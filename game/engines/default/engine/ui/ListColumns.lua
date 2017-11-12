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
local TreeList = require "engine.ui.TreeList"

--- A generic UI multi columns list
-- @classmod engine.ui.ListColumns
module(..., package.seeall, class.inherit(TreeList))

function _M:init(t)
	t.tree = assert(t.list, "no list entires")
	t.columns = assert(t.columns, "no list columns")
	t.w = assert(t.width, "no list width")
	assert(t.height or t.nb_items, "no list height/nb_items")
	-- self.sortable = t.sortable
	-- self.on_drag_end = t.on_drag_end

	TreeList.init(self, t)
end

function _M:selectColumn(i, force, reverse)
	-- DGDGDGDG
end
