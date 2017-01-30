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
local Block = require "engine.ui.blocks.Block"
local Tiles = require "engine.Tiles"

--- A talent icon
-- @classmod engine.ui.blocks.Talent
module(..., package.seeall, class.inherit(Block))

function _M:init(t)
	Block.init(self, t)

	self.plus_t = self.parent:getAtlasTexture("ui/plus.png")
	self.minus_t = self.parent:getAtlasTexture("ui/minus.png")

	self.plus = core.renderer.fromTextureTable(self.plus_t, 0, 0)
	self.minus = core.renderer.fromTextureTable(self.minus_t, 0, 0)

	self.next_x, self.next_y = self.minus_t.w, self.parent.font:height()
	self.text = core.renderer.text(self.parent.font):outline(1):translate(self.minus_t.w, 0, 10)

	self.do_container:add(self.plus:shown(false))
	self.do_container:add(self.minus)
	self.do_container:add(self.text)
end

function _M:updateStatus(text)
	self.text:text(text)
	return self
end

function _M:updateColor(color)
	self.text:color(colors.smart1unpack(color))
	return self
end

function _M:add(talent)
	self.do_container:add(talent:get():translate(self.next_x, self.next_y))
	self.next_x = self.next_x + talent.w + 4
	self.h = self.next_y + talent.h
end

function _M:onFocusChange(v)
	-- self.cur_frame.container:shown(false)
	-- self.cur_frame = v and self.frame_sel or self.frame
	-- self.cur_frame.container:shown(true)
	-- self.cursor:shown(v)
end
