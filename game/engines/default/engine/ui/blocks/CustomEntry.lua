-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2018 Nicolas Casalini
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
local Block = require "engine.ui.blocks.Block"

--- An entry for any kind of lists and such
-- @classmod engine.ui.blocks.block
module(..., package.seeall, class.inherit(Block))

function _M:init(t, w, h, inside_do)
	t = t or {}
	Block.init(self, t)

	self.w, self.h = w, h
	self.frame = self.parent:makeFrameDO(t.frame or "ui/selector", w, h)
	self.frame.container:shown(false)
	self.frame_sel = self.parent:makeFrameDO(t.frame_sel or "ui/selector-sel", w, h)
	self.frame_sel.container:shown(false)
	self.cur_frame = self.frame
	self.do_container:add(self.frame.container)
	self.do_container:add(self.frame_sel.container)

	if inside_do then
		self.inside_do = inside_do
		self.do_container:add(inside_do)
	end
end

function _M:select(v)
	if self.selected == v then return end
	self.selected = v
	if not self.frame then return end
	if v then
		self.cur_frame.container:color(1, 1, 1, 1)
		self.cur_frame.container:shown(v)
	else
		-- self.cur_frame.container:shown(false)
		self.cur_frame.container:tween(8, "a", nil, 0, "linear", function() self.cur_frame.container:shown(false) end)
	end
end

function _M:onFocusChange(v)
	self.focused = v

	if not self.frame then return end

	self.cur_frame.container:shown(false)
	self.cur_frame = v and self.frame_sel or self.frame
	if self.selected then
		self.cur_frame.container:color(1, 1, 1, 1)
		self.cur_frame.container:shown(true)
	end
end
