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
local Separator = require "engine.ui.Separator"
local Focusable = require "engine.ui.Focusable"

-- a slider with an integrated numberbox
-- @classmod engine.ui.NumberSlider
module(..., class.inherit(Separator, Focusable))

function _M:init(t)
	self.min = t.min or 0
	self.max = t.max or 9999
	self.value = t.value or self.min
	self.on_change = on_change
	self.nbox = Numberbox.new{
		min=self.min,
		max=self.max,
		title="",
		chars = #tostring(self.max) + 1,
		number = self.value,
		fct = function(v) self:onChange() end,
	}
	self.nbox.can_focus = false -- we will handle its focus by hand

	local dir = t.dir
	if t.dir == "horizontal" then
		t.dir = "vertical"
	else
		t.dir = "horizontal"
	end
	Separator.init(self, t)
	t.dir = dir
	self.dir = dir
	self.key = self.nbox.key
end

function _M:on_focus(v)
	self.nbox:setFocus(v)
	self:onChange()
end

function _M:onChange()
	self.value = self.nbox.number
	if self.on_change then self.on_change(self.value) end
end

function _M:display(x, y, nb_keyframes)
	if self.dir == "horizontal" then
		self.dir = "vertical"
		Separator.display(self, x, y, nb_keyframes)
		self.dir = "horizontal"
		local halfw = self.nbox.w / 2
		local delta = self.max - self.min
		local shift = self.value - self.min
		local prop = delta > 0 and shift / delta or 0.5
		local xmin, xmax = math.max(self.left.w, halfw), self.w - math.max(self.right.w, halfw)
		local nbx = xmin + (xmax - xmin) * prop
		self.range = {nbx - halfw, nbx + halfw}
		self.nbox:display(x + nbx - halfw, y + (self.h - self.nbox.h) / 2, nb_keyframes)
	else
		self.dir = "horizontal"
		Separator.display(self, x, y, nb_keyframes)
		self.dir = "vertical"
		local halfh = self.nbox.h / 2
		local delta = self.max - self.min
		local shift = self.value - self.min
		local prop = delta > 0 and shift / delta or 0.5
		local ymin, ymax = math.max(self.top.h, halfh), self.h - math.max(self.bottom.h, halfh)
		local nbx = ymin + (ymax - ymin) * prop
		self.range = {nby - halfh, nby + halfh}
		self.nbox:display(x + (self.w - self.nbox.w) / 2, y + nby - halfh, nb_keyframes)
	end
end

