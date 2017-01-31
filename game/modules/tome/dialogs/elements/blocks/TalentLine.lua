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
local Block = require "engine.ui.blocks.Block"
local Mouse = require "engine.Mouse"

--- A talent icon
-- @classmod engine.ui.blocks.Talent
module(..., package.seeall, class.inherit(Block))

function _M:init(t, item, collapsed, frame)
	Block.init(self, t)
	self.mouseid = tostring(self) -- this makes values like "table: 0x......" which are always unique

	self.item = item

	self.mouse = Mouse.new()

	self.plus_t = self.parent:getAtlasTexture("ui/plus.png")
	self.minus_t = self.parent:getAtlasTexture("ui/minus.png")

	self.plus = core.renderer.fromTextureTable(self.plus_t, 0, 0)
	self.minus = core.renderer.fromTextureTable(self.minus_t, 0, 0)

	self.frame = self.parent:makeFrameDO(frame, 1, 1, nil, nil, nil, true)
	self.frame.container:shown(false):translate(self.minus_t.w + 4 - 2, (self.minus_t.h - self.parent.font:height()) / 2 - 2)
	self.do_container:add(self.frame.container)

	self.text = core.renderer.text(self.parent.font):outline(1):translate(self.minus_t.w + 4, (self.minus_t.h - self.parent.font:height()) / 2, 10)

	self.do_container:add(self.plus:shown(false))
	self.do_container:add(self.minus)
	self.do_container:add(self.text)

	self.talents_x, self.talents_y = self.minus_t.w, self.parent.font:height()
	self.do_talents = core.renderer.container():translate(self.talents_x, self.talents_y)
	self.do_container:add(self.do_talents)

	self.next = core.renderer.container()
	self.do_container:add(self.next)

	self.next_x, self.next_y = 0, 0
	self.talents_h = 0

	self.talents = {}
	self.sel = 1

	self.mouse:registerZone(0, 0, self.plus_t.w, self.plus_t.h, function(button, x, y, xrel, yrel, bx, by, event)
		if event == "button" and button == "wheelup" then self.parent:scroll(-1)
		elseif event == "button" and button == "wheeldown" then self.parent:scroll(1)
		elseif event == "button" and (button == "left" or button == "right") then
			self:collapse(not self.collapsed)
		end
	end, nil, "collapse", true, 1)
	self.mouse:registerZone(self.plus_t.w, 0, self.parent.w - self.plus_t.w, self.plus_t.h, function(button, x, y, xrel, yrel, bx, by, event)
		if event == "button" and button == "wheelup" then self.parent:scroll(-1)
		elseif event == "button" and button == "wheeldown" then self.parent:scroll(1)
		elseif event == "button" and (button == "left" or button == "right") then
			self.parent:onUse(self.item, button == "left")
			self:collapse(false)
		elseif event == "out" then
			self:setSel(false)
		else
			self:setSel(true)
		end
	end, nil, "collapse", true, 1)
end

function _M:setSel(v)
	self.frame.container:shown(v)
	if v then self.parent:setSel(self.item) end
end

function _M:setNext(d)
	d.prev_line = self
	self.next_line = d
	self.next:clear():add(d:get())
end

function _M:collapse(v)
	self.collapsed = v
	self.do_talents:shown(not v)
	self.minus:shown(not v)
	self.plus:shown(v)
	if v then
		self.h = math.ceil(self.parent.font:height())
	else
		self.h = math.ceil(self.parent.font:height() + self.talents_h)
	end
	self.next:translate(0, self.h + 10)

	self:updateMouse()

	self.parent:onExpand(self.item)
end

function _M:updateMouse()
	local tx, ty = self.do_container:getTranslate(self.parent.lines_container)
	local pmouse = self.parent.list_mouse
	local mouse = self.mouse

	pmouse:replaceZone(tx, ty, self.parent.w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		mouse:delegate(button, x - tx, y - ty, xrel, yrel, bx, by, event)
	end, nil, self.mouseid, true, 1)

	if self.next_line then
		-- Update the next one too
		self.next_line:updateMouse()
	else
		-- We are the last one, tell parent the size of the list
		self.parent:setListHeight(ty + self.h)
	end
end

function _M:updateStatus(text)
	self.text:text(text)
	local w, h = self.text:getStats()
	self.frame:resize(w + 4, h + 4)
	return self
end

function _M:updateColor(color)
	self.text:color(colors.smart1unpack(color))
	return self
end

function _M:add(talent)
	local id = #self.talents+1
	self.talents[id] = talent
	talent.tree = self

	self.mouse:registerZone(self.talents_x + self.next_x, self.talents_y + self.next_y, talent.w, talent.h, function(button, x, y, xrel, yrel, bx, by, event)
		if event == "button" and button == "wheelup" then self.parent:scroll(-1)
		elseif event == "button" and button == "wheeldown" then self.parent:scroll(1)
		elseif event == "button" and (button == "left" or button == "right") then
			self.parent:onUse(self.talents[self.sel].item, button == "left")
		elseif event == "out" then
			self.talents[self.sel]:setSel(false)	
		else
			self.talents[self.sel]:setSel(false)
			self.talents[id]:setSel(true)
			self.sel = id
		end
	end, nil, "icon"..id, true, 1)

	self.do_talents:add(talent:get():translate(self.next_x, self.next_y))
	self.next_x = self.next_x + talent.w + 4
	self.talents_h = self.next_y + talent.h
end

function _M:onFocusChange(v)
end
