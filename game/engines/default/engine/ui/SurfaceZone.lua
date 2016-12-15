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
local Base = require "engine.ui.Base"
local Focusable = require "engine.ui.Focusable"

--- A generic UI surface zone
-- @classmod engine.ui.SurfaceZone
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self.w = assert(t.width, "no surface zone width")
	self.h = assert(t.height, "no surface zone height")
	self.alpha = t.alpha or 200

	self.s = core.display.newSurface(self.w, self.h)

	self.color = t.color or {r=255, g=255, b=255}

	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()

	self.texture = core.renderer.textureTable(self.s)

	if self.text_shadow then self.do_container:add(core.renderer.fromTextureTable(self.texture, self.text_shadow.x, self.text_shadow.y, self.w, self.h, false, 0, 0, 0, self.text_shadow)) end
	self.do_container:add(core.renderer.fromTextureTable(self.texture, 0, 0, self.w, self.h))

	self.can_focus = false
end

function _M:update()
	self.s:updateTexture(self.texture.t)
end
