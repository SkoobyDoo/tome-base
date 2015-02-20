-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2015 Nicolas Casalini
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
module(..., package.seeall, class.make)

local gfx_prefix = "/data/gfx/"
local cache = {}
local tcache = {}

_no_save_fields = { vo = true, votext = true, votextmono = true, votextbold = true }

-- Default font
_M.font = core.display.newFont("/data/font/DroidSans.ttf", 12)
_M.font_h = _M.font:lineSkip()
_M.font_mono = core.display.newFont("/data/font/DroidSansMono.ttf", 12)
_M.font_mono_w = _M.font_mono:size("  ") - _M.font_mono:size(" ")  -- account for inter-letter interval
_M.font_mono_h = _M.font_mono:lineSkip()
_M.font_bold = core.display.newFont("/data/font/DroidSans-Bold.ttf", 12)
_M.font_bold_h = _M.font_bold:lineSkip()

-- Default UI
_M.ui = "metal"
_M.defaultui = "metal"

sounds = {
	button = "ui/subtle_button_sound",
}

_M.ui_conf = {}

_M.tilesets = {}
_M.tilesets_texs = {}
_M.atlas_cache = {}

function _M:loadUIDefinitions(file)
	local f, err = loadfile(file)
	if not f then print("Error while loading UI definition from", file, ":", err) return end
	setfenv(f, self.ui_conf)
	local ok, err = pcall(f)
	if not f then print("Error while loading UI definition from", file, ":", err) return end
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

	if not self.ui_conf[self.ui] then self.ui = "metal" end

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
	local r = {t=t, w=w, h=h, tw=tw, th=th}
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
	print("Loading tile from tileset", f)
	local tex = self.tilesets_texs[d.set]
	if not tex then
		tex = core.display.loadImage(d.set):glTexture(true, true)
		self.tilesets_texs[d.set] = tex
		print("Loading tileset", d.set)
	end
	return tex, d.factorx, d.factory, d.x, d.y, d.w, d.h
end

function _M:getAtlasTexture(file)
	if self.atlas_cache[file] then return self.atlas_cache[file] end
	local uifile = (self.ui ~= "" and self.ui.."-" or "")..file
	local ts, fx, fy, tsx, tsy, tw, th = self:checkTileset(uifile)
	if ts then
		local t = {t=ts, tw=fx, th=fy, w=tw, h=th, tx=tsx, ty=tsy}
		self.atlas_cache[file] = t
		return t
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
		for di, dduid in ipairs(tex.dduids) do
			dduid.e:toScreen(nil, x + dduid.x, y, dduid.w, dduid.w, 1, false, false)
		end
	end
	return res
end

function _M:makeFrame(base, w, h)
	local f = {}
	if base then
		f.b7 = self:getUITexture(base.."7.png")
		f.b9 = self:getUITexture(base.."9.png")
		f.b1 = self:getUITexture(base.."1.png")
		f.b3 = self:getUITexture(base.."3.png")
		f.b8 = self:getUITexture(base.."8.png")
		f.b4 = self:getUITexture(base.."4.png")
		f.b2 = self:getUITexture(base.."2.png")
		f.b6 = self:getUITexture(base.."6.png")
		f.b5 = self:getUITexture(base.."5.png")
	end
	f.w = math.floor(w)
	f.h = math.floor(h)
	return f
end

function _M:makeVO()
	-- We could take any image in the tileset
	local t = self:getAtlasTexture("ui/button5.png")
	return core.vo.new(16, t.t)
end

function _M:addQuadVO(vo, at, x, y, w, h, r, g, b, a)
	return vo:addQuad(r or 1, g or 1, b or 1, a or 1,
		{x, y, 			at.tx, at.ty},
		{x + w, y, 		at.tx + at.tw, at.ty},
		{x + w, y + h, 		at.tx + at.tw, at.ty + at.th},
		{x, y + h, 		at.tx, at.ty + at.th}
	)
end

function _M:updateQuadTextureVO(vo, vo_id, at)
	local tx1, tx2, ty1, ty2 = at.tx, at.tx + at.tw, at.ty, at.ty + at.th

	vo:updateQuadTexture(vo_id,
		{tx1, ty1},
		{tx2, ty1},
		{tx2, ty2},
		{tx1, ty2}
	)
end

function _M:makeFrameVO(vo, base, x, y, w, h, r, g, b, a)
	local b7 = self:getAtlasTexture(base.."7.png")
	local b9 = self:getAtlasTexture(base.."9.png")
	local b1 = self:getAtlasTexture(base.."1.png")
	local b3 = self:getAtlasTexture(base.."3.png")
	local b8 = self:getAtlasTexture(base.."8.png")
	local b4 = self:getAtlasTexture(base.."4.png")
	local b2 = self:getAtlasTexture(base.."2.png")
	local b6 = self:getAtlasTexture(base.."6.png")
	local b5 = self:getAtlasTexture(base.."5.png")
	w = math.floor(w)
	h = math.floor(h)

	-- -- Sides
	local start = self:addQuadVO(vo, b8, x + b7.w, y, w - b7.w - b9.w, b8.h, r, g, b, a)
	self:addQuadVO(vo, b2, x + b7.w, y + h - b3.h, w - b7.w - b9.w, b2.h, r, g, b, a)
	self:addQuadVO(vo, b4, x, y + b7.h, b4.w, h - b7.h - b1.h, r, g, b, a)
	self:addQuadVO(vo, b6, x + w - b9.w, y + b7.h, b6.w, h - b7.h - b1.h, r, g, b, a)

	-- Corners
	self:addQuadVO(vo, b1, x, y + h - b1.h, b1.w, b1.h, r, g, b, a)
	self:addQuadVO(vo, b7, x, y, b7.w, b7.h, r, g, b, a)
	self:addQuadVO(vo, b9, x + w - b9.w, y, b9.w, b9.h, r, g, b, a)
	self:addQuadVO(vo, b3, x + w - b3.w, y + h - b3.h, b3.w, b3.h, r, g, b, a)

	-- Body
	local stop = self:addQuadVO(vo, b5, x + b7.w, y + b7.h, w - b7.w - b3.w , h - b7.h - b3.h, r, g, b, a)

	return {start=start, stop=stop}
end

function _M:updateFrameTextureVO(vo, vo_id, base)
	local b7 = base and self:getAtlasTexture(base.."7.png")
	local b9 = base and self:getAtlasTexture(base.."9.png")
	local b1 = base and self:getAtlasTexture(base.."1.png")
	local b3 = base and self:getAtlasTexture(base.."3.png")
	local b8 = base and self:getAtlasTexture(base.."8.png")
	local b4 = base and self:getAtlasTexture(base.."4.png")
	local b2 = base and self:getAtlasTexture(base.."2.png")
	local b6 = base and self:getAtlasTexture(base.."6.png")
	local b5 = base and self:getAtlasTexture(base.."5.png")
	local id = vo:find(vo_id.start)
	local s = vo:getQuadSize()

	-- -- Sides
	self:updateQuadTextureVO(vo, id + 0*s, b8)
	self:updateQuadTextureVO(vo, id + 1*s, b2)
	self:updateQuadTextureVO(vo, id + 2*s, b4)
	self:updateQuadTextureVO(vo, id + 3*s, b6)
	self:updateQuadTextureVO(vo, id + 4*s, b1)
	self:updateQuadTextureVO(vo, id + 5*s, b7)
	self:updateQuadTextureVO(vo, id + 6*s, b9)
	self:updateQuadTextureVO(vo, id + 7*s, b3)
	self:updateQuadTextureVO(vo, id + 8*s, b5)
end

function _M:updateFrameColorVO(vo, vo_id, set, r, g, b, a)
	vo:color(vo_id.start, vo_id.stop, set, r, g, b, a)
end

function _M:drawFrame(f, x, y, r, g, b, a, w, h, total_w, total_h, loffset_x, loffset_y, clip_area)
	if not f.b7 then return 0, 0, 0, 0 end
	
	loffset_x = loffset_x or 0
	loffset_y = loffset_y or 0
	total_w = total_w or 0
	total_h = total_h or 0
	
	x = math.floor(x)
	y = math.floor(y)
	
	f.w = math.floor(w or f.w)
	f.h = math.floor(h or f.h)
	
	clip_area = clip_area or { h = f.h, w = f.w }

	-- first of all check if anything is visible
	if total_h + f.h > loffset_y and total_h < loffset_y + clip_area.h then 
		local clip_y_start = 0
		local clip_y_end = 0
		local total_clip_y_start = 0
		local total_clip_y_end = 0

		-- check if top (top right, top and top left) is visible
		if total_h + f.b8.h > loffset_y and total_h < loffset_y + clip_area.h then
			util.clipTexture({_tex = f.b7.t, _tex_w = f.b7.tw, _tex_h = f.b7.th}, x, y, f.b7.w, f.b7.h, 0, total_h, 0, loffset_y, clip_area, r, g, b, a) --left top
			_, _, clip_y_start, clip_y_end = util.clipTexture({_tex = f.b8.t, _tex_w = f.b8.tw, _tex_h = f.b8.th}, x + f.b7.w, y, f.w - f.b7.w - f.b9.w, f.b8.h, 0, total_h, 0, loffset_y, clip_area, r, g, b, a) -- top
			util.clipTexture({_tex = f.b9.t, _tex_w = f.b9.tw, _tex_h = f.b9.th}, x + f.w - f.b9.w, y, f.b9.w, f.b9.h, 0, total_h, 0, loffset_y, clip_area, r, g, b, a) -- right top

			total_clip_y_start = clip_y_start
			total_clip_y_end = clip_y_end
		else
			total_clip_y_start = f.b8.h
		end
		total_h = total_h + f.b8.h
		local mid_h = math.floor(f.h - f.b2.h - f.b8.h)

		-- check if mid (right, center and left) is visible
		if total_h + mid_h > loffset_y and total_h < loffset_y + clip_area.h then
			util.clipTexture({_tex = f.b4.t, _tex_w = f.b4.tw, _tex_h = f.b4.th}, x, y + f.b7.h - total_clip_y_start, f.b4.w, mid_h, 0, total_h, 0, loffset_y, clip_area, r, g, b, a) -- left
			_, _, clip_y_start, clip_y_end = util.clipTexture({_tex = f.b6.t, _tex_w = f.b6.tw, _tex_h = f.b6.th}, x + f.w - f.b9.w, y + f.b7.h - total_clip_y_start, f.b6.w, mid_h, 0, total_h, 0, loffset_y, clip_area, r, g, b, a) -- center
			util.clipTexture({_tex = f.b5.t, _tex_w = f.b5.tw, _tex_h = f.b5.th}, x + f.b7.w, y + f.b7.h - total_clip_y_start, f.w - f.b7.w - f.b3.w, mid_h, 0, total_h, 0, loffset_y, clip_area, r, g, b, a) -- right

			total_clip_y_start = total_clip_y_start + clip_y_start
			total_clip_y_end = total_clip_y_end + clip_y_end
		else
			total_clip_y_start = total_clip_y_start + mid_h
		end
		total_h = total_h + mid_h
		
		-- check if bottom (bottom right, bottom and bottom left) is visible
		if total_h + f.b2.h > loffset_y and total_h < loffset_y + clip_area.h then
			util.clipTexture({_tex = f.b1.t, _tex_w = f.b1.tw, _tex_h = f.b1.th}, x, y + f.h - f.b1.h - total_clip_y_start, f.b1.w, f.b1.h, 0, total_h, 0, loffset_y, clip_area, r, g, b, a) -- left bottom
			_, _, clip_y_start, clip_y_end = util.clipTexture({_tex = f.b2.t, _tex_w = f.b2.tw, _tex_h = f.b2.th}, x + f.b7.w, y + f.h - f.b2.h - total_clip_y_start, f.w - f.b7.w - f.b9.w, f.b2.h, 0, total_h, 0, loffset_y, clip_area, r, g, b, a) -- bottom
			util.clipTexture({_tex = f.b3.t, _tex_w = f.b3.tw, _tex_h = f.b3.th}, x + f.w - f.b3.w, y + f.h - f.b3.h - total_clip_y_start, f.b3.w, f.b3.h, 0, total_h, 0, loffset_y, clip_area, r, g, b, a) -- right bottom

			total_clip_y_start = total_clip_y_start + clip_y_start
			total_clip_y_end = total_clip_y_end + clip_y_end
		else
			total_clip_y_start = total_clip_y_start + f.b2.h
		end
		
		return 0, 0, total_clip_y_start, total_clip_y_end
	end
	return 0, 0, 0, 0
end

function _M:setTextShadow(v)
	self.text_shadow = v
end

function _M:positioned(x, y)
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

function _M:setupVOs(vo, font, fontmono, fontbold)
	if vo then self.vo = self:makeVO() end
	if font then self.votext = core.vo.new() end
	if fontmono then self.votextmono = core.vo.new() end
	if fontbold then self.votextbold = core.vo.new() end
end
