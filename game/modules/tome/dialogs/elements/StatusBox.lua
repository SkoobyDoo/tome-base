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

--- A talent trees display
module(..., package.seeall, class.inherit(Base))

-- A status box.
-- width : sets width
-- delay: if not nil, the text will disappear after that much seconds
-- text and color can be set, that updates frame counter
function _M:init(t)
	self.w = t.width
	self.delay = t.delay * 30

	t.request_renderer = true
	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()
	self.h = self.font_h

	self.iw, self.ih = self.w, self.h

	self.w = self.w + 6
	self.h = self.h + 6
	self.text = core.renderer.text(self.font)
	self.do_container:add(self.text)
end

function _M:setTextColor(text, color)
	text = text or ""
	color = color or {r=255,g=255,b=255}
	self.text:textColor(colors.smart1unpack(color)):text(text):color(1, 1, 1, 0):cancelTween(true):tween(6, "a", 0, 1, nil, function(d)
		d:tween(30, "wait", function(d)
			d:tween(15, "a", nil, 0)
		end)
	end)
end
