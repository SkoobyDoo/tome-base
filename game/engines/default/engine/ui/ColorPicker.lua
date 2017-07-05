-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2017 Nicolas Casalini
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
local Shader = require "engine.Shader"
local Base = require "engine.ui.Base"
local Focusable = require "engine.ui.Focusable"
local GenericContainer = require "engine.ui.GenericContainer"
local Textzone = require "engine.ui.Textzone"
local Textbox = require "engine.ui.Textbox"
local Numberbox = require "engine.ui.Numberbox"

--- A generic UI image
-- @classmod engine.ui.Image
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self.color = t.color or colors_alphaf.LIGHT_GREEN(1)
	self.default_color = self.color
	self.w = assert(t.width, "no colorpicker width")
	self.h = assert(t.height, "no colorpicker height")
	self.fct = assert(t.fct, "no colorpicker fct")

	t.require_renderer = true
	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear():zSort(true)

	local mire = core.renderer.image("/data/gfx/ui/colorpicker_mire.png"):scale(self.w / 32, self.h / 32)
	self.do_container:add(mire)

	self.do_color = core.renderer.colorQuad(0, 0, self.w, self.h, 1, 1, 1, 1):translate(0, 0, 10)
	self.do_container:add(self.do_color)

	self.do_alpha = core.renderer.colorQuad(0, 0, self.w / 3, self.h, 1, 1, 1, 1):translate(self.w, 0, 10)
	self.do_container:add(self.do_alpha)

	self:setColor(self.color, true)

	self.w = math.ceil(self.w * 1.3)

	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if button == "left" then self:popup()
		elseif button == "right" then self:setColor({1, 0, 0, 1}) end
	end)
	-- game:onTickEnd(function() self:popup() end )
end

function _M:getColor(as_255)
	if as_255 then return {self.color[1] * 255, self.color[2] * 255, self.color[3] * 255, self.color[4] * 255}
	else return self.color end
end

function _M:setColor(c, nofct)
	self.color = c
	self.do_color:color(self.color[1], self.color[2], self.color[3], 1)
	self.do_alpha:color(self.color[4], self.color[4], self.color[4], 1)
	if not nofct then self.fct(c) end
end

local function rgb_to_hsv(r, g, b, a)
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local h, s, v
	v = max

	local d = max - min
	if max == 0 then s = 0 else s = d / max end

	if max == min then
		h = 0
	else
		if max == r then
		h = (g - b) / d
		if g < b then h = h + 6 end
		elseif max == g then h = (b - r) / d + 2
		elseif max == b then h = (r - g) / d + 4
		end
		h = h / 6
	end

	return h, s, v, a
end

local function hsv_to_rgb(h, s, v, a)
	local r, g, b

	local i = math.floor(h * 6);
	local f = h * 6 - i;
	local p = v * (1 - s);
	local q = v * (1 - f * s);
	local t = v * (1 - (1 - f) * s);

	i = i % 6

	if i == 0 then r, g, b = v, t, p
	elseif i == 1 then r, g, b = q, v, p
	elseif i == 2 then r, g, b = p, v, t
	elseif i == 3 then r, g, b = p, q, v
	elseif i == 4 then r, g, b = t, p, v
	elseif i == 5 then r, g, b = v, p, q
	end

	return r, g, b, a
end

function _M:popup()
	local Dialog = require "engine.ui.Dialog"
	local d = Dialog.new("Pick a color", 600, 600)

	local hue_shader = Shader.new("ui/color_picker_hsv")
	local regenHSV

	-- Current color
	local h, s, v, a = rgb_to_hsv(unpack(self.color))
	local r, g, b = unpack(self.color)

	-- Hue picker
	local hue = core.renderer.vertexes():texture(core.renderer.white):shader(hue_shader)
		:point(0, 0, 0, 0, 	0, 1, 1, 1)
		:point(d.iw, 0, 0, 0, 	1, 1, 1, 1)
		:point(d.iw, 50, 0, 0, 	1, 1, 1, 1)
		:point(0, 50, 0, 0, 	0, 1, 1, 1)
	local hue_selector = core.renderer.colorQuad(0, 0, 1, 50, 0, 0, 0, 1)
	local c_hue = GenericContainer.new{width=d.iw, height=50}
	c_hue.do_container:add(hue):add(hue_selector)

	-- S/V picker
	local c_hsv = GenericContainer.new{width=256, height=256}
	local hsv = core.renderer.vertexes():texture(core.renderer.white):shader(hue_shader)
		:point(0, 0, 0, 0, 	1, 1, 0, 1)
		:point(c_hsv.w, 0, 0, 0, 	1, 1, 1, 1)
		:point(c_hsv.w, c_hsv.h, 0, 0, 	1, 0, 1, 1)
		:point(0, c_hsv.h, 0, 0, 	1, 0, 0, 1)
	local hsv_selector = core.renderer.colorQuad(-5, -1, 5, 1, 1, 1, 1, 1, core.renderer.colorQuad(-1, -5, 1, 5, 1, 1, 1, 1))
	c_hsv.do_container:add(hsv):add(hsv_selector)

	-- Alpha
	local c_alpha = GenericContainer.new{width=d.iw - 266, height=48}
	local alpha_selector = core.renderer.colorQuad(0, 0, 1, 48, 1, 1, 1, 1)
	local alpha = core.renderer.vertexes():texture(core.renderer.white)
		:point(0, 0, 0, 0, 			1, 1, 1, 1)
		:point(c_alpha.w, 0, 0, 0, 		0, 0, 0, 1)
		:point(c_alpha.w, c_alpha.h, 0, 0, 	0, 0, 0, 1)
		:point(0, c_alpha.h, 0, 0, 		1, 1, 1, 1)
	c_alpha.do_container:add(alpha):add(alpha_selector)

	-- Final color
	local c_final = GenericContainer.new{width=32, height=32}
	local final = core.renderer.colorQuad(0, 0, c_final.w, c_final.h, 1, 1, 1, 1):translate(0, 0, 10)
	local mire = core.renderer.image("/data/gfx/ui/colorpicker_mire.png"):scale(c_final.w / 32, c_final.h / 32)
	c_final.do_container:add(mire):add(final)

	-- Misc UI elements
	local c_final_name = Textzone.new{text="Final color: ", auto_width=1, auto_height=1}	
	local c_r = Numberbox.new{title="Red:   ", chars=4, numer=r*255, min=0, max=255, fct=function(n) h, s, v, a = rgb_to_hsv(n, g, b, a) regenHSV() end}
	local c_g = Numberbox.new{title="Green: ", chars=4, numer=g*255, min=0, max=255, fct=function(n) h, s, v, a = rgb_to_hsv(r, n, b, a) regenHSV() end}
	local c_b = Numberbox.new{title="Blue:  ", chars=4, numer=b*255, min=0, max=255, fct=function(n) h, s, v, a = rgb_to_hsv(r, g, n, a) regenHSV() end}
	local c_a = Numberbox.new{title="Alpha: ", chars=4, numer=a*255, min=0, max=255, fct=function(n) h, s, v, a = rgb_to_hsv(r, g, b, n) regenHSV() end}
	local c_rgb = Textbox.new{title="Hex: ", chars=7, text=string.format("%02X%02X%02X", r * 255, g * 255, b * 255), max_len=6, filter=function(c) return string.hex_digits[c:lower()] and c:lower() or nil end,  fct=function(n) if not n then return end r, g, b = colors.hex1unpack(n) h, s, v, a = rgb_to_hsv(r, g, b, a) regenHSV() end}

	-- UI controls
	c_hue.mouse:registerZone(0, 0, c_hue.w, c_hue.h, function(button, x, y, xrel, yrel, bx, by, event)
		if button == "left" then
			h = bx / c_hue.w
			regenHSV()
		end
	end)
	c_hsv.mouse:registerZone(0, 0, c_hsv.w, c_hsv.h, function(button, x, y, xrel, yrel, bx, by, event)
		if button == "left" then
			v = bx / c_hsv.w
			s = 1 - (by / c_hsv.h)
			regenHSV()
		end
	end)
	c_alpha.mouse:registerZone(0, 0, c_alpha.w, c_alpha.h, function(button, x, y, xrel, yrel, bx, by, event)
		if button == "left" then
			a = 1 - bx / c_alpha.w
			regenHSV()
		end
	end)

	regenHSV = function()
		r, g, b, a = hsv_to_rgb(h, s, v, a)
		hsv:color(h, 1, 1, 1)
		hue_selector:translate(c_hue.w * h, 0, 10)
		alpha_selector:translate(c_alpha.w * (1 - a), 0, 10):color(1 - a, 1 - a, 1 - a, 1)
		hsv_selector:translate(c_hsv.w * v, c_hsv.h * (1 - s), 10):color(1 - a, 1 - a, 1 - a, 1)
		final:color(r, g, b, a)
		self:setColor{r, g, b, a}

		c_r.number = math.floor(r * 255); c_r:updateText(0)
		c_g.number = math.floor(g * 255); c_g:updateText(0)
		c_b.number = math.floor(b * 255); c_b:updateText(0)
		c_a.number = math.floor(a * 255); c_a:updateText(0)
		c_rgb:setText(string.format("%02X%02X%02X", r * 255, g * 255, b * 255))
	end
	regenHSV()

	local uis = {
		{left=0, top=0, ui=c_hue},
		{left=0, top=60, ui=c_hsv},
		{left=266, top=60, ui=c_alpha},
		{left=266, top=60 + c_alpha.h + (c_final_name.h - c_final_name.h) / 2, ui=c_final_name},
		{left=c_final_name, top=c_alpha, ui=c_final},
		{left=c_hsv, top=c_final, ui=c_r},
		{left=c_r, top=c_final, ui=c_g},
		{left=c_g, top=c_final, ui=c_b},
		{left=c_b, top=c_final, ui=c_a},
		{left=c_hsv, top=c_r, ui=c_rgb},
	}

	local def_colors = {}
	for _, c in pairs(colors_simple1) do
		def_colors[#def_colors+1] = {rgb_to_hsv(c[1], c[2], c[3], 1)}
	end
	table.sort(def_colors, function(a, b)
		if a[1] == b[1] then
			if a[2] == b[2] then return a[3] < b[3]
			else return a[2] < b[2] end
		else return a[1] < b[1] end
	end)
	local x, y = 0, 60 + c_hsv.h + 6
	for i, c in ipairs(def_colors) do
		local c = c
		local s, is = 36, 32
		local c_c = GenericContainer.new{width=is, height=is}
		local col = core.renderer.colorQuad(0, 0, c_c.w, c_c.h, hsv_to_rgb(unpack(c))):translate(0, 0, 10)
		c_c.do_container:add(col)
		c_c.mouse:registerZone(0, 0, c_c.w, c_c.h, function(button, x, y, xrel, yrel, bx, by, event) if button == "left" then
			h, s, v, a = unpack(c)
			regenHSV()
		end end)
		uis[#uis+1] = {left=x, top=y, ui=c_c}
		x = x + s
		if x + s >= d.iw then x = 0 y = y + s end
	end


	d.key:addBind("EXIT", function() 
		-- util.showMainMenu(false, engine.version[4], engine.version[1].."."..engine.version[2].."."..engine.version[3], game.__mod_info.short_name, game.save_name, false)
		game:unregisterDialog(d)
	end)
	d.key:addBind("ACCEPT", function() end)

	d:loadUI(uis)
	d:setupUI(false, false)

	game:registerDialog(d)
end
