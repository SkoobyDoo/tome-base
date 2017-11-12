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
local Base = require "engine.ui.Base"

--- A generic UI separator
-- @classmod engine.ui.Separator
module(..., package.seeall, class.inherit(Base))

function _M:init(t)
	self.dir = assert(t.dir, "no separator dir")
	self.size = assert(t.size, "no separator size")

	self.dest_area = {w = 1, h = 1}
	Base.init(self, t)
end

function _M:generate()
	self.do_container:clear()

	if self.dir == "horizontal" then
		local top = self:getAtlasTexture("ui/border_vert_top.png")
		local middle = self:getAtlasTexture("ui/border_vert_middle.png")
		local bottom = self:getAtlasTexture("ui/border_vert_bottom.png")

		self.do_container:add(core.renderer.fromTextureTable(top, 0, 0))
		self.do_container:add(core.renderer.fromTextureTable(middle, 0, top.h, middle.w, self.size - top.h - bottom.h, true))
		self.do_container:add(core.renderer.fromTextureTable(bottom, 0, self.size - bottom.h))

		self.w, self.h = middle.w, self.size		
	else
		local left = self:getAtlasTexture("ui/border_hor_left.png")
		local middle = self:getAtlasTexture("ui/border_hor_middle.png")
		local right = self:getAtlasTexture("ui/border_hor_right.png")

		self.do_container:add(core.renderer.fromTextureTable(left, 0, 0))
		self.do_container:add(core.renderer.fromTextureTable(middle, left.w, 0, self.size - left.w - right.w, middle.h, true))
		self.do_container:add(core.renderer.fromTextureTable(right, self.size - right.w, 0))

		self.w, self.h = self.size, middle.h
	end
	self.dest_area.w = self.w
	self.dest_area.h = self.h
end
