-- TE4 - T-Engine 4
-- Copyright (C) 2009, 2010 Nicolas Casalini
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
local Base = require "engine.ui.Base"

--- A generic UI slider, usualy used by other UI elements
module(..., package.seeall, class.inherit(Base))

function _M:init(t)
	self.size = assert(t.size, "no slider size")
	self.max = assert(t.max, "no slider max")
	self.pos = t.pos or 0
	self.inverse = t.inverse

	Base.init(self, t)
end

function _M:generate()
	self.top = self:getTexture("ui/scrollbar_top.png")
	self.middle = self:getTexture("ui/scrollbar.png")
	self.bottom = self:getTexture("ui/scrollbar_bottom.png")
	self.sel = self:getTexture("ui/scrollbar-sel.png")
	self.w, self.h = self.middle.w, self.size
end

function _M:display(x, y)
	self.top.t:toScreenFull(x, y, self.top.w, self.top.h, self.top.tw, self.top.th)
	self.bottom.t:toScreenFull(x, y + self.h - self.bottom.h, self.bottom.w, self.bottom.h, self.bottom.tw, self.bottom.th)
	self.middle.t:toScreenFull(x, y + self.top.h, self.middle.w, self.h - self.top.h - self.bottom.h, self.middle.tw, self.middle.th)
	self.pos = util.bound(self.pos, 0, self.max)
	if self.inverse then
		y = y + self.h - (self.pos * self.size / self.max) + self.sel.h / 2
	else
		y = y + (self.pos * self.size / self.max) + self.sel.h / 2
	end
	self.sel.t:toScreenFull(x - (self.sel.w - self.top.w) / 2, y, self.sel.w, self.sel.h, self.sel.tw, self.sel.th)
end
