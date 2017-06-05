-- ToME - Tales of Maj'Eyal
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
local UI = require "engine.ui.Base"
local Dialog = require "engine.ui.Dialog"
local FontPackage = require "engine.FontPackage"

module(..., package.seeall, class.make)

local frames_colors = {
	sustain = {0.6, 0.6, 0, 1},
}

function _M:init(party, a)
	local color = frames_colors.sustain

	self.party = party
	self.a = a
	self.back = core.renderer.colorQuad(0, 0, 40, 40, 0, 0, 0, 1)
	self.lifebar = core.renderer.colorQuad(0, 0, 40, 40, 0xc0/255, 0, 0, 1)
	self.frame = UI:cloneFrameDO(party.base_frame)
	self.display_entity = a:getEntityDisplayObject(party.tiles, 38, 38, 1, false, false, true)
	self.texts = core.renderer.container()
	if a.summon_time then
		self.text_overlay = core.renderer.text(party.buff_font):outline(1, 0, 0, 0, 1)
		self.text_overlay:translate(20, 20, 10)
		self.texts:add(self.text_overlay)
	end

	party.frames_layer:add(self.frame.container:color(unpack(color)))
	party.backs_layer:add(self.back):add(self.lifebar)
	party.icons_layer:add(self.display_entity)
	party.texts_layer:add(self.texts)
end

function _M:delete()
	self.back:removeFromParent()
	self.lifebar:removeFromParent()
	self.texts:removeFromParent()
	self.frame.container:removeFromParent()
	self.display_entity:removeFromParent()
end

function _M:move(x, y)
	self.x, self.y = x, y
	self.back:translate(x, y)
	self.lifebar:translate(x, y)
	self.texts:translate(x, y)
	self.frame.container:translate(x, y)
	self.display_entity:translate(x + 2, y + 2)
end

function _M:getDescription()
	local a = self.a
	local def = game.party.members[a]
	if not def then return "" end
	local text = "#GOLD##{bold}#"..a.name.."\n#WHITE##{normal}#Life: "..math.floor(100 * a.life / a.max_life).."%\nLevel: "..a.level.."\n"..def.title
	if a.summon_time then
		text = text.."\nTurns remaining: "..a.summon_time
	end
	return text
end

function _M:positionMouse(x, y)
	self.party.mouse:replaceZone(self.x - x, self.y - y, 40, 40, function(button, mx, my, xrel, yrel, bx, by, event)
		local a = self.a
		local def = game.party.members[a]
		if not def then return end

		if event == "button" and button == "left" then
			if def.control == "full" then game.party:select(a)
			elseif def.orders then game.party:giveOrders(a)
			end
		elseif event == "button" and button == "right" then
			if def.orders then game.party:giveOrders(a) end
		end

		game:tooltipDisplayAtMap(game.w, game.h, self:getDescription())
	end, nil, "party:"..self.a.uid, true, 1)
end

function _M:update(player)
	local a = self.a
	if self.text_overlay then
		if a.summon_time ~= self.old_time then			
			self.text_overlay:text(a.summon_time):center()
			self.old_time = a.summon_time
		end
	end

	local p = math.min(1, math.max(0, a.life / a.max_life))
	if p ~= self.old_p then
		self.lifebar:tween(7, "scale_y", nil, p):tween(7, "y", nil, math.ceil(40 * (1-p)))
		self.old_p = p
	end
end
