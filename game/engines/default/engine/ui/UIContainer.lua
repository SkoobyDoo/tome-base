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
local Base = require "engine.ui.Base"
local Focusable = require "engine.ui.Focusable"
local Scrollbar = require "engine.ui.blocks.Scrollbar"

--- A generic UI Container
-- @classmod engine.ui.UIContainer
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self.w = assert(t.width, "no container width")
	self.h = assert(t.height, "no container height")
	
	self.uis = {}
	
	self.uis_h = 0
	
	self.scroll_inertia = 0
	self.do_scroller = core.renderer.container()

	t.require_renderer = true
	Base.init(self, t)
end

function _M:generate()
	self.do_container:clear()
	self.do_scroller:clear()
	self.mouse:reset()
	self.key:reset()

	self.do_container:cutoff(0, 0, self.w, self.h)

	self.do_container:add(self.do_scroller)

	self.scrollbar = Scrollbar.new(nil, self.h, 1)
	self.scrollbar:translate(self.w - self.scrollbar.w, 0, 1)
	self.scrollbar:get():shown(false)
	self.do_container:add(self.scrollbar:get())

	-- Add UI controls
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if button == "wheelup" and event == "button" then self.key:triggerVirtual("MOVE_UP")
		elseif button == "wheeldown" and event == "button" then self.key:triggerVirtual("MOVE_DOWN")
		end
	end)
	self.key:addBinds{
		MOVE_UP = function() self:scroll(false) end,
		MOVE_DOWN = function() self:scroll(true) end,
	}
end

function _M:scroll(down)
	if self.uis_h <= self.h then return end
	if down then self.scroll_inertia = math.min(self.scroll_inertia, 0) + 10
	else self.scroll_inertia = math.min(self.scroll_inertia, 0) - 10
	end
end

function _M:erase()
	for _, ui in ipairs(self.uis) do
		ui.do_container:removeFromParent()
	end
	self.uis = {}
end

function _M:changeUI(uis)
	self:erase()
	local max_h = 0
	self.uis = uis
	for i=1, #self.uis do
		local ui = self.uis[i]
		if ui.do_container then
			ui.do_container:translate(0, max_h)
			ui.do_container:removeFromParent()
			self.do_scroller:add(ui.do_container)
			max_h = max_h + ui.h
		end
	end
	self.uis_h = max_h
	if max_h <= self.h then
		self.scrollbar:get():shown(false)
	else
		self.scrollbar:get():shown(true)
		self.scrollbar:setMax(max_h - self.h)
		self.scrollbar:setPos(0)
		self.do_scroller:translate(0, 0, 0)
	end
end

function _M:resize(w, h)
	self.w = w
	self.h = h
	self.do_container:cutoff(0, 0, self.w, self.h)
	self.scrollbar:translate(self.w - self.scrollbar.w, 0, 1)
	self:changeUI(self.uis)
end

function _M:display(x, y, nb_keyframes)
	if self.scroll_inertia ~= 0 and nb_keyframes > 0 then
		self.scrollbar:setPos(self.scrollbar.pos + self.scroll_inertia * nb_keyframes)
		self.do_scroller:translate(0, -self.scrollbar.pos, 0)
		if self.scroll_inertia > 0 then self.scroll_inertia = math.max(self.scroll_inertia - nb_keyframes, 0)
		elseif self.scroll_inertia < 0 then self.scroll_inertia = math.min(self.scroll_inertia + nb_keyframes, 0)
		end
		if self.scrollbar.pos == 0 or self.scrollbar.pos == self.scrollbar.max then self.scroll_inertia = 0 end
	end
end
