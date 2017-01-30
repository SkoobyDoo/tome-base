-- ToME - Tales of Maj'Eyal
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
local Talent = require "mod.dialogs.elements.blocks.Talent"
local TalentLine = require "mod.dialogs.elements.blocks.TalentLine"
local Tiles = require "engine.Tiles"

--- A talent trees display
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self.tiles = assert(t.tiles, "no Tiles class")
	self.tree = t.tree or {}
	self.w = assert(t.width, "no width")
	self.h = assert(t.height, "no height")
	self.tooltip = assert(t.tooltip, "no tooltip")
	self.on_use = assert(t.on_use, "no on_use")
	self.on_expand = t.on_expand
	
	self.no_cross = t.no_cross
	self.dont_select_top = t.dont_select_top
	self.no_tooltip = t.no_tooltip
	self.clip_area = t.clip_area or { w = self.w, h = self.h }

	self.icon_size = 48
	self.frame_size = 50
	self.icon_offset = 1
	self.frame_offset = 5
	_, self.fh = self.font:size("")
	self.fh = self.fh - 2
	
	self.scrollbar = t.scrollbar
	self.scroll_inertia = 0
	
	self.shadow = 0.7
	self.last_input_was_keyboard = false

	self.lines_container = core.renderer.container()

	t.require_renderer = true
	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear():zSort(true):cutoff(0, 0, self.w, self.h):setRendererName("TalentTrees")
	self.lines_container:clear():translate(0, 0)
	self.do_container:add(self.lines_container)
	
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
	self.max_h = 0
	
	self.mousezones = {}
	self:redrawAllItems()
	
	-- Add UI controls
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if event == "button" and button == "wheelup" then if self.scrollbar then self:scroll(-1) end
		elseif event == "button" and button == "wheeldown" then if self.scrollbar then self:scroll(1) end
		end
		return false
	end)
	self.key:addBinds{
		ACCEPT = function() if self.last_mz then self:onUse(self.last_mz.item, true) end end,
		MOVE_UP = function() self.last_input_was_keyboard = true self:moveSel(-1, 0) end,
		MOVE_DOWN = function() self.last_input_was_keyboard = true self:moveSel(1, 0) end,
		MOVE_LEFT = function() self.last_input_was_keyboard = true self:moveSel(0, -1) end,
		MOVE_RIGHT = function() self.last_input_was_keyboard = true self:moveSel(0, 1) end,
	}
	self.key:addCommands{
		[{"_RETURN","ctrl"}] = function() if self.last_mz then self:onUse(self.last_mz.item, false) end end,
		[{"_UP","ctrl"}] = function() self.last_input_was_keyboard = false if self.scrollbar then self.scroll_inertia = math.min(self.scroll_inertia, 0) - 5 end end,
		[{"_DOWN","ctrl"}] = function() self.last_input_was_keyboard = false if self.scrollbar then self.scroll_inertia = math.max(self.scroll_inertia, 0) + 5 end end,
		_HOME = function() if self.scrollbar then self.scrollbar.pos = 0 self.last_input_was_keyboard = true self:moveSel(0, 0) end end,
		_END = function() if self.scrollbar then self.scrollbar.pos = self.scrollbar.max self.last_input_was_keyboard = true self:moveSel(0, 0) end end,
		_PAGEUP = function() if self.scrollbar then self.scrollbar.pos = util.minBound(self.scrollbar.pos - self.h, 0, self.scrollbar.max) self.last_input_was_keyboard = true self:moveSel(0, 0) end end,
		_PAGEDOWN = function() if self.scrollbar then self.scrollbar.pos = util.minBound(self.scrollbar.pos + self.h, 0, self.scrollbar.max) self.last_input_was_keyboard = true self:moveSel(0, 0) end end,
		_SPACE = function() if self.last_mz and self.last_mz.item.type then self:onExpand(self.last_mz.item) end end
	}
end

function _M:setListHeight(h)
	self.list_h = h
	if self.scrollbar then self.scrollbar:setMax(h) end
end

function _M:scroll(v)
	if self.scrollbar then
		if v < 0 then self.scroll_inertia = math.min(self.scroll_inertia, 0) + v * 5
		else self.scroll_inertia = math.max(self.scroll_inertia, 0) + v * 5
		end
	end
end

function _M:onUse(item, inc)
	self.on_use(item, inc)
end

function _M:onExpand(item)
	if self.on_expand then self.on_expand(item) end
end

function _M:updateTooltip()
	local str = self.tooltip(self.cur_item)
	if not self.no_tooltip then game:tooltipDisplayAtMap(game.w, game.h, str) end
end

function _M:setSel(item)
	if self.cur_item == item then return end
	self.cur_item = item
	self:updateTooltip()
end

function _M:drawItem(item, parent)
	if item.stat then
		item._block = Talent.new(nil, item, item.entity, self.frame_size, "ui/selector-sel", "ui/icon-frame/frame")
		self.lines_container:add(item._block:get())
		-- local str = item:status():toString()
		-- local d = self.font:draw(str, self.font:size(str), 255, 255, 255, true)[1]
		-- item.text_status = d
	elseif item.type_stat then
		-- local str = item.name:toString()
		-- self.font:setStyle("bold")
		-- local d = self.font:draw(str, self.font:size(str), 255, 255, 255, true)[1]
		-- self.font:setStyle("normal")
		-- item.text_status = d
	elseif item.talent then
		-- local d = self.font:draw(str, self.font:size(str), 255, 255, 255, true)[1]
		-- item.text_status = d
		item._block = Talent.new(nil, item, item.entity, self.frame_size, "ui/selector-sel", "ui/icon-frame/frame")
		item._block:updateStatus(item:status():toString()):updateColor(item:color())
		parent._block:add(item._block)
	elseif item.type then
		item._block = TalentLine.new(nil, item, not item.shown)
		item._block:updateStatus(item:rawname():toString()):updateColor(item:color())
		-- local str = item:rawname():toString()
		-- local c = item:color()
		-- self.font:setStyle("bold")
		-- local d = self.font:draw(str, self.font:size(str), c[1], c[2], c[3], true)[1]
		-- self.font:setStyle("normal")
		-- item.text_status = d
		-- if ((not self.no_cross) and self.plus.w + 3 or 0) + item.text_status.w > self.w - (self.scrollbar and self.scrollbar.sel.w * 0.8 or 0) + 10 then
		-- 	item.text_status.display_offset = { x_dir = 0, x = 0 }
		-- end
	end
end

function _M:on_focus_change(status)
end

function _M:redrawAllItems()
	local y = 0
	local prev_tree = nil
	for i = 1, #self.tree do
		local tree = self.tree[i]
		self:drawItem(tree, nil)
		for j = 1, #tree.nodes do
			local tal = tree.nodes[j]
			self:drawItem(tal, tree)
		end
		if tree._block then
			if prev_tree then prev_tree._block:setNext(tree._block)
			else self.lines_container:add(tree._block:get()) end
			tree._block:collapse(not tree.shown)
			prev_tree = tree
		end
	end

	-- -- calculate each tree items height
	-- self.max_h = 0
	-- for i = 1, #self.tree do
	-- 	local dy = 0
	-- 	local tree = self.tree[i]

	-- 	if tree.text_status then
	-- 		local key = tree.text_status
	-- 		dy = dy + key.h + 4
	-- 	end
	-- 	local addh = 0
	-- 	if tree.shown then for j = 1, #tree.nodes do
	-- 		local tal = tree.nodes[j]
	-- 		if tal.text_status then
	-- 			local key = tal.text_status
	-- 			addh = key.h
	-- 		end
	-- 		addh = addh + self.frame_size
	-- 	end end
	-- 	dy = dy + addh + 12
	-- 	tree.h = dy
	-- 	self.max_h = self.max_h + dy
	-- end
	
	-- -- generate the scrollbar
	-- if self.scrollbar then self.scrollbar.max = self.max_h end
end

function _M:on_select(item, force)
	if self.prev_item == item and not force then return end
	local str, fx, fy = self.tooltip(item)
	local tx,ty = fx or (self.last_display_x + self.last_mz.x2), fy or (self.last_display_y + self.last_mz.y1)
	if not self.no_tooltip then game:tooltipDisplayAtMap(tx, ty, str) end
	self.prev_item = item
end


function _M:display(x, y, nb_keyframes)
	if self.scrollbar then
		local oldpos = self.scrollbar.pos
		self.scrollbar:setPos(util.minBound(self.scrollbar.pos + self.scroll_inertia, 0, self.scrollbar.max))
		if self.scroll_inertia > 0 then self.scroll_inertia = math.max(self.scroll_inertia - 1, 0)
		elseif self.scroll_inertia < 0 then self.scroll_inertia = math.min(self.scroll_inertia + 1, 0)
		end
		if self.scrollbar.pos == 0 or self.scrollbar.pos == self.scrollbar.max then self.scroll_inertia = 0 end

		if self.scrollbar.pos ~= oldpos then
			self.lines_container:translate(0, -self.scrollbar.pos, 0)
		end
	end
end
