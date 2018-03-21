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
local WithTitle = require "engine.ui.WithTitle"
local Focusable = require "engine.ui.Focusable"
local Input = require "engine.ui.blocks.Input"

--- A generic UI textbox
-- @classmod engine.ui.Textbox
module(..., package.seeall, class.inherit(WithTitle, Focusable))

function _M:init(t)
	self.text = t.text or ""
	self.old_text = self.text
	self.on_mouse = t.on_mouse
	self.hide = t.hide
	self.on_change = t.on_change
	self.max_len = t.max_len or 999
	self.fct = assert(t.fct, "no textbox fct")
	self.chars = assert(t.chars, "no textbox chars")
	self.filter = t.filter or function(c) return c end

	self.tmp = {}
	for i = 1, #self.text do self.tmp[#self.tmp+1] = self.text:sub(i, i) end
	self.cursor = #self.tmp + 1
	self.scroll = 1

	WithTitle.init(self, t)
end

function _M:on_focus(v)
	game:onTickEnd(function() self.key:unicodeInput(v) end)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()

	-- Draw UI
	local fw, fh = self.chars * self.font_mono_w, self.font_mono_h
	-- the following constants are to account for empty pixels on the frames
	local ew, eh = 2, 2

	self.textinput = Input.new(nil, "", nil, fw - 2 * ew, fh - 2 * eh)
	self.do_container:add(self.textinput:get())

	self.h = self.textinput.h
	self:generateTitle(self.h)
	local title_w = self.title_w
	self.w = title_w + self.textinput.w

	self.textinput:translate(title_w, 0, 0)

	self.max_display = self.chars
	self:updateText()

	-- Add UI controls
	self.mouse:registerZone(title_w + self.textinput.frame.b4.w, 0, self.textinput.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if event == "button" and button == "left" then
			self.cursor = util.bound(math.floor(bx / self.font_mono_w) + self.scroll, 1, #self.tmp+1)
			self:updateText()
		elseif event == "button" and self.on_mouse then
			self.on_mouse(button, x, y, xrel, yrel, bx, by, event)
		end
	end)
	self.key:addBind("ACCEPT", function() self.fct(self.text) end)
	self.key:addIgnore("_ESCAPE", true)
	self.key:addIgnore("_TAB", true)
	self.key:addIgnore("_UP", true)
	self.key:addIgnore("_DOWN", true)

	self.key:addCommands{
		_LEFT = function() self.cursor = util.bound(self.cursor - 1, 1, #self.tmp+1) self.scroll = util.scroll(self.cursor, self.scroll, self.max_display) self:updateText() end,
		_RIGHT = function() self.cursor = util.bound(self.cursor + 1, 1, #self.tmp+1) self.scroll = util.scroll(self.cursor, self.scroll, self.max_display) self:updateText() end,
		_BACKSPACE = function()
			if self.cursor > 1 then
				local st = core.key.modState("ctrl") and 1 or self.cursor - 1
				for i = self.cursor - 1, st, -1 do
					table.remove(self.tmp, i)
					self.cursor = self.cursor - 1
					self.scroll = util.scroll(self.cursor, self.scroll, self.max_display)
				end
				self:updateText()
			end
		end,
		_DELETE = function()
			if self.cursor <= #self.tmp then
				local num = core.key.modState("ctrl") and #self.tmp - self.cursor + 1 or 1
				for i = 1, num do
					table.remove(self.tmp, self.cursor)
				end
				self:updateText()
			end
		end,
		_HOME = function()
			self.cursor = 1
			self.scroll = util.scroll(self.cursor, self.scroll, self.max_display)
			self:updateText()
		end,
		_END = function()
			self.cursor = #self.tmp + 1
			self.scroll = util.scroll(self.cursor, self.scroll, self.max_display)
			self:updateText()
		end,
		__TEXTINPUT = function(c)
			if #self.tmp < self.max_len then
				if self.filter(c) then
					table.insert(self.tmp, self.cursor, self.filter(c))
					self.cursor = self.cursor + 1
					self.scroll = util.scroll(self.cursor, self.scroll, self.max_display)
					self:updateText()
				end
			end
		end,
		[{"_v", "ctrl"}] = function(c)
			local s = core.key.getClipboard()
			if s then
				for i = 1, #s do
					if #self.tmp >= self.max_len then break end
					local c = string.sub(s, i, i)
					table.insert(self.tmp, self.cursor, self.filter(c))
					self.cursor = self.cursor + 1
					self.scroll = util.scroll(self.cursor, self.scroll, self.max_display)
				end
				self:updateText()
			end
		end,
		[{"_c", "ctrl"}] = function(c)
			self:updateText()
			core.key.setClipboard(self.text)
		end,
	}
end

function _M:setText(text)
	self.text = text
	self.tmp = {}
	for i = 1, #self.text do self.tmp[#self.tmp+1] = self.text:sub(i, i) end
	self.cursor = #self.tmp + 1
	self.scroll = 1
	self:updateText()
end

function _M:updateText()
	if not self.tmp[1] then self.tmp = {} end
	self.text = table.concat(self.tmp)
	local text
	local b, e = self.scroll, math.min(self.scroll + self.max_display - 1, #self.tmp)
	if not self.hide then text = table.concat(self.tmp, nil, b, e)
	else text = string.rep("*", e - b + 1) end

	self.textinput:setText(text)
	self.textinput:setPos(self.cursor - self.scroll + 1)

	if self.on_change and self.old_text ~= self.text then self.on_change(self.text, self) end
	self.old_text = self.text
end
