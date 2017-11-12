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
local List = require "engine.ui.List"
local Dialog = require "engine.ui.Dialog"
local Input = require "engine.ui.blocks.Input"

--- A generic UI list dropdown box
-- @classmod engine.ui.Dropdown
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self.text = t.text or ""
	self.w = assert(t.width, "no dropdown width")
	self.fct = assert(t.fct, "no dropdown fct")
	self.list = assert(t.list, "no dropdown list")
	self.nb_items = assert(t.nb_items, "no dropdown nb_items")
	self.on_select = t.on_select
	self.display_prop = t.display_prop or "name"
	self.scrollbar = t.scrollbar

	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()

	-- Draw UI
	self.h = self.font_h + 6
	self.height = self.h

	self.textinput = Input.new(nil, "", nil, self.w - 8, self.h - 11)
	self.textinput:showCursor(false)
	self.do_container:add(self.textinput:get())

	-- Add UI controls
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if event == "button" and button == "left" then self:showSelect() end
	end)
	self.key:addBind("ACCEPT", function() self:showSelect() end)
end

function _M:positioned(x, y, sx, sy)
	self.c_list = List.new{width=self.w, list=self.list, select=self.on_select, display_prop=self.display_prop, scrollbar=self.scrollbar, nb_items=self.nb_items, fct=function()
		game:unregisterDialog(self.popup)
		self:sound("button")
		self.fct(self.c_list.list[self.c_list.sel])
		self.textinput:setText(self.c_list:getCurrentText())
	end}
	self.popup = Dialog.new(nil, self.w, self.c_list.h, sx, sy + self.h, nil, nil, false, "simple")
	self.popup.frame.a = 0.7
	self.popup:loadUI{{left=0, top=0, ui=self.c_list}}
	self.popup:setupUI(true, true)
	self.popup.key:addBind("EXIT", function()
		game:unregisterDialog(self.popup)
		self.c_list.sel = self.previous
		self:sound("button")
		self.fct(self.c_list.list[self.c_list.sel])
		self.textinput:setText(self.c_list:getCurrentText())
	end)
	self.textinput:setText(self.c_list:getCurrentText())
end

function _M:showSelect()
	self.previous = self.c_list.sel
	game:registerDialog(self.popup)
end
