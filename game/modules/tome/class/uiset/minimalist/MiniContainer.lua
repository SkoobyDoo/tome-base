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
	self.locked = true
	self.orientation = "left"
end

function _M:imageLoader(file)
	local sfile = "/data/gfx/"..UI.ui.."-ui/minimalist/"..file
	-- DGDGDGDG: use atlas !!!!
	if fs.exists(sfile) then
		return core.renderer.surface(core.display.loadImage(sfile), 0, 0)
	else
		return core.renderer.surface(core.display.loadImage("/data/gfx/ui/"..file), 0, 0)
	end
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
	self.mouse.delegate_offset_x, self.mouse.delegate_offset_y = x, y
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

function _M:getPlace()
	return "bad", {x=0, y=0, scale=1, a=0}
end
