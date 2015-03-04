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

--- A generic UI button
module(..., package.seeall, class.inherit(Base))

function _M:init(t)
	self.dir = assert(t.dir, "no separator dir")
	self.size = assert(t.size, "no separator size")

	Base.init(self, t)
end

function _M:generate()
	if self.dir == "horizontal" then
		self.top = self:getAtlasTexture("ui/border_vert_top.png")
		self.middle = self:getAtlasTexture("ui/border_vert_middle.png")
		self.bottom = self:getAtlasTexture("ui/border_vert_bottom.png")
		self.w, self.h = self.middle.w, self.size
		
	else
		self.left = self:getAtlasTexture("ui/border_hor_left.png")
		self.middle = self:getAtlasTexture("ui/border_hor_middle.png")
		self.right = self:getAtlasTexture("ui/border_hor_right.png")
		self.w, self.h = self.size, self.middle.h
	end
end

function _M:display(x, y, total_w, nb_keyframes)
	if self.dir == "horizontal" then
		-- x = x - math.floor(self.top.w / 2)
		-- y = y - math.floor(self.top.h / 2)
		self:uiTexture(self.top, x, y, self.top.w, self.top.h)
		self:uiTexture(self.bottom, x, y + self.h - self.bottom.h, self.bottom.w, self.bottom.h)
		self:uiTexture(self.middle, x, y + self.top.h, self.middle.w, self.h - self.top.h - self.bottom.h)
	else
		-- x = x - math.floor(self.left.w / 2)
		-- y = y - math.floor(self.left.h / 2)
		self:uiTexture(self.left, x, y, self.left.w, self.left.h)
		self:uiTexture(self.right, x + self.w - self.right.w, y, self.right.w, self.right.h)
		self:uiTexture(self.middle, x + self.left.w, y, self.w - self.left.w - self.right.w, self.middle.h)
	end
end
