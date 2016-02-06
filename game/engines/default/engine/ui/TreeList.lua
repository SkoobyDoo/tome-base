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

--- A generic UI tree list
-- @classmod engine.ui.TreeList
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self.tree = assert(t.tree, "no tree tree")
	self.columns = assert(t.columns, "no list columns")
	self.w = assert(t.width, "no tree width")
	self.h = t.height
	self.nb_items = t.nb_items
	assert(self.h or self.nb_items, "no tree height/nb_items")
	self.fct = t.fct
	self.on_drag = t.on_drag
	self.on_expand = t.on_expand
	self.on_drawitem = t.on_drawitem
	self.select = t.select
	self.scrollbar = t.scrollbar
	self.all_clicks = t.all_clicks
	self.level_offset = t.level_offset or 12
	self.key_prop = t.key_prop or "__id"
	self.sel_by_col = t.sel_by_col and {} or nil

	self.fh = t.item_height or (self.font_h + 6)

	self.plus = self:getAtlasTexture("ui/plus.png")
	self.minus = self:getAtlasTexture("ui/minus.png")

	self.items_by_key = {}

	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()

	-- Draw the scrollbar
	if self.scrollbar then
		self.scrollbar = Scrollbar.new(nil, self.h, 1)
		self.scrollbar:translate(self.w - self.scrollbar.w, 0, 1)
		self.use_w = self.w - self.scrollbar.w
		self.do_container:add(self.scrollbar:get())
	else
		self.use_w = self.w
	end

	local w = self.use_w
	local colw = 0
	for j, col in ipairs(self.columns) do
		if type(col.width) == "table" then
			if col.width[2] == "fixed" then
				w = w - col.width[1]
			end
		end
	end
	for j, col in ipairs(self.columns) do
		col.id = j
		if type(col.width) == "table" then
			if col.width[2] == "fixed" then
				col.width = col.width[1]
			end
		else
			col.width = w * col.width / 100
		end
		if self.sel_by_col then
			colw = colw + col.width
			self.sel_by_col[j] = colw
		end
	end

	local fw, fh = self.w, self.fh
	self.fw, self.fh = fw, fh

	if not self.h then self.h = self.nb_items * fh end

	self.max_display = math.floor(self.h / fh)

	-- Draw the tree items
	self:drawTree()

	-- Add UI controls
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if button == "wheelup" and event == "button" then self.scroll = util.bound(self.scroll - 1, 1, self.max - self.max_display + 1)
		elseif button == "wheeldown" and event == "button" then self.scroll = util.bound(self.scroll + 1, 1, self.max - self.max_display + 1) end

			if self.sel and self.list[self.sel] then self.list[self.sel].focus_decay = self.focus_decay_max end
		self.sel = util.bound(self.scroll + math.floor(by / self.fh), 1, self.max)
		if self.sel_by_col then
			for i = 1, #self.sel_by_col do if bx > (self.sel_by_col[i-1] or 0) and bx <= self.sel_by_col[i] then
				self.cur_col = i
				break
			end end
		end
		self:onSelect()
		if self.list[self.sel] and self.list[self.sel].nodes and bx <= self.plus.w and button ~= "wheelup" and button ~= "wheeldown" and event == "button" then
			self:treeExpand(nil)
		else
			if (self.all_clicks or button == "left") and button ~= "wheelup" and button ~= "wheeldown" and event == "button" then self:onUse(button) end
		end
		if event == "motion" and button == "left" and self.on_drag then self.on_drag(self.list[self.sel], self.sel) end
	end)
	self.key:addBinds{
		ACCEPT = function() self:onUse("left") end,
		MOVE_UP = function()
			if self.sel and self.list[self.sel] then self.list[self.sel].focus_decay = self.focus_decay_max end
			self.sel = util.boundWrap(self.sel - 1, 1, self.max) self.scroll = util.scroll(self.sel, self.scroll, self.max_display) self:onSelect()
		end,
		MOVE_DOWN = function()
			if self.sel and self.list[self.sel] then self.list[self.sel].focus_decay = self.focus_decay_max end
			self.sel = util.boundWrap(self.sel + 1, 1, self.max) self.scroll = util.scroll(self.sel, self.scroll, self.max_display) self:onSelect()
		end,
	}
	if self.sel_by_col then
		self.key:addBinds{
			MOVE_LEFT = function() self.cur_col = util.boundWrap(self.cur_col - 1, 1, #self.sel_by_col) self:onSelect() end,
			MOVE_RIGHT = function() self.cur_col = util.boundWrap(self.cur_col + 1, 1, #self.sel_by_col) self:onSelect() end,
		}
	end
	self.key:addCommands{
		[{"_UP","ctrl"}] = function() self.key:triggerVirtual("MOVE_UP") end,
		[{"_DOWN","ctrl"}] = function() self.key:triggerVirtual("MOVE_DOWN") end,
		_HOME = function()
			if self.sel and self.list[self.sel] then self.list[self.sel].focus_decay = self.focus_decay_max end
			self.sel = 1
			self.scroll = util.scroll(self.sel, self.scroll, self.max_display)
			self:onSelect()
		end,
		_END = function()
			if self.sel and self.list[self.sel] then self.list[self.sel].focus_decay = self.focus_decay_max end
			self.sel = self.max
			self.scroll = util.scroll(self.sel, self.scroll, self.max_display)
			self:onSelect()
		end,
		_PAGEUP = function()
			if self.sel and self.list[self.sel] then self.list[self.sel].focus_decay = self.focus_decay_max end
			self.sel = util.bound(self.sel - self.max_display, 1, self.max)
			self.scroll = util.scroll(self.sel, self.scroll, self.max_display)
			self:onSelect()
		end,
		_PAGEDOWN = function()
			if self.sel and self.list[self.sel] then self.list[self.sel].focus_decay = self.focus_decay_max end
			self.sel = util.bound(self.sel + self.max_display, 1, self.max)
			self.scroll = util.scroll(self.sel, self.scroll, self.max_display)
			self:onSelect()
		end,
	}

	self:outputList()
	self:onSelect()
end

function _M:drawItem(item)
	if not item._container then
		item.cols = {}
		item._container = core.renderer.container()
		self.do_container:add(item._container)
	end

	local x = 0
	for i, col in ipairs(self.columns) do
		if not col.direct_draw then
			local fw = col.width
			local level = item.level
			local color = util.getval(item.color, item) or {255,255,255}
			local text
			if type(col.display_prop) == "function" then
				text = col.display_prop(item):toString()
			else
				text = item[col.display_prop or col.sort]
				if type(text) ~= "table" or not text.is_tstring then
					text = util.getval(text, item)
					if type(text) == "table" then text = text:toString() end
				elseif type(text) == "table" and text.is_tstring then
					text = text:toString()
				else
					text = tostring(text)
				end
			end

			if not item.cols[i] then
				local offset = 0
				if i == 1 then
					offset = level * self.level_offset
					if item.nodes then offset = offset + self.plus.w end
				end

				item.cols[i] = {}
				item.cols[i]._entry = Entry.new(nil, "", color, col.width, self.fh, offset)
				item.cols[i]._entry:translate(x, 0, 0)
				local ec = item.cols[i]._entry:get()
				item._container:add(ec)
	
				if i == 1 and item.nodes then
					item.plus = core.renderer.fromTextureTable(self.plus)
					item.minus = core.renderer.fromTextureTable(self.minus)
					item.plus:translate(0, (item.cols[i]._entry.h - self.plus.h) / 2, 0)
					item.minus:translate(0, (item.cols[i]._entry.h - self.minus.h) / 2, 0)
					item.plus:shown(not item.shown)
					item.minus:shown(item.shown)
					ec:add(item.plus)
					ec:add(item.minus)
				end
			end
			item.cols[i]._entry:setText(text, color)
		end
		x = x + col.width
	end
	if self.on_drawitem then self.on_drawitem(item) end
end

function _M:drawTree()
	local recurs recurs = function(list, level)
		for i, item in ipairs(list) do
			item.level = level
			if item[self.key_prop] then self.items_by_key[item[self.key_prop]] = item end
--			self:drawItem(item)
			if item.nodes then recurs(item.nodes, level+1) end
		end
	end
	recurs(self.tree, 0)
end

function _M:outputList()
	local flist = {}
	self.list = flist

	local recurs recurs = function(list)
		for i, item in ipairs(list) do
			flist[#flist+1] = item
			item._i = #flist
			if item.nodes and item.shown then recurs(item.nodes) end
		end
	end
	recurs(self.tree)

	self.max = #self.list
	self.sel = util.bound(self.sel or 1, 1, self.max)
	self.max_display = math.min(math.floor(self.h/self.fh), self.max)
	self.scroll = self.scroll or 1
	self.cur_col = self.cur_col or 1

	if self.scrollbar then self.scrollbar:setMax(self.max - 1) self.scrollbar:setPos(self.sel - 1) end

	self.old_sel = nil self:onSelect()
end

function _M:treeExpand(v, item)
	local item = item or self.list[self.sel]
	if not item then return end
	if v == nil then
		item.shown = not item.shown
	else
		item.shown = v
	end
	
	item.plus:shown(not item.shown)
	item.minus:shown(item.shown)

	for i, sitem in ipairs(item.nodes or {}) do
		sitem._container:shown(item.shown)
	end

	if self.on_expand then self.on_expand(item) end
	self:outputList()
end

function _M:onSelect()
	local item = self.list[self.sel]
	if not item then return end
	if self.old_sel and self.sel == self.old_sel and self.cur_col == self.old_col then return end

	-- Update scrolling
	local max = math.min(self.scroll + self.max_display - 1, self.max)
	for i, item in ipairs(self.list) do
		if i >= self.scroll and i <= max then
			local pos = (item._i - self.scroll) * self.fh
			self:drawItem(item)
			item._container:translate(0, pos, 0)
			item._container:shown(true)
		else
			if item._container then item._container:shown(false) end
		end
	end

	if self.last_selected_item and self.last_selected_item ~= item then
		if self.last_selected_item.cols then for i, c in ipairs(self.last_selected_item.cols) do c._entry:select(false) end end
	end
	if self.sel_by_col then
		if item.cols then for i, c in ipairs(item.cols) do c._entry:select(self.cur_col == i) end end
	else
		if item.cols then for i, c in ipairs(item.cols) do c._entry:select(true) end end
	end
	self.last_selected_item = item

	if self.scrollbar then self.scrollbar:setPos(self.sel - 1) end

	if rawget(self, "select") then self.select(item, self.sel) end

	self.old_sel = self.sel
	self.old_col = self.cur_col
end

function _M:onUse(...)
	local item = self.list[self.sel]
	if not item then return end
	self:sound("button")
	if item.fct then item.fct(item, self.sel, ...)
	else self.fct(item, self.sel, ...) end
end
