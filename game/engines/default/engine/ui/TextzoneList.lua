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
local Base = require "engine.ui.Base"
local Focusable = require "engine.ui.Focusable"
local Textzone = require "engine.ui.Textzone"

--- A generic UI textzone list
-- @classmod engine.ui.TextzoneList
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self.items = {}
	if t.weakstore then setmetatable(self.items, {__mode="k"}) end
	self.cur_item = nil
	self.w = assert(t.width, "no list width")
	self.h = assert(t.height, "no list height")
	self.scrollbar = t.scrollbar
	self.focus_check = t.focus_check
	self.variable_height = t.variable_height
	self.pingpong = t.pingpong
	self.max_h = 0

	if t.can_focus ~= nil then self.can_focus = t.can_focus end

	Base.init(self, t)
end
function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()

	self.fw, self.fh = self.w, self.font_h

	self.key.receiveKey = function(_, ...)
		if self.cur_item and self.items[self.cur_item] then self.items[self.cur_item].ui.key:receiveKey(...) end
	end
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if self.cur_item and self.items[self.cur_item] then self.items[self.cur_item].ui.mouse:delegate(button, bx, by, xrel, yrel, bx, by, event) end
	end)
end

function _M:createItem(item, text)
	local ui = Textzone.new{width=self.w, height=self.h, auto_height=self.variable_height, fct=function() end, scrollbar=self.scrollbar, text=text}
	self.items[item] = { ui = ui }
end

function _M:on_focus_change(status)
	if self.cur_item and self.items[self.cur_item] then
		self.items[self.cur_item].ui:setFocus(status)
		if not status then
			self.items[self.cur_item].ui:stopAutoScrolling()
		end
	end
end

function _M:switchItem(item, create_if_needed, force)
	if self.cur_item == item and not force then return true end
	if (create_if_needed and not self.items[item]) or force then self:createItem(item, create_if_needed) end
	if not item or not self.items[item] then self.cur_item = nil self.do_container:clear() return false end
	local d = self.items[item]

	self.cur_item = item

	d.ui.mouse.delegate_offset_x = 0
	d.ui.mouse.delegate_offset_y = 0
	d.ui:positioned(ux, uy, 0, 0)
	self.do_container:clear()
	self.do_container:add(d.ui.do_container)

	if self.focus_check then if d.ui:isScrollable() then
		self.can_focus = true
	else
		self.can_focus = false
	end end

	if self.variable_height then
		self.h = d.ui.h
	end

	if self.pingpong then
		d.ui:startAutoScrolling()
	end

	return true
end

function _M:erase()
	self.items = {}
	self.cur_item = nil
	self.do_container:clear()
end

function _M:display(x, y, nb_keyframes, screen_x, screen_y, offset_x, offset_y, local_x, local_y)
	if self.cur_item and self.items[self.cur_item] then
		self.items[self.cur_item].ui:display(x, y, nb_keyframes, screen_x, screen_y, offset_x, offset_y, local_x, local_y)
	end
end
