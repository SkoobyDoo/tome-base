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

--- A text entry zone
-- @classmod engine.ui.blocks.block
module(..., package.seeall, class.inherit(Block))

function _M:init(t, text, color, w, h)
	color = color or {255,255,255}

	Block.init(self, t)

	self.cursor_t = self.parent:getAtlasTexture("ui/textbox-cursor.png")
	self.cursor = core.renderer.fromTextureTable(self.cursor_t, 0, 0)

	self.frame = self.parent:makeFrameDO("ui/textbox", nil, nil, w, h)
	self.frame_sel = self.parent:makeFrameDO("ui/textbox-sel", nil, nil, w, h)
	self.frame_sel.container:shown(false)
	self.cur_frame = self.frame
	
	self.w, self.h = self.frame.w, self.frame.h

	self.text = core.renderer.text(self.parent.font)
	self.text:translate(self.frame.b4.w, (self.h - self.parent.font_h) / 2, 10)
	self.text:textColor(color[1] / 255, color[2] / 255, color[3] / 255, 1)
	
	self.do_container:add(self.frame.container)
	self.do_container:add(self.frame_sel.container)
	self.do_container:add(self.text)
	self.do_container:add(self.cursor)

	self:setText(text)
	self:setPos(#text)
end

function _M:onFocusChange(v)
	self.cur_frame.container:shown(false)
	self.cur_frame = v and self.frame_sel or self.frame
	self.cur_frame.container:shown(true)
	self.cursor:shown(v)
end

function _M:setText(text, color)
	if color then
		self.text:textColor(color[1] / 255, color[2] / 255, color[3] / 255, 1)
	end
	self.text:text(text)
	self.lasttext = text
end

function _M:setPos(i)
	local size = self.text:getLetterPosition(i)
	self.cursor:translate(self.frame.b4.w - self.cursor_t.w / 2 + size, (self.h - self.cursor_t.h) / 2, 11)
end

function _M:showCursor(v)
	self.cursor:color(1, 1, 1, v and 1 or 0)
end
