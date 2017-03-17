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
local Entry = require "engine.ui.blocks.Entry"
local Scrollbar = require "engine.ui.blocks.Scrollbar"

--- A generic UI list
-- @classmod engine.ui.List
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self.list = assert(t.list, "no list list")
	self.w = assert(t.width, "no list width")
	self.h = t.height
	self.fct = t.fct
	self.on_select = t.select
	self.on_drag = t.on_drag
	self.display_prop = t.display_prop or "name"
	self.scrollbar = t.scrollbar
	self.all_clicks = t.all_clicks
	self.scroll_inertia = 0

	t.require_renderer = true
	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()
	
	self.scroll_container = core.renderer.container()
	self.do_container:add(self.scroll_container)

	self.sel = 1

	local fw, fh = self.w, self.font_h + 6
	self.fw, self.fh = fw, fh

	-- Draw the scrollbar
	if self.scrollbar then
		self.fw = self.w - Scrollbar:getWidth()
	end

	-- Draw the list items
	local max_h = 0
	for i, item in ipairs(self.list) do
		item._i = i
		self:drawItem(item)
		item._entry:translate(0, max_h, 0)
		item._entry.y = max_h
		max_h = max_h + item._entry.h
	end

	if not self.h then self.h = max_h end
	self.do_container:cutoff(0, 0, self.w, self.h)

	self.max = #self.list

	-- Draw the scrollbar
	local sc = self.scrollbar
	self.scrollbar = Scrollbar.new(nil, self.h, max_h - self.h)
	self.scrollbar:translate(self.fw, 0, 1)
	if sc then self.do_container:add(self.scrollbar:get()) end

	-- Add UI controls
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if button == "wheelup" and event == "button" then self.scroll_inertia = math.min(self.scroll_inertia, 0) - 10
		elseif button == "wheeldown" and event == "button" then self.scroll_inertia = math.max(self.scroll_inertia, 0) + 10 end

		self:selectByY((self.scrollbar and self.scrollbar.pos or 0) + y)
		if (self.all_clicks or button == "left") and event == "button" then self:onUse(button) end
		if event == "motion" and button == "left" and self.on_drag then self.on_drag(self.list[self.sel], self.sel) end
	end)
	self.key:addBinds{
		ACCEPT = function() self:onUse() end,
		MOVE_UP = function()
			self.sel = util.boundWrap(self.sel - 1, 1, self.max)
			self:onSelect()
			if not self:isOnScreen(self.list[self.sel]._entry.y) then self.scrollbar.pos = math.min(self.list[self.sel]._entry.y, self.scrollbar.max) end
		end,
		MOVE_DOWN = function()
			self.sel = util.boundWrap(self.sel + 1, 1, self.max)
			self:onSelect()
			if not self:isOnScreen(self.list[self.sel]._entry.y) then self.scrollbar.pos = math.min(self.list[self.sel]._entry.y, self.scrollbar.max) self.oldpos = self.scrollbar.max end
		end,
	}
	self.key:addCommands{
		[{"_UP","ctrl"}] = function() self.key:triggerVirtual("MOVE_UP") end,
		[{"_DOWN","ctrl"}] = function() self.key:triggerVirtual("MOVE_DOWN") end,
		_HOME = function() if self.scrollbar then self.scrollbar.pos = 0 end end,
		_END = function() if self.scrollbar then self.scrollbar.pos = self.scrollbar.max end end,
		_PAGEUP = function() if self.scrollbar then self.scrollbar.pos = util.minBound(self.scrollbar.pos - self.h, 0, self.scrollbar.max) end end,
		_PAGEDOWN = function() if self.scrollbar then self.scrollbar.pos = util.minBound(self.scrollbar.pos + self.h, 0, self.scrollbar.max) end end,
	}
	self:onSelect()
end

function _M:getCurrentText()
	if not self.sel then return "" end
	return self.list[self.sel][self.display_prop]
end

function _M:drawItem(item)
	local text = item[self.display_prop]

	if not item._entry then
		item._entry = Entry.new(nil, text, item.color, self.fw, self.fh, nil, 99, false)
		self.scroll_container:add(item._entry:get())
	end
end

function _M:select(i)
	self.sel = util.bound(i, 1, self.max)
	self:onSelect()
end

function _M:isOnScreen(y)
	if y >= self.scrollbar.pos and y < self.scrollbar.pos + self.h then return true end
end

function _M:selectByY(y)
	for i, item in ipairs(self.list) do
		if y >= item._entry.y and y < item._entry.y + item._entry.h and item._entry.y + item._entry.h - y <= self.h then
			self.sel = i
			break
		end
	end
	self:onSelect()
end

function _M:onSelect()
	local item = self.list[self.sel]
	if not item then return end

	if self.last_selected_item and self.last_selected_item ~= item then self.last_selected_item._entry:select(false) end
	item._entry:select(true)
	self.last_selected_item = item

	if rawget(self, "on_select") then self.on_select(item, self.sel) end
end

function _M:onUse(...)
	local item = self.list[self.sel]
	if not item then return end
	self:sound("button")
	if item.fct then item:fct(item, self.sel, ...)
	else self.fct(item, self.sel, ...) end
end

function _M:display(x, y, nb_keyframes, screen_x, screen_y, offset_x, offset_y, local_x, local_y)
	if self.scrollbar then
		self.scrollbar:setPos(util.minBound(self.scrollbar.pos + self.scroll_inertia, 0, self.scrollbar.max))
		if self.scroll_inertia > 0 then self.scroll_inertia = math.max(self.scroll_inertia - nb_keyframes, 0)
		elseif self.scroll_inertia < 0 then self.scroll_inertia = math.min(self.scroll_inertia + nb_keyframes, 0)
		end
		if self.scrollbar.pos == 0 or self.scrollbar.pos == self.scrollbar.max then self.scroll_inertia = 0 end

		if self.scrollbar.pos ~= self.oldpos then
			local olddir = math.sign((self.oldpos or 0) - self.scrollbar.pos)
			self:selectByY(self.scrollbar.pos + (olddir > 0 and 3 or self.h - 3))
			self.scroll_container:translate(0, -self.scrollbar.pos, 0)
		end
		self.oldpos = self.scrollbar.pos
	end
end

--[[==
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
local Entry = require "engine.ui.blocks.Entry"
local Scrollbar = require "engine.ui.blocks.Scrollbar"

--- A generic UI variable list
-- @classmod engine.ui.VariableList
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self.list = assert(t.list, "no list list")
	self.w = assert(t.width, "no list width")
	self.max_h = t.max_height
	self.fct = t.fct
	self.select = t.select
	self.scrollbar = t.scrollbar
	self.min_items_shown = t.min_items_shown or 3
	self.display_prop = t.display_prop or "name"

	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()

	self.sel = 1
	self.scroll = 1
	self.max = #self.list

	local fw, fh = self.w, self.font_h
	self.fw, self.fh = fw, fh

	self.frame = self:makeFrame(nil, fw, fh)
	self.frame_sel = self:makeFrame("ui/selector-sel", fw, fh)
	self.frame_usel = self:makeFrame("ui/selector", fw, fh)

	-- Draw the scrollbar
	if self.scrollbar then
		self.scrollbar = Scrollbar.new(nil, self.h, self.max - self.max_display)
		self.scrollbar:translate(self.w - self.scrollbar.w, 0, 1)
		self.do_container:add(self.scrollbar:get())
	end

	-- Draw the list items
	local sh = 0
	local minh = 0
	for i, item in ipairs(self.list) do
		local color = item.color or {255,255,255}
		local width = fw - self.frame_sel.b4.w - self.frame_sel.b6.w

		local text = self.font:draw(item[self.display_prop], width, color[1], color[2], color[3])
		local fh = fh * #text + self.frame_sel.b8.w / 3 * 2

		local texs = {}
		for z, tex in ipairs(text) do
			texs[z] = {t=tex._tex, tw=tex._tex_w, th = tex._tex_h, w=tex.w, h=tex.h, y = (z - 1) * self.font_h + self.frame_sel.b8.w / 3}
		end

		item.start_h = sh
		item.fh = fh
		item._texs = texs

		sh = sh + fh
		if i <= self.min_items_shown then minh = sh end
	end
	self.h = math.max(minh, math.min(self.max_h or 1000000, sh))
	if sh > self.h then self.scrollbar = true end

	self.scroll_inertia = 0
	self.scroll = 0
	if self.scrollbar then self.scrollbar = Slider.new{size=self.h, max=sh} end

	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		self.last_input_was_keyboard = false

		if event == "button" and button == "wheelup" then if self.scrollbar then self.scroll_inertia = math.min(self.scroll_inertia, 0) - 5 end
		elseif event == "button" and button == "wheeldown" then if self.scrollbar then self.scroll_inertia = math.max(self.scroll_inertia, 0) + 5 end
		end

		for i = 1, #self.list do
			local item = self.list[i]
			if by + self.scroll >= item.start_h and by + self.scroll < item.start_h + item.fh then
				if self.sel and self.list[self.sel] then self.list[self.sel].focus_decay = self.focus_decay_max end
				self.sel = i
				self:onSelect()
				if button == "left" and event == "button" then self:onUse() end
				break
			end
		end
	end)

	-- Add UI controls
	self.key:addBinds{
		ACCEPT = function() self:onUse() end,
		MOVE_UP = function()
			if self.sel and self.list[self.sel] then self.list[self.sel].focus_decay = self.focus_decay_max end
			self.sel = util.boundWrap(self.sel - 1, 1, self.max) self:onSelect()
		end,
		MOVE_DOWN = function()
			if self.sel and self.list[self.sel] then self.list[self.sel].focus_decay = self.focus_decay_max end
			self.sel = util.boundWrap(self.sel + 1, 1, self.max) self:onSelect()
		end,
	}
end

function _M:onUse()
	local item = self.list[self.sel]
	if not item then return end
	self:sound("button")
	if item.fct then item:fct()
	else self.fct(item, self.sel) end
end

function _M:onSelect()
	local item = self.list[self.sel]
	if not item then return end

	if self.scrollbar then
		local pos = 0
		for i = 1, #self.list do
			local itm = self.list[i]
			pos = pos + itm.fh
			-- we've reached selected row
			if self.sel == i then
				-- check if it was visible if not go scroll over there
				if pos - itm.fh < self.scrollbar.pos then self.scrollbar.pos = util.minBound(pos - itm.fh, 0, self.scrollbar.max)
				elseif pos > self.scrollbar.pos + self.h then self.scrollbar.pos = util.minBound(pos - self.h, 0, self.scrollbar.max)
				end
				break
			end
		end
	end

	if rawget(self, "select") then self.select(item, self.sel) end
end

function _M:display(x, y, nb_keyframes, screen_x, screen_y)
	local by = y
	core.display.glScissor(true, screen_x, screen_y, self.w, self.h)

	if self.scrollbar then
		local tmp_pos = self.scrollbar.pos
		self.scrollbar.pos = util.minBound(self.scrollbar.pos + self.scroll_inertia, 0, self.scrollbar.max)
		if self.scroll_inertia > 0 then self.scroll_inertia = math.max(self.scroll_inertia - nb_keyframes, 0)
		elseif self.scroll_inertia < 0 then self.scroll_inertia = math.min(self.scroll_inertia + nb_keyframes, 0)
		end
		if self.scrollbar.pos == 0 or self.scrollbar.pos == self.scrollbar.max then self.scroll_inertia = 0 end

		y = y + (self.scrollbar and -self.scrollbar.pos or 0)
		self.scroll = self.scrollbar.pos
	end

	for i = 1, self.max do
		local item = self.list[i]
		if not item then break end

		self.frame.h = item.fh
		self.frame_sel.h = item.fh
		self.frame_usel.h = item.fh

		if self.sel == i then
			if self.focused then self:drawFrame(self.frame_sel, x, y)
			else self:drawFrame(self.frame_usel, x, y) end
		else
			self:drawFrame(self.frame, x, y)
			if item.focus_decay then
				if self.focused then self:drawFrame(self.frame_sel, x, y, 1, 1, 1, item.focus_decay / self.focus_decay_max_d)
				else self:drawFrame(self.frame_usel, x, y, 1, 1, 1, item.focus_decay / self.focus_decay_max_d) end
				item.focus_decay = item.focus_decay - nb_keyframes
				if item.focus_decay <= 0 then item.focus_decay = nil end
			end
		end
		for z, tex in pairs(item._texs) do
			if self.text_shadow then self:textureToScreen(tex, x+1 + self.frame_sel.b4.w, y+1 + tex.y, 0, 0, 0, self.text_shadow) end
			self:textureToScreen(tex, x + self.frame_sel.b4.w, y + tex.y)
		end
		y = y + item.fh
	end

	core.display.glScissor(false)

	if self.focused and self.scrollbar then
		self.scrollbar:display(x + self.w - self.scrollbar.w, by)

		self.last_scroll = self.scrollbar.pos
	end
end
==]]
