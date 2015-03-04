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
local Base = require "engine.ui.Base"

--- A generic UI slider, usualy used by other UI elements
module(..., package.seeall, class.inherit(Base))

function _M:init(t)
	self.h = assert(t.size, "no slider size")
	self.max = assert(t.max, "no slider max")
	self.pos = t.pos or 0
	self.inverse = t.inverse
	self.pos = util.minBound(self.pos, 0, self.max)

	Base.init(self, t)
end

function _M:generate()
	self.top = self:getAtlasTexture("ui/scrollbar_top.png")
	self.middle = self:getAtlasTexture("ui/scrollbar.png")
	self.bottom = self:getAtlasTexture("ui/scrollbar_bottom.png")
	self.sel = self:getAtlasTexture("ui/scrollbar-sel.png")
	self.w = self.middle.w
	self.pos = util.minBound(self.pos, 0, self.max)
end

function _M:display(x, y)
	self:uiTexture(self.top, x, y, self.top.w, self.top.h)
	self:uiTexture(self.bottom, x, y + self.h - self.bottom.h, self.bottom.w, self.bottom.h)
	self:uiTexture(self.middle, x, y + self.top.h, self.middle.w, self.h - self.top.h - self.bottom.h)
	local max = math.max(self.max, 1)
	local pos = util.minBound(self.pos, 0, max)
	if self.inverse then y = y + self.h - (pos / max) * (self.h - self.bottom.h - self.top.h - self.sel.h) - self.bottom.h - self.sel.h
	else y = y + (pos / max) * (self.h - self.bottom.h - self.top.h - self.sel.h) + self.top.h
	end
	self:uiTexture(self.sel, x - (self.sel.w - self.top.w) * 0.5, y, self.sel.w, self.sel.h)
end
