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
local Tiles = require "engine.Tiles"
local Base = require "engine.ui.Base"
local Slider = require "engine.ui.Slider"
local Focusable = require "engine.ui.Focusable"

--- A generic UI image list
-- @classmod engine.ui.ImageList
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self.tile_w = assert(t.tile_w, "no image list tile width")
	self.tile_h = assert(t.tile_h, "no image list tile height")
	self.w = assert(t.width, "no image list width")
	self.h = assert(t.height, "no image list  height")
	self.list = assert(t.list, "no image list list")
	self.fct = assert(t.fct, "no image list fct")
	self.padding = t.padding or 6
	self.force_size = t.force_size
	self.scrollbar = t.scrollbar
	self.selection = t.selection
	self.on_select = t.on_select
	self.root_loader = t.root_loader

	self.nb_w = math.floor(self.w / (self.tile_w + self.padding))
	self.nb_h = math.floor(self.h / (self.tile_h + self.padding))

	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()
	local frame_container = core.renderer.container()
	local sel_container = core.renderer.container()
	local image_container = core.renderer.container():translate(0, 0, 1)
	self.do_container:add(frame_container):add(sel_container):add(image_container)
	self.frame_container = frame_container
	self.sel_container = sel_container

	local frame_selected = nil
	local frame_sel = self:makeFrameDO("ui/selector-sel", self.tile_w, self.tile_h)
	local frame_usel = self:makeFrameDO("ui/selector", self.tile_w, self.tile_h)
	if self.selection then
		frame_selected = self:makeFrameDO("ui/selector-green", self.tile_w, self.tile_h)
	end

	self.scroll = 1
	self.dlist = {}
	self.items = {}
	local row = {}
	for i, data in ipairs(self.list) do
		local f = data
		if type(data) == "table" then f = f.image end
		if self.root_loader then
			if fs.exists(f) then
				local d, w, h = core.renderer.image(f, 0, 0, self.force_size and self.tile_w or nil, self.force_size and self.tile_h or nil)
				local item = {d=d, w=w, h=h, data=data}
				row[#row+1] = item
				self.items[item] = true
				if #row + 1 > self.nb_w then
					self.dlist[#self.dlist+1] = row
					row = {}
				end
			end
		else
			local s = Tiles:loadImage(f)
			if s then
				local d, w, h = core.renderer.fromSurface(s, 0, 0, self.force_size and self.tile_w or nil, self.force_size and self.tile_h or nil)
				local item = {d=d, w=w, h=h, data=data}
				row[#row+1] = item
				self.items[item] = true
				if #row + 1 > self.nb_w then
					self.dlist[#self.dlist+1] = row
					row = {}
				end
			end
		end
	end
	self.dlist[#self.dlist+1] = row
	self.max = #self.dlist

	if self.scrollbar then
		self.scrollbar = Slider.new{size=self.h, max=#self.dlist - self.nb_h}
	end

	local by = 0
	for j = 1, #self.dlist do
		local row = self.dlist[j]
		for i = 1, #row do
			local item = row[i]

			local x = (i-1) * (self.tile_w + self.padding)
			local y = by

			item.p_x, item.p_y = x, y
			item.f_focus = self:cloneFrameDO(frame_sel)
			frame_container:add(item.f_focus.container:translate(x, y):color(1, 1, 1, 0))

			if self.selection then
				item.f_selected = self:cloneFrameDO(frame_selected)
				sel_container:add(item.f_selected.container:translate(x, y):color(1, 1, 1, 0))
			end

			if not self.force_size then
				x = (i-1) * (self.tile_w + self.padding) + self.tile_w - item.w
				y = by + self.tile_h - item.h
			end
			image_container:add(item.d:translate(x, y))

			-- if item.selected then self:drawFrame(self.frame_selected, x + (i-1) * (self.tile_w + self.padding), y) end

			-- if self.sel_i == i and self.sel_j == j then
			-- 	if self.focused then self:drawFrame(self.frame_sel, x + (i-1) * (self.tile_w + self.padding), y)
			-- 	else self:drawFrame(self.frame_usel, x + (i-1) * (self.tile_w + self.padding), y) end
			-- else
			-- 	self:drawFrame(self.frame, x + (i-1) * (self.tile_w + self.padding), y)
			-- end

			-- if self.force_size then
			-- 	item[1]:toScreenFull(x + (i-1) * (self.tile_w + self.padding), y, self.tile_w, self.tile_h, item[2] * self.tile_w / item.w, item[3] * self.tile_h / item.h)
			-- else
			-- 	item[1]:toScreenFull(x + (i-1) * (self.tile_w + self.padding) + self.tile_w - item.w, y + self.tile_h - item.h, item.w, item.h, item[2], item[3])
			-- end
		end
		by = by + self.tile_h + self.padding
	end


	self.sel_i = 1
	self.sel_j = 1

	-- Add UI controls
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if self.scrollbar then
			if button == "wheelup" and event == "button" then self.scroll = util.bound(self.scroll - 1, 1, self.scrollbar.max)
			elseif button == "wheeldown" and event == "button" then self.scroll = util.bound(self.scroll + 1, 1, self.scrollbar.max) end
		end

		self.sel_j = util.bound(self.scroll + math.floor(by / (self.tile_h + self.padding)), 1, self.max)
		self.sel_i = util.bound(1 + math.floor(bx / (self.tile_w + self.padding)), 1, self.nb_w)
		if (button == "left" or button == "right") and event == "button" then self:onUse(button) end
		self:onSelect()
	end)
	self.key:addBinds{
		ACCEPT = function() self:onUse() end,
		MOVE_UP = function()
			self.sel_j = util.boundWrap(self.sel_j - 1, 1, self.max) self.scroll = util.scroll(self.sel_j, self.scroll, self.nb_h)
			self:onSelect()
		end,
		MOVE_DOWN = function()
			self.sel_j = util.boundWrap(self.sel_j + 1, 1, self.max) self.scroll = util.scroll(self.sel_j, self.scroll, self.nb_h)
			self:onSelect()
		end,
		MOVE_RIGHT = function()
			self.sel_i = util.boundWrap(self.sel_i + 1, 1, self.nb_w)
			self:onSelect()
		end,
		MOVE_LEFT = function()
			self.sel_i = util.boundWrap(self.sel_i - 1, 1, self.nb_w)
			self:onSelect()
		end,
	}
	self.key:addCommands{
		[{"_UP","ctrl"}] = function() self.key:triggerVirtual("MOVE_UP") end,
		[{"_DOWN","ctrl"}] = function() self.key:triggerVirtual("MOVE_DOWN") end,
		_HOME = function()
			self.sel_j = 1
			self.scroll = util.scroll(self.sel_j, self.scroll, self.nb_h)
			self:onSelect()
		end,
		_END = function()
			self.sel_j = self.max
			self.scroll = util.scroll(self.sel_j, self.scroll, self.nb_h)
			self:onSelect()
		end,
		_PAGEUP = function()
			self.sel_j = util.bound(self.sel_j - self.nb_h, 1, self.max)
			self.scroll = util.scroll(self.sel_j, self.scroll, self.nb_h)
			self:onSelect()
		end,
		_PAGEDOWN = function()
			self.sel_j = util.bound(self.sel_j + self.nb_h, 1, self.max)
			self.scroll = util.scroll(self.sel_j, self.scroll, self.nb_h)
			self:onSelect()
		end,
	}
	self:updateSelection()
end

function _M:getAllSelected()
	local list = {}
	for i, row in ipairs(self.dlist) do for j, item in ipairs(row) do if item.selected then list[#list+1] = item end end end
	return list
end

function _M:getAllSelectedKeys()
	local list = {}
	for i, row in ipairs(self.dlist) do for j, item in ipairs(row) do if item.selected then list[#list+1] = {i,j} end end end
	return list
end

function _M:setSelected(item, v)
	if not self.items[item] then return end
	if v == nil then item.selected = not item.selected
	else item.selected = v end
	self:updateSelection()
end

function _M:updateSelection()
	for i, row in ipairs(self.dlist) do for j, item in ipairs(row) do if item.f_selected then
		if item.selected then
			item.f_selected.container:tween(6, "a", nil, 1)
		else
			item.f_selected.container:tween(6, "a", nil, 0)
		end
	end end end
end

function _M:clearSelection()
	for i, row in ipairs(self.dlist) do for j, item in ipairs(row) do item.selected = false end end
	self:updateSelection()
end

function _M:onUse(button, forcectrl)
	local item = self.dlist[self.sel_j] and self.dlist[self.sel_j][self.sel_i]
	self:sound("button")
	if item then
		if self.selection == "simple" then
			self:clearSelection()
			item.selected = not item.selected
		elseif self.selection == "multiple" then
			item.selected = not item.selected
		elseif self.selection == "ctrl-multiple" then
			if not (forcectrl == true or (forcectrl == nil and core.key.modState("ctrl"))) then self:clearSelection() end
			item.selected = not item.selected
		end
		self:updateSelection()
		self.fct(item, button)
	end
end

function _M:onSelect(how, force)
	local item = self.dlist[self.sel_j] and self.dlist[self.sel_j][self.sel_i]
	if self.prev_item == item and not force then return end
	if self.on_select and item then self.on_select(item, how) end
	self.prev_item = item

	for iitem, _ in pairs(self.items) do
		iitem.f_focus.container:tween(6, "a", nil, iitem == item and 1 or 0)
	end
end

function _M:on_focus(status)
	self.frame_container:tween(7, "a", nil, status and 1 or 0.2)
end

function _M:display(x, y, nb_keyframes, ox, oy)
	for item, _ in pairs(self.items) do
		item.last_display_x = ox + item.p_x
		item.last_display_y = oy + item.p_y
	end
end
