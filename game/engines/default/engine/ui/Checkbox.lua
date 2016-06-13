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
local tween = require "tween"
local Base = require "engine.ui.Base"
local Focusable = require "engine.ui.Focusable"

--- A generic UI checkbox
-- @classmod engine.ui.Checkbox
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	self:proxyData{"checked"}

	self.title = assert(t.title, "no checkbox title")
	self.text = t.text or ""
	self.checked = t.default
	self.check_first = not t.check_last
	self.fct = t.fct or function() end
	self.on_change = t.on_change

	Base.init(self, t)
end

function _M:generate()
	self.do_container:clear()
	self.mouse:reset()
	self.key:reset()

	local check = self:getAtlasTexture("ui/checkbox.png")
	local tick = self:getAtlasTexture("ui/checkbox-ok.png")

	-- Draw UI
	local text = core.renderer.text(self.font)
	text:text(self.title)

	self.tex = self:drawFontLine(self.font, self.title)
	local w, h = text:getStats()
	self.w, self.h = w + check.w + 3, math.max(h, check.h)
	self.do_container:add(text)

	self.do_container:add(core.renderer.fromTextureTable(check, 0, (check.h - h) / 2))

	self.tickvo = core.renderer.fromTextureTable(tick, 0, (check.h - h) / 2)
	self.tickvo:color(1, 1, 1, self.checked and 1 or 0)
	self.do_container:add(self.tickvo)

	text:translate(check.w + 3, (self.h - h) / 2, 10)

	-- Add UI controls
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if event == "button" then
			self:select()
		end
	end)
	self.key:addBind("ACCEPT", function() self.fct(self.checked) end)
	self.key:addCommands{
		_SPACE = function() self:select() end,
	}
end

function _M:select()
	self.checked = not self.checked
	self:sound("button")
	if self.on_change then self.on_change(self.checked) end
end

function _M:proxyDataSet(k, v)
	-- Detect when checked field is changed and update
	if k == "checked" and self.tickvo then
		tween.stop(self.tweenid)
		self.tweenid = self.tickvo:colorTween(4, "a", nil, v and 1 or 0, "linear")
	end
	return true
end
