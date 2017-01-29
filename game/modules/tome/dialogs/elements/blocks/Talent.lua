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

local tiles_cache = Tiles.new(64, 64, "/data/font/DroidSansMono.ttf", 16, true, true)
tiles_cache.use_images = true
tiles_cache.force_back_color = {r=0, g=0, b=0}

function _M:init(t, entity, size, frame, frame_sel, talent_frame)
	Block.init(self, t)

	self.frame = self.parent:makeFrameDO(frame, size, size)
	self.frame.container:shown(true)
	self.frame_sel = self.parent:makeFrameDO(frame_sel, size, size)
	self.frame_sel.container:shown(false)
	self.cur_frame = self.frame
	self.talent_frame = self.parent:makeFrameDO(talent_frame, size, size)
	
	self.w, self.h = self.talent_frame.w, self.talent_frame.h

	self.do_container:add(self.frame.container)
	self.do_container:add(self.frame_sel.container)
	self.do_container:add(self.talent_frame.container)
	self.do_container:add(entity:getEntityDisplayObject(tiles_cache, size, size, 1, false, false, true):translate(0, 0, 20))
end

function _M:onFocusChange(v)
	self.cur_frame.container:shown(false)
	self.cur_frame = v and self.frame_sel or self.frame
	self.cur_frame.container:shown(true)
	-- self.cursor:shown(v)
end
