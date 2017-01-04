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
local Tiles = require "engine.Tiles"
local Base = require "engine.ui.Base"
local Focusable = require "engine.ui.Focusable"

--- A generic UI button image
-- @classmod engine.ui.ButtonImage
module(..., package.seeall, class.inherit(Base, Focusable))

frame_ox1 = -5
frame_ox2 = 5
frame_oy1 = -5
frame_oy2 = 5

function _M:init(t)
	if t.tex then
		self.tex = t.tex
	else	
		self.file = tostring(assert(t.file, "no button file"))
		self.image = Tiles:loadImage(self.file)
	end

	self.fct = assert(t.fct, "no button fct")
	self.on_select = t.on_select
	if t.can_focus ~= nil then self.can_focus = t.can_focus end
	if t.can_focus_mouse ~= nil then self.can_focus_mouse = t.can_focus_mouse end
	self.alpha_unfocus = t.alpha_unfocus or 1
	self.no_decoration = t.no_decoration

	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()

	if self.tex then
		self.content = core.renderer.texture(self.tex)
		self.iw, self.ih = self.tex:getSize()
	else
		self.content = core.renderer.surface(self.image)
		self.iw, self.ih = self.image:getSize()
	end

	-- Draw UI
	local w, h = self.iw, self.ih
	self.w, self.h = w - frame_ox1 + frame_ox2, h - frame_oy1 + frame_oy2
	self.content:translate(0, 0, 50)
	self.do_container:add(self.content)

	-- Add UI controls
	self.mouse:registerZone(0, 0, self.w+6, self.h+6, function(button, x, y, xrel, yrel, bx, by, event)
		if self.hide then return end
		if self.on_select then self.on_select() end
		if button == "left" and event == "button" then self:sound("button") self.fct() end
	end)
	self.key:addBind("ACCEPT", function() self:sound("button") self.fct() end)

	self.rw, self.rh = w, h

	if not self.no_decoration then
		self.frame = self:makeFrameDO("ui/button", nil, nil, self.w, self.h)
		self.frame.container:translate(-self.frame.b4.w, -self.frame.b8.h, 0)
		self.frame_sel = self:makeFrameDO("ui/button_sel", nil, nil, self.w, self.h)
		self.frame.container:translate(-self.frame.b4.w, -self.frame.b8.h, 0)
		self.frame_sel.container:shown(false)
		self.do_container:add(self.frame.container)
		self.do_container:add(self.frame_sel.container)

		self.w, self.h = self.frame.w, self.frame.h
	end
end

function _M:on_focus_change(status)
	if self.frame then
		self.frame.container:shown(not status)
		self.frame_sel.container:shown(status)
	end
	self.content:tween(8, "a", nil, status and 1 or self.alpha_unfocus, "inOutQuad")
end
