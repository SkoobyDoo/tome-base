-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2016 Nicolas Casalini
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

--- Flying Text
-- @classmod engine.FlyingText
module(..., package.seeall, class.make)

--- Init
-- @string[opt="DroidSans"] fontname
-- @int[opt=12] fontsize
-- @string[opt="DroidSans-Bold"] bigfontname
-- @int[opt=14] bigfontsize
function _M:init(fontname, fontsize, bigfontname, bigfontsize)
	self.font = core.display.newFont(fontname or "/data/font/DroidSans.ttf", fontsize or 12)
	self.bigfont = core.display.newFont(bigfontname or "/data/font/DroidSans-Bold.ttf", bigfontsize or 14)
	self.font_h = self.font:lineSkip()
	self.flyers = {}
	self.renderer = core.renderer.renderer()
end

--- Return the DisplayObject to draw
function _M:getDO()
	return self.renderer
end

--- Sets a tilt to the texts based on xvel
-- @param angle, in degree when xvel is 5
function _M:setTilt(a)
	self.tilt = a
end

local UI = require "engine.ui.Base"
_M.setTextOutline = UI.setTextOutline
_M.setTextShadow = UI.setTextShadow
_M.applyShadowOutline = UI.applyShadowOutline

--- Add a new flying text
-- @int x x position
-- @int y y position
-- @int[opt=10] duration
-- @param[type=?number] xvel horizontal velocity
-- @param[type=?number] yvel vertical velocity
-- @string str what the text says
-- @param[type=?table] color color of the text, defaults to colors.White
-- @param[type=?boolean] bigfont use the big font?
-- @return `FlyingText`
function _M:add(x, y, duration, xvel, yvel, str, color, bigfont)
	if not x or not y or not str then return end
	color = color or {255,255,255}
	local f = {
		DO = core.renderer.text(self.font),
		duration=duration or 10,
		xvel = xvel or 0,
		yvel = yvel or 0,
	}
	f.popout_dur = math.max(3, math.floor(f.duration / 4)),
	self:applyShadowOutline(f.DO)
	f.DO:textColor(color[1] / 255, color[2] / 255, color[3] / 255, 1)
	f.DO:text(str)
	f.DO:center()
	f.DO:translate(x, y)
	if self.tilt then f.DO:rotate(0, 0, math.rad(self.tilt * f.xvel / 5)) end
	f.w, f.h = f.DO:getStats()
	self.renderer:add(f.DO)
	self.flyers[f] = true
	return f
end

--- Removes all FlyingText
function _M:empty()
	self.flyers = {}
end

--- Display loop function
-- @int nb_keyframes
function _M:display(nb_keyframes)
	if not next(self.flyers) then return end
	self.renderer:toScreen()

	local dels = {}

	for fl, _ in pairs(self.flyers) do
		local zoom = nil
		local x, y = -fl.w / 2, -fl.h / 2
		local tx, ty = fl.x, fl.y
		
		fl.DO:translate(fl.xvel * nb_keyframes, fl.yvel * nb_keyframes, 0, true)
		fl.duration = fl.duration - nb_keyframes

		-- Delete the flyer
		if fl.duration <= 0 then
			dels[#dels+1] = fl
		elseif fl.duration <= fl.popout_dur then
			zoom = (fl.duration / fl.popout_dur)
			fl.DO:scale(zoom, zoom, zoom)
			fl.DO:color(1, 1, 1, zoom)
		end
	end

	for i, fl in ipairs(dels) do self.renderer:remove(fl.DO) self.flyers[fl] = nil end
end
