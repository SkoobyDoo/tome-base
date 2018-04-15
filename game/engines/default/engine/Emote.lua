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

--- Emotes for actors
-- @classmod engine.Emote
module(..., package.seeall, class.inherit(Base))

frame_ox1 = -15
frame_ox2 = 15
frame_oy1 = -15
frame_oy2 = 15

--- @string text
-- @int[opt=60] dur
-- @param[opt=colors.Black] color
function _M:init(text, dur, color, font)
	self.text = text
	self.dur = dur or 60
	self.color = color or colors.BLACK
	self.use_font = font

	Base.init(self, {font = self.use_font or {"/data/font/DroidSans-Bold.ttf", 16}})
end

--- on loaded
function _M:loaded()
	Base.init(self, {font = self.use_font or {"/data/font/DroidSans-Bold.ttf", 16}})
end

--- Serialization
-- @return if we successfully saved or not
function _M:save()
	return class.save(self, {x=true, y=true, text=true, dur=true, color=true}, true)
end

--- Update emote
function _M:update()
	return self.dead
end

--- Generate emote
function _M:generate()
	self.renderer = core.renderer.renderer("static"):setRendererName("emote")

	local text = core.renderer.text(self.font):outline(0.7):text(self.text):center()
	local w, h = text:getStats()
	self.rw, self.rh = w, h

	local frame = self:makeFrameDO("ui/emote/", nil, nil, w, h)
	self.w, self.h = frame.w, frame.h

	self.renderer:add(frame.container:color(1, 1, 1, 0.7))
	self.renderer:add(text:translate(self.w / 2, self.h / 2))

	self.renderer:tween(self.dur, "wait", function(r) r:tween(10, "a", nil, 0, "inQuad", function() self.dead = true end) end)

	self.dead = false
end

--- Display emote
function _M:display(x, y)
	self.renderer:toScreen(x, y)
end
