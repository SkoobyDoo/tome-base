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
	t.require_renderer = true
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
	self.sel_by_col = t.sel_by_col
	self.col_width = {}
	self.floating_headers = (t.floating_headers == nil and true) or t.floating_headers
	self.hide_columns = t.hide_columns

	self.fh = t.item_height or (self.font_h + 6)

	self.plus = self:getAtlasTexture("ui/plus.png")
	self.minus = self:getAtlasTexture("ui/minus.png")

	self.items_by_key = {}

	Base.init(self, t)
end

function _M:hasHeader()
	return self._has_header and not self.hide_columns
end

function _M:headerOffset()
	if not self:hasHeader() or not self.floating_headers then
		return 0
	else
		return 1
	end
end

function _M:selMin()
	if self:hasHeader() and not self.floating_headers then
		return 2
	else
		return 1
	end
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear():zSort(true):countDraws(false)

	-- Draw the scrollbar
	if self.scrollbar then
		self.scrollbar = Scrollbar.new(nil, self.h, 1)
		self.scrollbar:translate(self.w - self.scrollbar.w, 0, 1)
		self.use_w = self.w - self.scrollbar.w
		self.do_container:add(self.scrollbar:get())
	else
		self.use_w = self.w
	end

	self.item_container = core.renderer.container()
	self.do_container:add(self.item_container)

	local fw, fh = self.w, self.fh
	self.fw, self.fh = fw, fh

	if not self.h then self.h = self.nb_items * fh end

	self:setColumns(self.columns)

	-- Add UI controls
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if button == "wheelup" and event == "button" then self.scroll = util.bound(self.scroll - 1, 1, math.max(1, self.max - self.max_display + 1))
		elseif button == "wheeldown" and event == "button" then self.scroll = util.bound(self.scroll + 1, 1, math.max(1, self.max - self.max_display + 1)) end

		local sel = self.scroll + math.floor(by / self.fh) - self:headerOffset()
		if (button == "left" or button == "right") and self:hasHeader() and (sel < self.scroll or sel < self:selMin()) then
			local col
			for i = 1, #self.col_width do if bx <= self.col_width[i] then
				col = i
				break
			end end
			if col  then self:sortByColumn(col, button == "right") return end
		end
		self.sel = util.bound(sel, self:selMin(), self.max)
		if self.sel_by_col then
			for i = 1, #self.col_width do if bx <= self.col_width[i] then
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
		MOVE_UP = function() self:onSelect(util.boundWrap(self.sel - 1, 1, self.max)) end,
		MOVE_DOWN = function() self:onSelect(util.boundWrap(self.sel + 1, 1, self.max)) end,
	}
	if self.sel_by_col then
		self.key:addBinds{
			MOVE_LEFT = function() self.cur_col = util.boundWrap(self.cur_col - 1, 1, #self.columns) self:onSelect() end,
			MOVE_RIGHT = function() self.cur_col = util.boundWrap(self.cur_col + 1, 1, #self.columns) self:onSelect() end,
		}
	end
	self.key:addCommands{
		[{"_UP","ctrl"}] = function() self.key:triggerVirtual("MOVE_UP") end,
		[{"_DOWN","ctrl"}] = function() self.key:triggerVirtual("MOVE_DOWN") end,
		_HOME = function() self:onSelect(1) end,
		_END = function() self:onSelect(self.max) end,
		_PAGEUP = function() self:onSelect(self.sel - self.max_display) end,
		_PAGEDOWN = function() self:onSelect(self.sel + self.max_display) end,
	}

	self:walkTree()
	self:outputList()
end

function _M:setColumns(columns)
	if self.columns and self.columns._container then
		self.columns._container:removeFromParent()
	end

	self.columns = columns
	self.columns._is_header = true
	self.columns.level = 0

	self.col_width = {}

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
		colw = colw + col.width
		self.col_width[j] = colw
	end

	local has_header = false
	for j, col in ipairs(self.columns) do
		if col.name then
			has_header = true
			break
		end
	end

	self._has_header = has_header

	if self:hasHeader() then
		self:drawItem(self.columns)
		if self.floating_headers then
			self.columns._container:translate(0, 0)
			self.do_container:add(self.columns._container)
		end
	end

	self.max_display = math.floor(self.h / self.fh) - self:headerOffset()
	self.item_container:translate(0, self.fh * self:headerOffset(), 0)

	self:walkTree(true)
	self:outputList()
end

function _M:sortByColumn(column, reverse)
	local col = self.columns[column]
	if not col.sort then return end
	reverse = reverse and true or false

	if self._last_sort and self._last_sort ~= column then
		-- reenumerate stuff
		self:walkTree()
	end
	self._last_sort = column
	local function cmpf(a, b)
		-- true if less, false if greater, nil if equal
		if a < b then
			return not reverse
		elseif a > b then
			return reverse
		else
			return nil
		end
	end
	local function sortf(a, b)
		av = util.getitem(a, col.sort)
		bv = util.getitem(b, col.sort)
		local ok, cmpres = pcall(cmpf, av, bv)
		if not ok then cmpres = cmpf(tostring(av), tostring(bv)) end
		if cmpres ~= nil then
			return cmpres
		else
			return cmpf(a._number, b._number)
		end
	end
	local function recursive_sort(nodes)
		local ok, err = pcall(table.sort, nodes, sortf)  --in case our order function is invalid
		if not ok and err ~= "invalid order function for sorting" then error(err) end
		for i, node in ipairs(nodes) do
			if node.nodes then recursive_sort(node.nodes) end
		end
	end
	recursive_sort(self.tree)
	self:outputList()
end

function _M:setTree(tree)
	self.tree = tree
	self:walkTree(true)
	self:outputList()
end
function _M:setList(tree) -- the name is a bit misleading but legacy
	self:setTree(tree)
end

function _M:drawItem(item)
	local is_header = item._is_header
	if not item._container then
		item.cols = {}
		item._container = core.renderer.container()
	end

	local x = 0
	for i, col in ipairs(self.columns) do
		if not col.direct_draw then
			local fw = col.width
			local level = item.level
			local color = util.getval(item.color, item) or {255,255,255}
			local text

			if is_header then
				text = tostring(item[i].name)
			elseif type(col.display_prop) == "function" then
				text = tostring(col.display_prop(item))
			else
				text = item[col.display_prop or col.sort]
				if type(text) == "table" and text.is_tstring then
					text = tostring(text)
				else
					text = tostring(util.getval(text, item))
				end
			end

			if not item.cols[i] then
				local offset = 0
				if i == 1 then
					offset = level * self.level_offset
					if item.nodes then offset = offset + self.plus.w end
				end

				item.cols[i] = {}
				local opts = {}
				if is_header then
					opts = {frame="ui/heading-sel", frame_sel="ui/heading"}
				end
				item.cols[i]._entry = Entry.new(opts, text, color, col.width - offset, self.fh, offset, true)
				item.cols[i]._entry:translate(x + offset, 0, 0)
				item.cols[i]._entry:select(is_header)
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
			else
				item.cols[i]._entry:setText(text, color)
			end
			item.cols[i]._value = text
		end
		x = x + col.width
	end
	if self.on_drawitem then self.on_drawitem(item) end
	item.__drawn = true
end

function _M:walkTree(purge_cache)
	local recurs recurs = function(list, level, count)
		for i, item in ipairs(list) do
			item.level = level
			item._number = count
			count = count + 1
			if item[self.key_prop] then self.items_by_key[item[self.key_prop]] = item end
			if purge_cache then item.cols = nil end
			if item.nodes then count = recurs(item.nodes, level+1, count) end
		end
		return count
	end
	recurs(self.tree, 0, 0)
end

function _M:outputList()
	local flist = {}
	self.list = flist

	if self:hasHeader() and not self.floating_headers then
		flist[#flist+1] = self.columns
	end

	local recurs recurs = function(list, level)
		for i, item in ipairs(list) do
			flist[#flist+1] = item
			item._i = #flist
			if item.nodes and item.shown then recurs(item.nodes, level+1) end
		end
	end
	recurs(self.tree, 0)

	self.max = #self.list
	self.sel = util.bound(self.sel or self:selMin(), self:selMin(), self.max)
	self.scroll = self.scroll or 1
	self.cur_col = self.cur_col or 1

	if self.scrollbar then
		self.scrollbar:setMax(self.max - self.max_display)
		self.scrollbar:setPos(self.scroll - 1)
	end

	-- Generate all items, in lazy mode
	self.item_container:clear()
	for i = 1, self.max do
		local item = self.list[i]
		if item then
			self:drawItem(item)
			self.item_container:add(item._container)
		end
	end

	self.old_sel = nil
	self:onSelect()
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

	if self.on_expand then self.on_expand(item) end
	self:outputList()
end

function _M:onSelect(sel)
	if sel then
		self.sel = util.bound(sel, 1, self.max)
		self.scroll = util.scroll(self.sel, self.scroll, self.max_display)
	end
	if self.old_sel and self.sel == self.old_sel and self.cur_col == self.old_col then return end
	local item = nil
	if #self.tree > 0 then
		item = self.list[self.sel]
	end
	if not item then return end

	-- Update scrolling
	local pos = 0
	local max = math.min(self.scroll + self.max_display - 1, self.max)
	for i = 1, self.max do
		local item = self.list[i]
		if item then
			if i >= self.scroll and i <= max then
				item._container:translate(0, pos, 0)
				for c = 1, #item.cols do item.cols[c]._entry:shown(true) end
				pos = pos + self.fh
			else
				for c = 1, #item.cols do item.cols[c]._entry:shown(false) end
			end
		end
	end

	if self.last_selected_item and self.last_selected_item ~= item then
		-- print("LAST", self.last_selected_item)
		-- table.print(self.last_selected_item)
		if self.last_selected_item.cols then for i, c in ipairs(self.last_selected_item.cols) do c._entry:select(false) end end
	end
	if not self.display_only then
		if self.sel_by_col then
			if item.cols then for i, c in ipairs(item.cols) do c._entry:select(self.cur_col == i) end end
		else
			if item.cols then for i, c in ipairs(item.cols) do c._entry:select(true) end end
		end
	end
	self.last_selected_item = item

	if self.scrollbar then self.scrollbar:setPos(self.scroll - 1) end

	if not self.display_only and rawget(self, "select") then self.select(item, self.sel) end

	self.old_sel = self.sel
	self.old_col = self.cur_col
	self.old_scroll = self.scroll
end

function _M:onUse(...)
	local item = self.list[self.sel]
	if not item then return end
	self:sound("button")
	if item.fct then item.fct(item, self.sel, ...)
	else self.fct(item, self.sel, ...) end
end
