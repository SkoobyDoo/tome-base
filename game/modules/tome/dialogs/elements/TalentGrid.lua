-- ToME - Tales of Maj'Eyal
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
local Base = require "engine.ui.Base"
local Focusable = require "engine.ui.Focusable"
local Scrollbar = require "engine.ui.blocks.Scrollbar"
local Talent = require "mod.dialogs.elements.blocks.Talent"
local Mouse = require "engine.Mouse"

--- A talent trees display
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self.tiles = assert(t.tiles, "no Tiles class")
	self.grid = t.grid or {}
	self.w = assert(t.width, "no width")
	self.h = assert(t.height, "no height")
	self.tooltip = assert(t.tooltip, "no tooltip")
	self.no_tooltip = t.no_tooltip
	self.on_use = assert(t.on_use, "no on_use")
	self.on_expand = t.on_expand

	self.icon_size = 48
	self.frame_size = 50
	self.icon_offset = 1
	self.frame_offset = 5
	
	self.scrollbar = t.scrollbar
	self.scroll_inertia = 0
	
	self.grid_container = core.renderer.container()

	t.require_renderer = true
	Base.init(self, t)
end

function _M:generate()
	self.list_mouse = Mouse.new()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear():zSort(true):cutoff(0, 0, self.w, self.h):setRendererName("TalentGrid")
	self.grid_container:clear():translate(0, 0)
	self.do_container:add(self.grid_container)
	
	-- generate the scrollbar
	self.scroll_inertia = 0

	-- Draw the scrollbar
	if self.scrollbar then
		self.scrollbar = Scrollbar.new(nil, self.h, 1)
		self.scrollbar:translate(self.w - self.scrollbar.w, 0, 1)
		self.use_w = self.w - self.scrollbar.w
		self.do_container:add(self.scrollbar:get())
	else
		self.use_w = self.w
	end
	
	self.sel_i = 1
	self.sel_j = 1
	self.max_h = self.grid.max * (self.frame_size + self.frame_offset)

	self:generateAllItems()
	
	-- Add UI controls
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if event == "button" and button == "wheelup" then if self.scrollbar then self.scroll_inertia = math.min(self.scroll_inertia, 0) - 5 end
		elseif event == "button" and button == "wheeldown" then if self.scrollbar then self.scroll_inertia = math.max(self.scroll_inertia, 0) + 5 end
		else
			self.list_mouse:delegate(button, x, y + (self.scrollbar and self.scrollbar.pos or 0), xrel, yrel, bx, by, event)
		end
		return false
	end)
	self.key:addBinds{
		ACCEPT = function() if self.last_mz then self:onUse(self.last_mz.item, true) end end,
		MOVE_UP = function() self.last_input_was_keyboard = true self:moveSel(0, -1) end,
		MOVE_DOWN = function() self.last_input_was_keyboard = true self:moveSel(0, 1) end,
		MOVE_LEFT = function() self.last_input_was_keyboard = true self:moveSel(-1, 0) end,
		MOVE_RIGHT = function() self.last_input_was_keyboard = true self:moveSel(1, 0) end,
	}
	self.key:addCommands{
		[{"_RETURN","ctrl"}] = function() if self.last_mz then self:onUse(self.last_mz.item, false) end end,
		[{"_UP","ctrl"}] = function() self.last_input_was_keyboard = false if self.scrollbar then self.scroll_inertia = math.min(self.scroll_inertia, 0) - 5 end end,
		[{"_DOWN","ctrl"}] = function() self.last_input_was_keyboard = false if self.scrollbar then self.scroll_inertia = math.max(self.scroll_inertia, 0) + 5 end end,
		_HOME = function() if self.scrollbar then self.scrollbar.pos = 0 end end,
		_END = function() if self.scrollbar then self.scrollbar.pos = self.scrollbar.max end end,
		_PAGEUP = function() if self.scrollbar then self.scrollbar.pos = util.minBound(self.scrollbar.pos - self.h, 0, self.scrollbar.max) end end,
		_PAGEDOWN = function() if self.scrollbar then self.scrollbar.pos = util.minBound(self.scrollbar.pos + self.h, 0, self.scrollbar.max) end end,
		_SPACE = function() if self.last_mz and self.last_mz.item.type then self:onExpand(self.last_mz.item) end end
	}
end

function _M:setListHeight(h)
	self.list_h = h
	if self.scrollbar then self.scrollbar:setMax(h - self.h) end
end

function _M:onUse(item, inc)
	self.on_use(item, inc)
	self:drawItem(item, true)
end

function _M:updateTooltip()
	if not self.cur_item then return end
	local str = self.tooltip(self.cur_item)
	if not self.no_tooltip then game:tooltipDisplayAtMap(game.w, game.h, str) end
end

function _M:moveSel(i, j)
	if j ~= 0 then
		if j > 0 then
			if self.grid[self.sel_i][self.sel_j+1] then self.sel_j = self.sel_j + 1
			else self.sel_j = 1
			end
		else
			if self.grid[self.sel_i][self.sel_j-1] then self.sel_j = self.sel_j - 1
			else self.sel_j = #(self.grid[self.sel_i])
			end
		end
	end

	if i ~= 0 then
		self.sel_i = util.boundWrap(self.sel_i + i, 1, #self.grid)
	end
	self.sel_j = util.bound(self.sel_j, 1, #self.grid[self.sel_i])

	self:setSel(self.sel_i, self.sel_j, true)
end

function _M:setSel(i, j, v)
	self.sel_i, self.sel_j = i, j
	if self.cur_item then self.cur_item._block:setSel(false) end

	if v then
		self.cur_item = self.grid[self.sel_i][self.sel_j]
		self.cur_item._block:setSel(true)
	else
		local item = self.grid[self.sel_i][self.sel_j]
		item._block:setSel(false)
		self.cur_item = nil
	end
	self:updateTooltip()

end

function _M:drawItem(item, rebuild)
	if item.talent then
		if not rebuild then
			item._block = Talent.new(nil, item, item.entity, self.frame_size, "ui/selector-sel", "ui/icon-frame/frame", true)
			self.grid_container:add(item._block:get())
		end
		item._block:updateColor(item:color()):updateShadow(item:do_shadow())
	end
end

function _M:generateAllItems()
	for i = 1, #self.grid do
		local tree = self.grid[i]
		for j = 1, #tree do
			local tal = tree[j]
			self:drawItem(tal, false)
			local x, y = (i-1) * (self.frame_size + self.frame_offset), (j-1) * (self.frame_size + self.frame_offset)
			tal._block:translate(x, y)
			self.mouse:registerZone(x, y, self.frame_size, self.frame_size, function(button, x, y, xrel, yrel, bx, by, event)
				self:setSel(i, j, true)
				if event == "button" and button == "left" then self:onUse(self.cur_item, true)
				elseif event == "button" and button == "left" then self:onUse(self.cur_item, false)
				end
			end)
		end
	end
end

function _M:display(x, y, nb_keyframes)
	if self.scrollbar then
		local oldpos = self.scrollbar.pos
		self.scrollbar:setPos(util.minBound(self.scrollbar.pos + self.scroll_inertia, 0, self.scrollbar.max))
		if self.scroll_inertia > 0 then self.scroll_inertia = math.max(self.scroll_inertia - nb_keyframes, 0)
		elseif self.scroll_inertia < 0 then self.scroll_inertia = math.min(self.scroll_inertia + nb_keyframes, 0)
		end
		if self.scrollbar.pos == 0 or self.scrollbar.pos == self.scrollbar.max then self.scroll_inertia = 0 end

		if self.scrollbar.pos ~= oldpos then
			self.grid_container:translate(0, -self.scrollbar.pos, 0)
		end
	end
end
