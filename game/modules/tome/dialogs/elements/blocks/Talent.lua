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

function _M:init(t, item, entity, size, frame, talent_frame, no_text)
	Block.init(self, t)

	self.item = item

	self.talent_frame = self.parent:makeFrameDO(talent_frame, size, size)
	
	self.w, self.h = self.talent_frame.w, self.talent_frame.h

	self.do_container:add(self.talent_frame.container)
	self.do_container:add(entity:getEntityDisplayObject(tiles_cache, size - 6, size - 6, 1, false, false, true):translate(3, 3, 20))
	self.shadow = core.renderer.colorQuad(3, 3, size - 6, size - 6, 0, 0, 0, 0.85):translate(0, 0, 50):shown(false)
	self.do_container:add(self.shadow)

	if not no_text then
		self.text = core.renderer.text(self.parent.font):outline(1)
		self.do_container:add(self.text)
		self.h = math.ceil(self.h + self.parent.font:height())
	end

	self.frame = self.parent:makeFrameDO(frame, self.w, self.h)
	self.frame.container:shown(false)
	self.do_container:add(self.frame.container)
end

function _M:setSel(v)
	if self.is_sel ~= v then
		self.frame.container:shown(v)
		self.is_sel = v
	end
end

function _M:updateStatus(text)
	self.text:text(text)
	local w, h = self.text:getStats()
	self.text:translate((self.w - w) / 2, self.h - h, 10)
	return self
end

function _M:updateColor(color)
	self.talent_frame.container:color(colors.smart1unpack(color))
	return self
end

function _M:updateShadow(v)
	self.shadow:shown(v)
	return self
end

function _M:onFocusChange(v)
	self.frame.container:tween(8, "a", nil, v and 1 or 0.5)
end
