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

--- An entry for any kind of lists and such
-- @classmod engine.ui.blocks.block
module(..., package.seeall, class.inherit(Block))

function _M:init(t, text, color, w, h, offset, default_unseen)
	color = color or {255,255,255}
	self.color = color
	self.offset = offset

	Block.init(self, t)

	self.selected = false
	self.default_unseen = true

	t = t or {}
	self.t = t
	self.w, self.h = w, h

	if default_unseen then
		self:shown(false)
	elseif text ~= "" then
		self:generateContainer()
		self:setText(text, nil, default_unseen)
	end
end

function _M:generateContainer()
	local w, h = self.w, self.h
	self.frame = self.parent:makeFrameDO(self.t.frame or "ui/selector", w, h)
	self.frame.container:shown(false)
	self.frame_sel = self.parent:makeFrameDO(self.t.frame_sel or "ui/selector-sel", w, h)
	self.frame_sel.container:shown(false)
	self.cur_frame = self.frame

	self.max_text_w = w - self.frame.b4.w - self.frame.b6.w
	self.up_text_h = (h - self.font_h) / 2
	self.text = core.renderer.text(self.parent.font):translate(0, 0, 10)
	self.text:maxLines(1)
	self.text:textColor(self.color[1] / 255, self.color[2] / 255, self.color[3] / 255, 1)

	self.text_container = core.renderer.container()
	self.text_container:translate(self.frame.b4.w + (self.offset or 0), self.up_text_h, 10)
	self.text_container:add(self.text)

	self.do_container:add(self.frame.container)
	self.do_container:add(self.frame_sel.container)
	self.do_container:add(self.text_container)

	self.uses_own_renderer = false
end

function _M:lazyGenerate()
	if self.default_unseen then
		self.default_unseen = false
		self:generateContainer()
		self:setText(self.lazy_text or "", self.lazy_color, false)
		self:onFocusChange(self.focused)
		self:select(self.selected)
	end
end

function _M:onFocusChange(v)
	-- tween.stop(self.tweenid)
	self.focused = v

	if not self.frame then return end

	self.cur_frame.container:shown(false)
	self.cur_frame = v and self.frame_sel or self.frame
	if self.selected then
		self.cur_frame.container:color(1, 1, 1, 1)
		self.cur_frame.container:shown(true)
	end

	if not v then
		self:stopScrolling()
	end
end

function _M:setText(text, color, lazy_load)
	if self.default_unseen and lazy_load then
		self.lazy_text = text
		self.lazy_color = color
		return
	else
		self:lazyGenerate()
	end	

	if self.str == text then return end
	self.str = text
	if color then
		self.text:textColor(color[1] / 255, color[2] / 255, color[3] / 255, 1)
	end

	self.text:text(text)
	local w = self.text:getStats()
	if w <= self.max_text_w then
		if self.uses_own_renderer then
			self.text_container:remove(self.renderer)
			self.text_container:add(self.text)
			self.renderer = nil
			self.uses_own_renderer = false
		end
	else
		if not self.uses_own_renderer then
			self.renderer = core.renderer.renderer()
			self.renderer:cutoff(0, 0, self.max_text_w, self.h)
			self.text_container:remove(self.text)
			self.text_container:add(self.renderer)
			self.renderer:add(self.text)
			self.uses_own_renderer = true
		end
	end

	self:stopScrolling()
end

function _M:select(v)
	if self.selected == v then return end
	self.selected = v
	if not self.frame then return end
	if v then
		self.cur_frame.container:color(1, 1, 1, 1)
		self.cur_frame.container:shown(v)
		self:startScrolling()
	else
		self:stopScrolling()
		-- self.cur_frame.container:shown(false)
		self.cur_frame.container:tween(8, "a", nil, 0, "linear", function() self.cur_frame.container:shown(false) end)
	end
end

function _M:startScrolling()
	if not self.focused then return end
	if not self.uses_own_renderer then return end
	if not self.frame then return end

	local dirm, dirM
	local w = self.text:getStats()
	if not self.invert_scroll then
		dirm, dirM = 0, -(w - self.max_text_w + 10)
	else
		dirm, dirM = -(w - self.max_text_w + 10), 0
	end
	self.text:tween(4 * #self.str, "x", dirm, dirM, "inOutQuad", function() self.invert_scroll = not self.invert_scroll self:startScrolling() end)
end

function _M:stopScrolling()
	if not self.uses_own_renderer then return end
	if not self.frame then return end

	self.invert_scroll = false
	self.text:tween(8, "x", nil, 0, "inOutQuad")
end

function _M:shown(v)
	if v then self:lazyGenerate() end
	Block.shown(self, v)
end
