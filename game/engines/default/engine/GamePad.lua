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

require "config"
require "engine.class"

--- Handles gamepad binds to "virtual" actions
module(..., package.seeall, class.make)

PAD_AXIS_BUTTON_THRESHOLD = 0.35
PAD_BUTTON_REPEAT_SPEED = 0.05
PAD_BUTTON_REPEAT_FIRST_SPEED = 0.3

modifiers = {
	LEFTTRIGGER = true,
	RIGHTTRIGGER = true,
}

function _M:init()
	self.pad_button_state = {}
	self.pad_axis_state = {}
end

function _M:reset()
end

function _M:receivePadButton(button, is_up)
	button = button:upper()
	
	if not is_up then
		local state = {}
		if game and game.registerTimer then
			local time = PAD_BUTTON_REPEAT_SPEED
			if not self.pad_button_state[button] then time = PAD_BUTTON_REPEAT_FIRST_SPEED end
			state.timerid = game:registerTimer(time, function() self:receivePadButton(button, nil) end)
		end
		self.pad_button_state[button] = state
	else
		local state = self.pad_button_state[button]
		if state and state.timerid and game and game.removeTimer then
			game:removeTimer(state.timerid)
		end
		self.pad_button_state[button] = nil
	end

	print("<===button", button, is_up)
	if not modifiers[button] then
		self:receiveKey("PAD_"..button, self.pad_button_state.LEFTTRIGGER and true or false, self.pad_button_state.RIGHTTRIGGER and true or false, false, false, nil, is_up == true, nil, false)
	end
end

function _M:receivePadAxis(axis, value, stop)
	if not stop then
		if value < 0 then
			return self:receivePadAxis(axis.."_neg", -value, true)
		elseif value == 0 then
			self:receivePadAxis(axis, value, true)
			self:receivePadAxis(axis.."_neg", value, true)
			return
		end
	end

	axis = axis:upper()
	local prev = self.pad_axis_state[axis] or 0
	self.pad_axis_state[axis] = value

	if value >= PAD_AXIS_BUTTON_THRESHOLD and prev < PAD_AXIS_BUTTON_THRESHOLD then
		self:receivePadButton(axis, false)
	elseif value < PAD_AXIS_BUTTON_THRESHOLD and prev >= PAD_AXIS_BUTTON_THRESHOLD then
		self:receivePadButton(axis, true)
	end

	-- print("===axis", axis, value)
end

function _M:onCurrentChange(v)
	for key, state in pairs(self.pad_button_state) do
		if state.timerid and game.removeTimer then game:removeTimer(state.timerid) end
	end

	self.pad_button_state = {}
	self.pad_axis_state = {}
end
