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

local class= require "engine.class"
local Numberbox = require "engine.ui.Numberbox"
local Focusable = require "engine.ui.Focusable"
local Base = require "engine.ui.Base"

-- a slider with an integrated numberbox
-- @classmod engine.ui.NumberSlider
module(..., class.inherit(Base, Focusable))

function _M:init(t)
	self.min = t.min or 0
	self.max = t.max or 9999
	self.value = t.value or self.min
	self.step = t.step or 10
	self.on_change = on_change
	assert(t.size or t.w, "no numberspinner size")
	self.size = t.size
	self.w = t.w

	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()

	self.w = self.w or self.size
	self.left = self:getUITexture("ui/border_hor_left.png")
	self.middle = self:getUITexture("ui/border_hor_middle.png")
	self.right = self:getUITexture("ui/border_hor_right.png")
	self.nbox = Numberbox.new{
		min=self.min,
		max=self.max,
		title="",
		chars = #tostring(self.max) + 1,
		number = self.value,
		fct = function(v) self:onChange() end,
	}
	self.key:addBind("ACCEPT", function() self:onChange() end)
	self.key:addCommands{
		_UP = function() self.nbox:updateText(1) self:onChange() end,
		_DOWN = function() self.nbox:updateText(-1) self:onChange() end,
	}
	self.key.atLast = function(sym, ctrl, shift, alt, meta, unicode, isup, key) self.nbox.key:receiveKey(sym, ctrl, shift, alt, meta, unicode, isup, key) print("KEY", unicode) end
	self.h = math.max(self.nbox.h, self.middle.h)
	self.w = self.size
	self:onChange()

	self.mouse:registerZone(self.left.w, 0, self.w - self.left.w - self.right.w, self.h, function(...) self.nbox.mouse:delegate(...) end, nil, "box")
	self.nbox.mouse.delegate_offset_y = (self.h - self.nbox.h) / 2
	-- wheeeeeeee
	local wheelTable = {wheelup = 1, wheeldown = -1}
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if event ~= "button" or not wheelTable[button] then return false end
		self.nbox:updateText(wheelTable[button])
		self:onChange()
	end, {button=true})
	-- clicking on arrows
	local stepTable = {left = self.step, right = 1}
	self.mouse:registerZone(0, 0, self.left.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if event ~= "button" or not stepTable[button] then return false end
		self.nbox:updateText(-stepTable[button])
		self:onChange()
	end, {button=true}, "left")
	self.mouse:registerZone(self.w - self.right.w, 0, self.right.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if event ~= "button" or not stepTable[button] then return false end
		self.nbox:updateText(stepTable[button])
		self:onChange()
	end, {button=true}, "right")
	self:onChange()
end

function _M:on_focus(v)
	self.nbox:setFocus(v)
	self:onChange()
end

function _M:onChange()
	self.value = self.nbox.number
	if self.on_change then self.on_change(self.value) end

	local halfw = self.nbox.w / 2
	local delta = self.max - self.min
	local shift = self.value - self.min
	local prop = delta > 0 and shift / delta or 0.5
	local xmin, xmax = self.left.w + halfw, self.w - self.right.w - halfw
	local nbx = xmin + (xmax - xmin) * prop
	self.range = {nbx - halfw, nbx + halfw}
	local offsety = (self.h - self.nbox.h) / 2

	self.nbox.mouse.delegate_offset_x = self.range[1]
	self.mouse:updateZone("left", 0, 0, self.range[1], self.h)
	self.mouse:updateZone("right", self.range[2], 0, self.w - self.range[2], self.h)
	self.mouse:updateZone("box", self.range[1], offsety, self.range[2] - self.range[1], self.h - 2 * offsety)
end

function _M:display(x, y, nb_keyframes)
	self:textureToScreen(self.left, x, y + (self.h - self.left.h) / 2)
	self:textureToScreen(self.right, x + self.w - self.right.w, y + (self.h - self.right.h) / 2)
	self.middle.t:toScreenFull(x + self.left.w, y, self.w - self.left.w - self.right.w, self.middle.h, self.middle.tw, self.middle.th)
	self.nbox:display(x + self.range[1], y + (self.h - self.nbox.h) / 2, nb_keyframes)
end

