-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2015 Nicolas Casalini
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

--- A generic UI button
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
		local iw, ih = 0, 0
		if self.image then iw, ih = self.image:getSize() end
		self.iw, self.ih = iw, ih
	end
	if t.force_w then self.iw = t.force_w end

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

	-- Draw UI
	local w, h = self.iw, self.ih
	self.w, self.h = w - frame_ox1 + frame_ox2, h - frame_oy1 + frame_oy2
	if self.image then self.tex = self.tex or {self.image:glTexture()} end

	-- Add UI controls
	self.mouse:allowDownEvent(true)
	self.mouse:registerZone(0, 0, self.w+6, self.h+6, function(button, x, y, xrel, yrel, bx, by, event)
		if self.hide then return end
		if self.on_select then self.on_select() end
		if button == "left" and event == "button-down" then self:pressed(true) end
		if button == "left" and event == "button" then self:pressed(false) self:sound("button") self.fct() end
	end)
	self.key:addBind("ACCEPT", function() self:sound("button") self.fct() end)

	self.rw, self.rh = w, h

	-- Draw stuff
	if not self.no_decoration then
		self:setupVOs(true)
		self.vo_id = self:makeFrameVO(self.vo, "ui/button", 0, 0, self.bw, self.bh)
	end

	-- Add a bit of padding
	self.w = self.w + 6
	self.h = self.h + 6
end

function _M:pressed(v)
	if not self.vo_id then return end
	if v then self:updateFrameColorVO(self.vo, self.vo_id, true, 0, 1, 0, 1)
	else self:updateFrameColorVO(self.vo, self.vo_id, true, 1, 1, 1, 1) end
end

function _M:on_focus_change(status)
	if not self.vo_id then return end
	self:updateFrameTextureVO(self.vo, self.vo_id, status and "ui/button_sel" or "ui/button")
	if status then self:updateFrameColorVO(self.vo, self.vo_id, true, self.vo_id.r, self.vo_id.g, self.vo_id.b, 1)
	else self:updateFrameColorVO(self.vo, self.vo_id, true, self.vo_id.r, self.vo_id.g, self.vo_id.b, self.alpha_unfocus) end
	if not status then self:pressed(false) end
end

function _M:display(x, y, nb_keyframes, ox, oy)
	self.last_display_x = ox
	self.last_display_y = oy

	if self.hide then return end

	self.tex[1]:toScreenFull(x-frame_ox1, y-frame_oy1, self.rw, self.rh, self.tex[2], self.tex[3], 1, 1, 1, self.focused and 1 or self.alpha_unfocus)
end
