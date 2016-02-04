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
local Entry = require "engine.ui.blocks.Entry"
local Scrollbar = require "engine.ui.blocks.Scrollbar"

--- A generic UI list
-- @classmod engine.ui.List
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self.list = assert(t.list, "no list list")
	self.w = assert(t.width, "no list width")
	self.h = t.height
	self.nb_items = t.nb_items
	assert(self.h or self.nb_items, "no list height/nb_items")
	self.fct = t.fct
	self.on_select = t.select
	self.on_drag = t.on_drag
	self.display_prop = t.display_prop or "name"
	self.scrollbar = t.scrollbar
	self.all_clicks = t.all_clicks

	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()
	self.renderer = core.renderer.renderer()
	self.renderer:zSort(true)
	self.do_container:add(self.renderer)

	self.sel = 1
	self.scroll = 1
	self.max = #self.list

	local fw, fh = self.w, self.font_h + 6
	self.fw, self.fh = fw, fh

	if not self.h then self.h = self.nb_items * fh end

	self.renderer:cutoff(0, 0, self.w, self.h)

	self.max_display = math.min(self.max, math.floor(self.h / fh))

	-- Draw the scrollbar
	if self.scrollbar then
		self.scrollbar = Scrollbar.new(nil, self.h, self.max - 1)
		self.scrollbar:translate(self.w - self.scrollbar.w, 0, 1)
		self.renderer:add(self.scrollbar:get())
	end

	-- Draw the list items
	for i, item in ipairs(self.list) do
		item._i = i
		self:drawItem(item)
	end

	-- Add UI controls
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if button == "wheelup" and event == "button" then self.scroll = util.bound(self.scroll - 1, 1, self.max - self.max_display + 1)
		elseif button == "wheeldown" and event == "button" then self.scroll = util.bound(self.scroll + 1, 1, self.max - self.max_display + 1) end

		self.sel = util.bound(self.scroll + math.floor(by / self.fh), 1, self.max)
		if (self.all_clicks or button == "left") and event == "button" then self:onUse(button) end
		if event == "motion" and button == "left" and self.on_drag then self.on_drag(self.list[self.sel], self.sel) end
		self:onSelect()
	end)
	self.key:addBinds{
		ACCEPT = function() self:onUse() end,
		MOVE_UP = function()
			self.sel = util.boundWrap(self.sel - 1, 1, self.max) self.scroll = util.scroll(self.sel, self.scroll, self.max_display)
			self:onSelect()
		end,
		MOVE_DOWN = function()
			self.sel = util.boundWrap(self.sel + 1, 1, self.max) self.scroll = util.scroll(self.sel, self.scroll, self.max_display)
			self:onSelect()
		end,
	}
	self.key:addCommands{
		[{"_UP","ctrl"}] = function() self.key:triggerVirtual("MOVE_UP") end,
		[{"_DOWN","ctrl"}] = function() self.key:triggerVirtual("MOVE_DOWN") end,
		_HOME = function()
			self.sel = 1
			self.scroll = util.scroll(self.sel, self.scroll, self.max_display)
			self:onSelect()
		end,
		_END = function()
			self.sel = self.max
			self.scroll = util.scroll(self.sel, self.scroll, self.max_display)
			self:onSelect()
		end,
		_PAGEUP = function()
			self.sel = util.bound(self.sel - self.max_display, 1, self.max)
			self.scroll = util.scroll(self.sel, self.scroll, self.max_display)
			self:onSelect()
		end,
		_PAGEDOWN = function()
			self.sel = util.bound(self.sel + self.max_display, 1, self.max)
			self.scroll = util.scroll(self.sel, self.scroll, self.max_display)
			self:onSelect()
		end,
	}
	self:onSelect()
end

function _M:drawItem(item)
	local text = item[self.display_prop]

	if not item._entry then
		item._entry = Entry.new(nil, "", color, self.fw, self.fh)
		self.renderer:add(item._entry:get())
	end
	item._entry:setText(text, item.color)
end

function _M:select(i)
	self.sel = util.bound(i, 1, #self.list)
	self.scroll = util.scroll(self.sel, self.scroll, self.max_display)
	self:onSelect()
end

function _M:onSelect()
	local item = self.list[self.sel]
	if not item then return end

	if self.last_selected_item and self.last_selected_item ~= item then self.last_selected_item._entry:select(false) end
	item._entry:select(true)
	self.last_selected_item = item

	-- Update scrolling
	local max = math.min(self.scroll + self.max_display - 1, self.max)
	for i, item in ipairs(self.list) do
		if i >= self.scroll and i <= max then
			local pos = (item._i - self.scroll) * self.fh
			item._entry:translate(0, pos, 0)
			item._entry:shown(true)
		else
			item._entry:shown(false)
		end
	end

	if self.scrollbar then self.scrollbar:setPos(self.sel - 1) end

	if rawget(self, "on_select") then self.on_select(item, self.sel) end
end

function _M:onUse(...)
	local item = self.list[self.sel]
	if not item then return end
	self:sound("button")
	if item.fct then item:fct(item, self.sel, ...)
	else self.fct(item, self.sel, ...) end
end
