-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2014 Nicolas Casalini
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

--- A talent trees display
module(..., package.seeall, class.inherit(Base))

-- A status box.
-- width : sets width
-- delay: if not nil, the text will disappear after that much seconds
-- text and color can be set, that updates frame counter
function _M:init(t)
	self.w = t.width
	self.text = ""
	self.color = t.color or {r=255,g=255,b=255}
	self.delay = t.delay
	self.frame_delay = t.delay * (config.settings.display_fps or 60)
	self.frame_decay = 0

	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.h = self.font_h

	self.text_surf = core.display.newSurface(self.w, self.h)
	self.text_surf:erase(0, 0, 0, 0)
	self.text_tex = {self.text_surf:glTexture()}
	self.iw, self.ih = self.w, self.h

	self.w = self.w + 6
	self.h = self.h + 6
end

function _M:setTextColor(text, color)
	self.text = text or self.text
	self.color = color or self.color

	self.text_surf:erase(0, 0, 0, 0)
	self.text_surf:drawColorStringCentered(self.font_bold, self.text, 0, 0, self.iw, self.ih, self.color.r, self.color.g, self.color.b)
	self.text_surf:updateTexture(self.text_tex[1])
	self.frame_decay = 0
end

function _M:display(x, y, nb_keyframes)
	local alpha = 1
	if self.frame_delay then
		self.frame_decay = self.frame_decay + nb_keyframes
		if self.frame_decay > self.frame_delay then
			-- ease out over 0.5 s
			local easetime = (config.settings.display_fps or 60) / 2
			alpha = 1 - (self.frame_decay - self.frame_delay) / easetime
		end
	end
	self.text_tex[1]:toScreenFull(x + 3, y + 3, self.iw, self.ih, self.text_tex[2], self.text_tex[3], 1, 1, 1, alpha)
end

