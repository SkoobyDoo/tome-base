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
local Focusable = require "engine.ui.Focusable"
local Scrollbar = require "engine.ui.blocks.Scrollbar"

--- A generic UI text zone
-- @classmod engine.ui.Textzone
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self.text = tostring(assert(t.text, "no textzone text"))
	
	if t.auto_height then t.height = 1 end
	if t.auto_width then t.width = 1 end
	
	self.w = assert(t.width, "no list width")
	self.h = assert(t.height, "no list height")
	self.scrollbar = t.scrollbar
	self.auto_height = t.auto_height
	self.auto_width = t.auto_width
	self.has_box = t.has_box
	self.has_box_alpha = t.has_box_alpha
	self.fct = t.fct

	self.dest_area = t.dest_area and t.dest_area or { h = self.h }
	
	self.color = t.color or {r=255, g=255, b=255}
	if t.can_focus ~= nil then self.can_focus = t.can_focus end
	self.scroll_inertia = 0

	if t.config then t.config(self) end

	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()
	self.text_container = core.renderer.container()

	local tstr = self.text:toTString()

	if self.auto_width then self.w = tstr:maxWidth(self.font) end

	local draw_max_w
	if self.scrollbar then draw_max_w = self.w - Scrollbar:getWidth()
	else draw_max_w = self.w end

	local strs = self.text:splitLines(self.w, self.font)
	local max_lines = #strs

	local last_text = nil
	for i, str in ipairs(strs) do
		local textzone = core.renderer.text(self.font)
		self:applyShadowOutline(textzone)
		if not last_text then textzone:textColor(self.color.r / 255, self.color.g / 255, self.color.b / 255, 1)
		else textzone:setFrom(last_text) end
		textzone:text(str)
		textzone:translate(0, (i - 1) * self.font_h, 10)
		self.text_container:add(textzone)
		last_text = textzone
	end
	self.max = max_lines

	if self.auto_height then 
		self.h = self.font_h * max_lines 
		self.dest_area.h = self.h 
	end

	self.max_display = max_lines * self.font_h

	if self.max_display > self.h then
		self.do_renderer = core.renderer.renderer()
		self.do_renderer:cutoff(0, 0, self.w, self.h)
		self.do_renderer:add(self.text_container)
		self.do_container:add(self.do_renderer)
	else
		self.do_container:add(self.text_container)
	end

	if self.scrollbar and self.do_renderer then
		self.scrollbar = Scrollbar.new(nil, self.h, self.max_display - self.h)
		self.scrollbar:translate(self.w - self.scrollbar.w, 0, 1)
		self.do_container:add(self.scrollbar:get())
	else
		self.scrollbar = nil
	end

	if self.has_box then
		local kind = self.has_box == true and "ui/textbox" or self.has_box
		local frame = self:makeFrameDO(kind, nil, nil, self.w, self.h)
		frame.container:translate(-frame.b4.w, -frame.b8.h, 0)
		frame.container:color(1, 1, 1, self.has_box_alpha or 1)
		self.do_container:add(frame.container)
	end

	-- Add UI controls
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if self.fct and button == "left" and event == "button" then self.fct() end
		if button == "wheelup" and event == "button" then self.key:triggerVirtual("MOVE_UP")
		elseif button == "wheeldown" and event == "button" then self.key:triggerVirtual("MOVE_DOWN")
		end
		if button == "middle" and self.scrollbar then
			if not self.scroll_drag then
				self.scroll_drag = true
				self.scroll_drag_x_start = bx
				self.scroll_drag_y_start = by
			else
				self.scrollbar.pos = util.minBound(self.scrollbar.pos + by - self.scroll_drag_y_start, 0, self.scrollbar.max)
				self.scroll_drag_x_start = bx
				self.scroll_drag_y_start = by
			end
		else
			self.scroll_drag = false
		end
	end)
	
	self.key:addBinds{
		MOVE_UP = function() if self.scrollbar then self.scroll_inertia = math.min(self.scroll_inertia, 0) - 10  end end,
		MOVE_DOWN = function() if self.scrollbar then self.scroll_inertia = math.max(self.scroll_inertia, 0) + 10  end end,
	}
	
	self.key:addCommands{
		_HOME = function() if self.scrollbar then self.scrollbar.pos = 0 end end,
		_END = function() if self.scrollbar then self.scrollbar.pos = self.scrollbar.max end end,
		_PAGEUP = function() if self.scrollbar then self.scrollbar.pos = util.minBound(self.scrollbar.pos - self.h, 0, self.scrollbar.max) end end,
		_PAGEDOWN = function() if self.scrollbar then self.scrollbar.pos = util.minBound(self.scrollbar.pos + self.h, 0, self.scrollbar.max) end end,
	}
end

function _M:isScrollable()
	return self.max_display and self.max_display > self.h and self.scrollbar
end

function _M:setText(text)
	self.text = text
	self:generate()
end

function _M:startAutoScrolling()
	if not self.do_renderer then return end
	self.pingpong = true

	local dirm, dirM
	local h = self.max_display
	if not self.invert_scroll then
		dirm, dirM = nil, -(h - self.h + 10)
	else
		dirm, dirM = nil, 0
	end
	self.text_container:tween(h / 3, "y", dirm, dirM, "inOutQuad",
		function() self.invert_scroll = not self.invert_scroll self:startAutoScrolling() end,
		function(x, y, z) if self.scrollbar then self.scrollbar:setPos(-y) end end
	)
end

function _M:stopAutoScrolling()
	if not self.do_renderer then return end
	self.pingpong = false

	self.invert_scroll = false
	self.text_container:tween(8, "y", nil, 0, "inOutQuad")
end

function _M:display(x, y, nb_keyframes, screen_x, screen_y, offset_x, offset_y, local_x, local_y)
	if self.scrollbar then
		local oldpos = self.scrollbar.pos
		self.scrollbar:setPos(util.minBound(self.scrollbar.pos + self.scroll_inertia, 0, self.scrollbar.max))
		if self.scroll_inertia > 0 then self:stopAutoScrolling() self.scroll_inertia = math.max(self.scroll_inertia - nb_keyframes, 0)
		elseif self.scroll_inertia < 0 then self:stopAutoScrolling() self.scroll_inertia = math.min(self.scroll_inertia + nb_keyframes, 0)
		end
		if self.scrollbar.pos == 0 or self.scrollbar.pos == self.scrollbar.max then self.scroll_inertia = 0 end

		if self.scrollbar.pos ~= oldpos then
			self.text_container:translate(0, -self.scrollbar.pos, 0)
		end
	end
end
