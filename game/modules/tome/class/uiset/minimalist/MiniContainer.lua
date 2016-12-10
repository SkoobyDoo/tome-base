-- ToME - Tales of Maj'Eyal
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
local Mouse = require "engine.Mouse"
local UI = require "engine.ui.Base"

--- Abstract class that defines a UI "item", like th player frame, hotkeys, ...
-- @classmod engine.LogDisplay
module(..., package.seeall, class.make)

function _M:init(minimalist, w, h)
	if not w or not h then
		local _ _, _, w, h = self:getDefaultGeometry()
	end
	self.uiset = minimalist
	self.mouse = Mouse.new()
	self.x, self.y = 0, 0
	self.w, self.h = w, h
	self.scale = 1
	self.locked = true
	self.focused = false
	self.orientation = "left"
	self.mousezone_id = self:getClassName() -- Change that in the subclass if there has to be more than one instance
end

function _M:imageLoader(file, rw, rh)
	local sfile = UI.ui.."-ui/minimalist/"..file
	if fs.exists("/data/gfx/"..sfile) then
		local ts, fx, fy, tsx, tsy, tw, th = UI:checkTileset(sfile)
		if ts then return core.renderer.fromTextureTable({t=ts, tw=fx, th=fy, w=tw, h=th, tx=tsx, ty=tsy}, 0, 0, rw, rh)
		else return core.renderer.surface(core.display.loadImage("/data/gfx/"..sfile), 0, 0, rw, rh) end
	else
		local ts, fx, fy, tsx, tsy, tw, th = UI:checkTileset("ui/"..file)
		if ts then return core.renderer.fromTextureTable({t=ts, tw=fx, th=fy, w=tw, h=th, tx=tsx, ty=tsy}, 0, 0, rw, rh)
		else return core.renderer.surface(core.display.loadImage("/data/gfx/ui/"..file), 0, 0, rw, rh) end
	end
end

function _M:texLoader(file, rw, rh)
	local sfile = UI.ui.."-ui/minimalist/"..file
	if fs.exists("/data/gfx/"..sfile) then
		local ts, fx, fy, tsx, tsy, tw, th = UI:checkTileset(sfile)
		if ts then return {t=ts, tw=fx, th=fy, w=tw, h=th, tx=tsx, ty=tsy}
		else
			local tex, rw, rh, tw, th, iw, ih = core.display.loadImage("/data/gfx/"..sfile):glTexture()
			return {t=tex, w=iw, h=ih, tw=iw/rw, th=ih/rh, tx=0, ty=0}
		end
	else
		local ts, fx, fy, tsx, tsy, tw, th = UI:checkTileset("ui/"..file)
		if ts then return {t=ts, tw=fx, th=fy, w=tw, h=th, tx=tsx, ty=tsy}
		else
			local tex, rw, rh, tw, th, iw, ih = core.display.loadImage("/data/gfx/ui/"..file):glTexture()
			return {t=tex, w=iw, h=ih, tw=iw/rw, th=ih/rh, tx=0, ty=0}
		end
	end
end

function _M:makeFrameDO(base, w, h, iw, ih, center, resizable)
	return UI:makeFrameDO({base=base, fct=function(s) return self:texLoader(s) end}, w, h, iw, ih, center, resizable)
end

function _M:update(nb_keyframes)
end

function _M:getDefaultGeometry()
	error("MiniContainer defined without a default geometry")
end

function _M:getDO()
	error("cant use MiniContainer directly")
end

function _M:move(x, y)
	self.x, self.y = x, y
	self:setupMouse()
end

function _M:resize(w, h)
	self.w, self.h = w, h
end

function _M:setOrientation(dir)
	self.orientation = dir
end

function _M:lock(v)
	self.locked = v
end

function _M:getDO()
	-- By default assume this name, overload if different
	return self.do_container
end

function _M:onFocus(v)
end

function _M:tooltipAll(fct, desc)
	return function(button, mx, my, xrel, yrel, bx, by, event)
		if event ~= "out" then game.tooltip_x, game.tooltip_y = 1, 1; game:tooltipDisplayAtMap(game.w, game.h, tostring(util.getval(desc))) end
		fct(button, mx, my, xrel, yrel, bx, by, event)
	end
end

function _M:tooltipButton(fct, desc)
	return function(button, mx, my, xrel, yrel, bx, by, event)
		if event ~= "out" then game.tooltip_x, game.tooltip_y = 1, 1; game:tooltipDisplayAtMap(game.w, game.h, tostring(util.getval(desc))) end
		if event == "button" then fct(button, mx, my, xrel, yrel, bx, by, event) end
	end
end

function _M:setupMouse(first)
	if first then self.mouse_first_setup = true end
	if not self.mouse_first_setup then return end

	self.mouse.delegate_offset_x, self.mouse.delegate_offset_y = self.x, self.y
	if not game.mouse:updateZone(self.mousezone_id, self.x, self.y, self.w, self.h, nil, self.scale) then
		game.mouse:unregisterZone(self.mousezone_id)

		local fct = function(button, mx, my, xrel, yrel, bx, by, event)
			local newfocus = event ~= "out"
			if newfocus ~= focus then
				self.focused = newfocus
				self:onFocus(self.focused)
			end
			self.mouse:delegate(button, mx, my, xrel, yrel, bx, by, event)
		end
		game.mouse:registerZone(self.x, self.y, self.w, self.h, fct, nil, self.mousezone_id, true, self.scale)
	end
end
