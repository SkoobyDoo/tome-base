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

--- Basic gamepad handler
-- @classmod engine.GamePad
module(..., package.seeall, class.make)

AXIS_DEADZONE = 0.15

function _M:init()
	self.handlers = {}
	self.deadzone_send = {}
end

--- Setup as the current game keyhandler
function _M:setCurrent()
	core.gamepad.set_current_handler(self)
	_M.current = self
end

function _M:deadzoneExists(axises)
	self.deadzone_send = table.keys(axises)
end

--- Called when a gamepad axis event is received
-- @param ball id of ball changed
-- @param xrel the relative movement of the ball
-- @param yrel the relative movement of the ball
function _M:receiveAxis(axis, value)
	-- if value < self.AXIS_DEADZONE and value > -self.AXIS_DEADZONE then if not self.deadzone_send[axis] then return else value = 0 end end
	if self.handlers[axis] then self.handlers[axis](value, axis) end
	print("=gamepad axis", axis, value)
end

--- Called when a gamepad hat event is received
-- @param hat id of the hat changed
-- @param dir current direction of the hat, one of 1,2,3,4,6,7,8,9 (representing direction)
function _M:receiveButton(button, is_up)
	if self.handlers[button] then self.handlers[button](is_up, button) end
	print("=gamepad button", button, is_up)
end

--- Called when a gamepad hat event is received
-- @param added if true the device is added, false the device is removed
-- @param id the device id
function _M:receiveDevice(added, id)
	if added then
		if self.handlers.__added then self.handlers.__added(id, "__added") end
	else
		if self.handlers.__removed then self.handlers.__removed(id, "__removed") end
	end
	-- print("=gamepad device", added, id)
end

function _M:addHandler(kind, fct)
	self.handlers[kind] = fct
end

function _M:addHandlers(t)
	for kind, fct in pairs(t) do
		self:addHandler(kind, fct)
	end
end
