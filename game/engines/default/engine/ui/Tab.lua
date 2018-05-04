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

--- A generic UI tab button
-- @classmod engine.ui.Tab
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self:proxyData{"selected"}

	self.title = assert(t.title, "no tab title")
	self.selected = t.default
	self.on_change = t.on_change

	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()

	-- Draw UI
	local title_line = core.renderer.text(self.font)
	title_line:text(self.title)
	local w, h = title_line:getStats()
	local f = self:makeFrameDO("ui/button", nil, nil, w, h)
	self.frame_do = f
	self.frame_sel_do = self:makeFrameDO("ui/button_sel", f.w, f.h)
	self.w, self.h  = f.w, f.h

	title_line:translate(f.b4.w, f.b8.h, 10)
	self.do_container:add(self.frame_do.container)
	self.do_container:add(self.frame_sel_do.container)
	self.do_container:add(title_line)

	self:select(self.selected, true)

	-- Add UI controls
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if event == "button" then
			self:select()
		end
	end)


	self.key:addBind("ACCEPT", function() self:select() end)
	self.key:addCommands{
		_SPACE = function() self:select() end,
	}

	self.finished = true
end

function _M:select(selected, notrig)
	if selected == nil then selected = true end
	self.selected = selected
end

function _M:proxyDataSet(k, v)
	if k == "selected" and self.do_container then
		self.frame_do.container:shown(not v)
		self.frame_sel_do.container:shown(v)
		if self.on_change and self.finished then self.on_change(v) end
	end
	return true
end
