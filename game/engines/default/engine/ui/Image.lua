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

--- A generic UI image
-- @classmod engine.ui.Image
module(..., package.seeall, class.inherit(Base))

function _M:init(t)
	if t.tex then
		error("ui.Image t.tex unsupported")
	else
		self.file = tostring(assert(t.file, "no image file"))
		self.image = Tiles:loadImage(self.file)
		local iw, ih = 0, 0
		if self.image then iw, ih = self.image:getSize() end
		self.iw, self.ih = iw, ih
		if t.auto_width then t.width = iw end
		if t.auto_height then t.height = ih end
	end
	self.w = assert(t.width, "no image width") * (t.zoom or 1)
	self.h = assert(t.height, "no image height") * (t.zoom or 1)
	self.back_color = t.back_color

	self.shadow = t.shadow

	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()

	if self.image then
		if self.shadow then self.do_container:add(core.renderer.fromSurface(self.image, 5, 5, self.w, self.h, false, 0, 0, 0, 0.5)) end
		if self.back_color then self.do_container:add(core.renderer.colorQuad(0, 0, self.w, self.h, colors.smart1unpack(self.back_color))) end
		self.do_container:add(core.renderer.fromSurface(self.image, 0, 0, self.w, self.h, false, 1, 1, 1, 1))
	end
end
