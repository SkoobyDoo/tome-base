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

local class = require "engine.class"

local Base = require "engine.ui.Base"

--- Helper for "title" parameter for UI elements
-- @classmod engine.ui.WithTitle
module(..., package.seeall, class.inherit(Base))

function _M:init(t)
	self.title = t.title
	self.title_w = t.title_w
	self.size_title = t.size_title or t.title

	Base.init(self, t)
end

function _M:generateTitle(h)
	if not self.size_title and not self.title_w then
		self.title_w = 0
		self.title_h = 0
		return
	end
	self.title_w = self.title_w or self.font:size(self.size_title)
	self.title_h = self.font:height()

	self.title_do = core.renderer.text(self.font)
	self.title_do:text(self.title or "")
	self.title_do:maxWidth(self.title_w)
	self.title_do:translate(self.title_x or 0, (self.title_y or ((h - self.title_h) / 2)), 10)
	self.do_container:add(self.title_do)
end
