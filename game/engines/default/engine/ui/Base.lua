-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2018 Nicolas Casalini
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Nicolas Casalini "DarkGod"
-- darkgod@te4.org

require "engine.class"
local KeyBind = require "engine.KeyBind"
local Mouse = require "engine.Mouse"

--- A generic UI element
-- @classmod engine.ui.base
module(..., package.seeall, class.make)

local gfx_prefix = "/data/gfx/"
local cache = {}
local tcache = {}

_M.tilesets = {}
_M.tilesets_texs = {}
_M.atlas_cache = {}

-- Default font
_M.font = core.display.newFont("/data/font/DroidSans.ttf", 12)
_M.font_h = _M.font:lineSkip()
_M.font_mono = core.display.newFont("/data/font/DroidSansMono.ttf", 12)
_M.font_mono_w = _M.font_mono:size("  ") - _M.font_mono:size(" ")  -- account for inter-letter interval
_M.font_mono_h = _M.font_mono:lineSkip()
_M.font_bold = core.display.newFont("/data/font/DroidSans-Bold.ttf", 12)
_M.font_bold_h = _M.font_bold:lineSkip()

-- Default UI
_M.ui = "dark"
_M.defaultui = "dark"

sounds = {
	button = "ui/subtle_button_sound",
}

_M.ui_conf = {}

function _M:loadUIDefinitions(file)
	local f, err = loadfile(file)
	if not f then error("Error while loading UI definition from", file, ":", err) return end
	self.ui_conf.def = self.ui_conf
	setfenv(f, self.ui_conf)
	local ok, err = pcall(f)
	self.ui_conf.def = nil
	if not f then error("Error while loading UI definition from", file, ":", err) return end
end

function _M:uiExists(ui)
	return self.ui_conf[ui]
end

function _M:changeDefault(ui)
	if not self:uiExists(ui) then return end
	self.ui = ui
	for name, c in pairs(package.loaded) do
		if type(c) == "table" and c.isClassName and c:isClassName(self._NAME) then
			c.ui = ui
		end
	end
end

function _M:inherited(base)
	if base._NAME == "engine.ui.Base" then
		self.font = base.font
		self.font_h = base.font_h
		self.font_mono = base.font_mono
		self.font_mono_w = base.font_mono_w
		self.font_mono_h = base.font_mono_h
		self.font_bold = base.font_bold
		self.font_bold_h = base.font_bold_h
	end
end

function _M:init(t, no_gen)
	self.mouse = Mouse.new()
	self.key = KeyBind.new()
	if t.require_renderer then
		self.do_container = core.renderer.renderer()
	else
		self.do_container = core.renderer.container()
	end
	self.blocks = setmetatable({}, {__mode="k"})

	if not rawget(self, "ui") then self.ui = self.ui end

	if t.font then
		if type(t.font) == "table" then
			self.font = core.display.newFont(t.font[1], t.font[2])
			self.font_h = self.font:lineSkip()
		else
			self.font = t.font
			self.font_h = self.font:lineSkip()
		end
	end
	
	if t.ui then self.ui = t.ui end

	if not self.ui_conf[self.ui] then self.ui = "dark" end

	if not no_gen then self:generate() end
end

function _M:clearCache()
	cache = {}
	tcache = {}
end

function _M:getImage(file, noerror)
	if cache[file] then return unpack(cache[file]) end
	local s = core.display.loadImage(gfx_prefix..file)
	if noerror and not s then return end
	assert(s, "bad UI image: "..file)
	s:alpha(true)
	cache[file] = {s, s:getSize()}
	return unpack(cache[file])
end

function _M:getUITexture(file)
	local uifile = (self.ui ~= "" and self.ui.."-" or "")..file
	if tcache[uifile] then return tcache[uifile] end
	local i, w, h = self:getImage(uifile, true)
	if not i then i, w, h = self:getImage(self.defaultui.."-"..file) end
	if not i then error("bad UI texture: "..uifile) return end
	local t, tw, th = i:glTexture()
	local r = {t=t, w=w, h=h, tw=w/tw, th=h/th, tx=0, ty=0}
	tcache[uifile] = r
	return r
end

function _M:loadTileset(file)
	if not fs.exists(file) then print("Tileset file "..file.." does not exists.") return end
	local f, err = loadfile(file)
	if err then error(err) end
	local env = {}
	local ts = {}
	setfenv(f, setmetatable(ts, {__index={_G=ts}}))
	local ok, err = pcall(f)
	if not ok then error(err) end
	print("[TILESET] loading atlas", file, ok, err)
	if ts.__width > core.display.glMaxTextureSize() or ts.__height > core.display.glMaxTextureSize() then
		print("[TILESET] Refusing tileset "..file.." due to texture size "..ts.__width.."x"..ts.__height.." over max of "..core.display.glMaxTextureSize())
		return
	end
	for k, e in pairs(ts) do self.tilesets[k] = e end
end

function _M:checkTileset(image)
	local f = gfx_prefix..image
	if not self.tilesets[f] then return end
	local d = self.tilesets[f]
	-- print("Loading tile from tileset", f)
	local tex = self.tilesets_texs[d.set]
	if not tex then
		tex = core.loader.png(d.set, true, true)
		self.tilesets_texs[d.set] = tex
		print("Loading tileset", d.set)
	end
	return tex, d.factorx, d.factory, d.x, d.y, d.w, d.h
end

function _M:getAtlasTexture(file)
	local uifile = (self.ui ~= "" and self.ui.."-" or "")..file
	if self.atlas_cache[uifile] then return self.atlas_cache[uifile] end
	local ts, fx, fy, tsx, tsy, tw, th = self:checkTileset(uifile)
	if ts then
		local t = {t=ts, tw=fx, th=fy, w=tw, h=th, tx=tsx, ty=tsy}
		self.atlas_cache[uifile] = t
		return t
	else
		return self:getUITexture(file)
	end
end

function _M:drawFontLine(font, text, width, r, g, b, direct_draw)
	width = width or font:size(text)
	local tex = font:draw(text, width, r or 255, g or 255, b or 255, true, direct_draw)[1]
	local r = {t = tex._tex, w=tex.w, h=tex.h, tw=tex._tex_w, th=tex._tex_h, dduids = tex._dduids}
	return r
end

function _M:textureToScreen(tex, x, y, r, g, b, a, allow_uid)
	local res = tex.t:toScreenFull(x, y, tex.w, tex.h, tex.tw, tex.th, r, g, b, a)
	if tex.dduids and allow_uid then
		for e, dduid in pairs(tex.dduids) do
			e:toScreen(nil, x + dduid.x, y, dduid.w, dduid.w, 1, false, false)
		end
	end
	return res
end

function _M:makeFrame(base, w, h, iw, ih)
	local f = {}
	if base then
		f.b7 = self:getAtlasTexture(base.."7.png")
		f.b9 = self:getAtlasTexture(base.."9.png")
		f.b1 = self:getAtlasTexture(base.."1.png")
		f.b3 = self:getAtlasTexture(base.."3.png")
		f.b8 = self:getAtlasTexture(base.."8.png")
		f.b4 = self:getAtlasTexture(base.."4.png")
		f.b2 = self:getAtlasTexture(base.."2.png")
		f.b6 = self:getAtlasTexture(base.."6.png")
		f.b5 = self:getAtlasTexture(base.."5.png")
		if not w then w = iw + f.b4.w + f.b6.w end
		if not h then h = ih + f.b8.h + f.b2.h end
	end
	f.w = math.floor(w)
	f.h = math.floor(h)
	return f
end

local fromTextureTable = core.renderer.fromTextureTable

local function resizeFrame(f, w, h, iw, ih)
	if not w then w = iw + f.b4.w + f.b6.w end
	if not h then h = ih + f.b8.h + f.b2.h end
	local cx, cy = f.cx, f.cy

	if f.b1.t == f.b2.t and f.b1.t == f.b3.t and f.b1.t == f.b4.t and f.b1.t == f.b5.t and f.b1.t == f.b6.t and f.b1.t == f.b7.t and f.b1.t == f.b8.t and f.b1.t == f.b9.t then
		if not f.container then f.container = core.renderer.vertexes() end
		-- print("====MAKING MONO VERTEX FRAME")
		f.container:clear()
		fromTextureTable(f.b5, cx + f.b4.w, cy + f.b8.h, w - f.b6.w - f.b4.w, h - f.b8.h - f.b2.h, true, 1, 1, 1, 1, f.container)

		fromTextureTable(f.b7, cx + 0, cy + 0, nil, nil, false, 1, 1, 1, 1, f.container)
		fromTextureTable(f.b9, cx + w-f.b9.w, cy + 0, nil, nil, false, 1, 1, 1, 1, f.container)

		fromTextureTable(f.b1, cx + 0, cy + h-f.b1.h, nil, nil, false, 1, 1, 1, 1, f.container)
		fromTextureTable(f.b3, cx + w-f.b3.w, cy + h-f.b3.h, nil, nil, false, 1, 1, 1, 1, f.container)

		fromTextureTable(f.b4, cx + 0, cy + f.b7.h, nil, h - f.b7.h - f.b1.h, true, 1, 1, 1, 1, f.container)
		fromTextureTable(f.b6, cx + w-f.b6.w, cy + f.b9.h, nil, h - f.b9.h - f.b3.h, true, 1, 1, 1, 1, f.container)

		fromTextureTable(f.b8, cx + f.b7.w, cy + 0, w - f.b7.w - f.b9.w, nil, true, 1, 1, 1, 1, f.container)
		fromTextureTable(f.b2, cx + f.b1.w, cy + h - f.b2.h, w - f.b1.w - f.b3.w, nil, true, 1, 1, 1, 1, f.container)
	else
		if not f.container then f.container = core.renderer.container() end
		f.container:clear()
		f.container:add(fromTextureTable(f.b5, cx + f.b4.w, cy + f.b8.h, w - f.b6.w - f.b4.w, h - f.b8.h - f.b2.h, true))

		f.container:add(fromTextureTable(f.b7, cx + 0, cy + 0))
		f.container:add(fromTextureTable(f.b9, cx + w-f.b9.w, cy + 0))

		f.container:add(fromTextureTable(f.b1, cx + 0, cy + h-f.b1.h))
		f.container:add(fromTextureTable(f.b3, cx + w-f.b3.w, cy + h-f.b3.h))

		f.container:add(fromTextureTable(f.b4, cx + 0, cy + f.b7.h, nil, h - f.b7.h - f.b1.h, true))
		f.container:add(fromTextureTable(f.b6, cx + w-f.b6.w, cy + f.b9.h, nil, h - f.b9.h - f.b3.h, true))

		f.container:add(fromTextureTable(f.b8, cx + f.b7.w, cy + 0, w - f.b7.w - f.b9.w, nil, true))
		f.container:add(fromTextureTable(f.b2, cx + f.b1.w, cy + h - f.b2.h, w - f.b1.w - f.b3.w, nil, true))
	end
end

function _M:makeFrameDO(base, w, h, iw, ih, center, resizable)
	local f = {}
	if base then
		if type(base) == "string" then
			f.b7 = self:getAtlasTexture(base.."7.png")
			f.b9 = self:getAtlasTexture(base.."9.png")
			f.b1 = self:getAtlasTexture(base.."1.png")
			f.b3 = self:getAtlasTexture(base.."3.png")
			f.b8 = self:getAtlasTexture(base.."8.png")
			f.b5 = self:getAtlasTexture(base.."5.png")
			f.b4 = self:getAtlasTexture(base.."4.png")
			f.b2 = self:getAtlasTexture(base.."2.png")
			f.b6 = self:getAtlasTexture(base.."6.png")
		else
			f.b7 = base.fct(base.base.."7.png")
			f.b9 = base.fct(base.base.."9.png")
			f.b1 = base.fct(base.base.."1.png")
			f.b3 = base.fct(base.base.."3.png")
			f.b8 = base.fct(base.base.."8.png")
			f.b5 = base.fct(base.base.."5.png")
			f.b4 = base.fct(base.base.."4.png")
			f.b2 = base.fct(base.base.."2.png")
			f.b6 = base.fct(base.base.."6.png")
		end
		local cx, cy = 0,0
		if not w then w = iw + f.b4.w + f.b6.w end
		if not h then h = ih + f.b8.h + f.b2.h end

		if center then cx, cy = -math.floor(w / 2), -math.floor(h / 2) end
		f.cx, f.cy = cx, cy

		resizeFrame(f, w, h)
	else
		f.container = core.renderer.container() -- dummy
	end
	f.w = math.floor(w)
	f.h = math.floor(h)
	if resizable then f.resize = resizeFrame end
	return f
end

function _M:cloneFrameDO(of, resizable)
	local f = {}
	f.w, f.h = of.w, of.h
	f.cx, f.cy = of.cx, of.cy
	f.b7 = of.b7 f.b9 = of.b9 f.b1 = of.b1 f.b3 = of.b3 f.b8 = of.b8 f.b5 = of.b5 f.b4 = of.b4 f.b2 = of.b2 f.b6 = of.b6
	resizeFrame(f, f.w, f.h)
	if resizable then f.resize = resizeFrame end
	return f
end

function _M:drawFrame(f, x, y, r, g, b, a, w, h, total_w, total_h, loffset_x, loffset_y, clip_area)
	-- DGDGDGDG : replace that!
	error("replace UI:drawFrame")
end

function _M:setTextShadow(color, x, y)
	if color == false or color == nil then
		self.text_shadow = false
	elseif type(v) == "table" then -- Already a color, use it
		self.text_shadow = {x=x, y=y or x, color=colors.smart1(v)}
	else -- Just use a default outline value
		self.text_shadow = {x=color or 1, y=color or 1, color={0, 0, 0, 0.7}}
	end
end

function _M:setTextOutline(v)
	if v == false or v == nil then
		self.text_outline = false
	elseif type(v) == "table" then -- Already a color, use it
		self.text_outline = colors.smart1(v)
	elseif type(v) == "number" then -- Assuem this is the desired alpha
		self.text_outline = {0, 0, 0, v}
	else -- Just use a default outline value
		self.text_outline = {0, 0, 0, 0.7}
	end
end

function _M:applyShadowOutline(textdo)
	if self.text_outline then textdo:outline(1, unpack(self.text_outline)) end
	if self.text_shadow then textdo:shadow(self.text_shadow.x, self.text_shadow.y, unpack(self.text_shadow.color)) end
end

function _M:positioned(x, y)
end

function _M:blockAdded(block)
	self.blocks[block] = true
end

function _M:sound(name)
	if game.playSound and sounds[name] then
		game:playSound(sounds[name])
	end
end

function _M:makeKeyChar(i)
	i = i - 1
	if i < 26 then
		return string.char(string.byte('a') + i)
	elseif i < 52 then
		return string.char(string.byte('A') + i - 26)
	elseif i < 62 then
		return string.char(string.byte('0') + i - 52)
	else
		-- Invalid
		return "  "
	end
end

function _M:display(x, y, nb_keyframes, screen_x, screen_y, offset_x, offset_y, local_x, local_y)
end
