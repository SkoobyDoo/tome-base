-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2016 Nicolas Casalini
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

--- A scrollbar. To scroll stuff. In a scrolling way. That scrolls.
-- @classmod engine.ui.blocks.block
module(..., package.seeall, class.inherit(Block))

function _M:init(t, size, max, pos, inverse)
	Block.init(self, t)

	self.inverse = inverse
	self.max = max
	self.pos = util.minBound(pos or 0, 0, self.max)

	local top = self.parent.ui:getAtlasTexture("ui/scrollbar_top.png")
	local middle = self.parent.ui:getAtlasTexture("ui/scrollbar.png")
	local bottom = self.parent.ui:getAtlasTexture("ui/scrollbar_bottom.png")
	self.top_w = top.w
	self.top_h = top.h
	self.bottom_h = bottom.h
	self.sel_t = self.parent.ui:getAtlasTexture("ui/scrollbar-sel.png")
	self.sel = core.renderer.fromTextureTable(self.sel_t, 0, 0)

	self.w = middle.w
	self.h = size

	self.do_container:add(core.renderer.fromTextureTable(top, 0, 0))
	self.do_container:add(core.renderer.fromTextureTable(middle, 0, top.h, middle.w, size - top.h - bottom.h, true))
	self.do_container:add(core.renderer.fromTextureTable(bottom, 0, size - bottom.h))
	self.do_container:add(self.sel)
end

function _M:onFocusChange(v)
	self.do_container:shown(v)
end

function _M:setPos(pos)
	self.max = math.max(self.max, 1)
	self.pos = util.minBound(pos, 0, self.max)

	local y
	if self.inverse then
		y = self.h - (self.pos / self.max) * (self.h - self.bottom_h - self.top_h - self.sel_t.h) - self.bottom_h - self.sel_t.h
	else
		y = (self.pos / self.max) * (self.h - self.bottom_h - self.top_h - self.sel_t.h) + self.top_h
	end
	self.sel:translate((self.top_w-self.sel_t.w ) * 0.5, y, 1)
end
