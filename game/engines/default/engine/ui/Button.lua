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
local tween = require "tween"
local Base = require "engine.ui.Base"
local Focusable = require "engine.ui.Focusable"

--- A generic UI button
-- @classmod engine.ui.Button
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self.text = assert(t.text, "no button text")
	self.fct = assert(t.fct, "no button fct")
	self.on_select = t.on_select
	self.force_w = t.width
	if t.can_focus ~= nil then self.can_focus = t.can_focus end
	if t.can_focus_mouse ~= nil then self.can_focus_mouse = t.can_focus_mouse end
	self.alpha_unfocus = t.alpha_unfocus or 1

	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()

	-- Draw UI
	self.font:setStyle("bold")
	local text = core.renderer.text(self.font)
	text:text(self.text)
	self.font:setStyle("normal")

	local w, h = text:getStats()
	local f = self:makeFrameDO("ui/button", self.force_w, nil, w, h)
	self.frame_do = f
	w = f.w - f.b4.w - f.b6.w
	self.iw, self.ih = w, h

	self.w, self.h = f.w, f.h
	if self.force_w then w = self.force_w end

	text:translate(f.b4.w, f.b8.h, 10)
	self.do_container:add(text)

	self.frame_sel_do = self:makeFrameDO("ui/button_sel", f.w, f.h)
	self.frame_sel_do.container:translate(0, 0, 1)
	self.frame_sel_do.container:color(1, 1, 1, 0)
	self.do_container:add(self.frame_do.container)
	self.do_container:add(self.frame_sel_do.container)

	-- Add UI controls
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if self.hide then return end
		if self.on_select then self.on_select() end
		if button == "left" and event == "button" then self:sound("button") self.fct() end
	end)
	self.key:addBind("ACCEPT", function() self:sound("button") self.fct() end)

end

function _M:on_focus_change(status)
	self.frame_sel_do.container:colorTween("focus", 8, "a", nil, status and 1 or 0, "inOutQuad")
end
