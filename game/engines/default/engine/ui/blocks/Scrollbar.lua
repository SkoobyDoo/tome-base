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

--- A scrollbar. To scroll stuff. In a scrolling way. That scrolls.
-- @classmod engine.ui.blocks.block
module(..., package.seeall, class.inherit(Block))

function _M:getWidth()
	local UIBase = require "engine.ui.Base"
	local middle = UIBase:getAtlasTexture("ui/scrollbar.png")
	local sel_t = UIBase:getAtlasTexture("ui/scrollbar-sel.png")
	return math.max(middle.w, sel_t.w)
end

function _M:init(t, size, max, pos, inverse)
	Block.init(self, t)

	self.inverse = inverse
	self.max = max or 1
	self.pos = util.minBound(pos or 0, 0, self.max)

	local top = self.parent:getAtlasTexture("ui/scrollbar_top.png")
	local middle = self.parent:getAtlasTexture("ui/scrollbar.png")
	local bottom = self.parent:getAtlasTexture("ui/scrollbar_bottom.png")
	self.top_w = top.w
	self.top_h = top.h
	self.bottom_h = bottom.h
	self.sel_t = self.parent:getAtlasTexture("ui/scrollbar-sel.png")
	local max_w = math.max(self.sel_t.w, top.w, middle.w, bottom.w)

	self.w = max_w
	self.h = size

	self.do_container:add(core.renderer.fromTextureTable(top, -top.w/2, 0):translate(max_w/2, 0, 0))
	self.do_container:add(core.renderer.fromTextureTable(middle, -middle.w/2, top.h, middle.w, size - top.h - bottom.h, true):translate(max_w/2, 0, 0))
	self.do_container:add(core.renderer.fromTextureTable(bottom, -bottom.w/2, size - bottom.h):translate(max_w/2, 0, 0))
	self.sel = core.renderer.fromTextureTable(self.sel_t, -self.sel_t.w/2 + max_w/2, 0)
	self.do_container:add(self.sel:translate(0, 0, 0.1))
end

function _M:onFocusChange(v)
	self.do_container:shown(v)
end

function _M:setMax(max)
	self.max = max
	self:setPos(self.pos)
end

function _M:setPos(pos)
	self.max = math.max(self.max, 1)
	self.pos = util.minBound(pos, 0, self.max)
	if self.pos == self.oldpos and self.max == self.oldmax then return end

	local y
	if self.inverse then
		y = self.h - (self.pos / self.max) * (self.h - self.bottom_h - self.top_h - self.sel_t.h) - self.bottom_h - self.sel_t.h
	else
		y = (self.pos / self.max) * (self.h - self.bottom_h - self.top_h - self.sel_t.h) + self.top_h
	end
	self.sel:translate(0, y, 1)

	self.oldmax = self.max
	self.oldpos = self.pos
end
