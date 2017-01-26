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
local Textbox = require "engine.ui.Textbox"

--- A generic UI number textbox
--- @classmod engine.ui.Numberbox
module(..., package.seeall, class.inherit(Textbox))

function _M:init(t)
	t = table.clone(t)
	local on_change = t.on_change
	t.on_change = nil
	if t.number then
		t.text = tostring(t.number)
	end
	Textbox.init(self, t)
	self.number = t.number or 0
	self.on_number_change = on_change
	self.min = t.min or 0
	self.max = t.max or 9999999
	self.first = true
end

function _M:generate()
	Textbox.generate(self)

	self.key:addIgnore("_UP", false)
	self.key:addIgnore("_DOWN", false)
	self.key:addBind("ACCEPT", function() self.fct(self.number) end)

	self.key:addCommands{
		_UP = function() self:updateText(1) end,
		_DOWN = function() self:updateText(-1) end,
		__TEXTINPUT = function(c)
			if self.first then self.first = false self.tmp = {} self.cursor = 1 end
			if #self.tmp and ((self.cursor == 1 and c == '-') or (c >= '0' and c <= '9')) then
				table.insert(self.tmp, self.cursor, c)
				self.cursor = self.cursor + 1
				self.scroll = util.scroll(self.cursor, self.scroll, self.max_display)
				self:updateText()
			end
		end,
	}
end

function _M:updateText(v)
	self.first = false
	local old = self.number
	if not v then
		self.number = self.tmp and tonumber(table.concat(self.tmp)) or 0
		self.number = util.bound(self.number, self.min, self.max)
		Textbox.updateText(self)
	else
		self.number = self.number or 0
		self.number = util.bound(self.number + v, self.min, self.max)
		text = tostring(self.number)
		Textbox.setText(self, text)
	end

	if self.on_number_change and old ~= self.number then self.on_number_change(self.number) end
end
