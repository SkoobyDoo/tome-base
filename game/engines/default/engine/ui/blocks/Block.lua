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

--- A generic UI block
-- @classmod engine.ui.blocks.block
module(..., package.seeall, class.make)

-- We enter the realms of magic code; here be dragons!
-- Let's find the first function in the call stack that is an UI
local function findUI()
	local stackid = 2
	while true do
		local i = debug.getinfo(stackid, "f")
		if not i then return end
		local selfname, self = debug.getlocal(stackid, 1)
		if selfname == "self" and type(self) == "table" and self.isClassName and self:isClassName("engine.ui.Base") then
			return self
		end
		stackid = stackid + 1
	end
	error("Could not find parent UI")
end

function _M:init(t)
	t = t or {}
	self.parent = setmetatable({}, {__mode="v"})
	if t.for_ui then self.parent.ui = t.for_ui end
	if not self.parent.ui then self.parent.ui = findUI() end

	self.font = t.font or self.parent.ui.font
	self.font_h = t.font_h or self.parent.ui.font_h

	self.do_container = core.renderer.container()

	self.parent.ui:blockAdded(self) -- This does not provoke cycle tables because the parent stores us as a weak table
end

function _M:onFocusChange(v)
end

function _M:get()
	return self.do_container
end

function _M:translate(x, y, z)
	self.do_container:translate(x, y, z)
end

function _M:rotate(x, y, z)
	self.do_container:rotate(x, y, z)
end

function _M:scale(x, y, z)
	self.do_container:scale(x, y, z)
end

function _M:color(r, g, b, a)
	self.do_container:color(r, g, b, a)
end

function _M:shown(v)
	self.do_container:shown(v)
end
