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

function _M:init(effects, tid)
	local t = effects:getPlayer():getTalentFromId(tid)

	local color = frames_colors.sustain

	self.effects = effects
	self.tid = tid
	self.frame = UI:cloneFrameDO(effects.base_frame)
	self.display_entity = t.display_entity:getEntityDisplayObject(effects.tiles, 38, 38, false, true)
	self.texts = core.renderer.container()
	if t.iconOverlay then
		self.text_overlay = core.renderer.text(effects.buff_font):outline(1, 0, 0, 0, 1)
		self.text_overlay:translate(20, 20, 10)
		self.texts:add(self.text_overlay)
	end

	effects.frames_layer:add(self.frame.container:color(unpack(color)))
	effects.icons_layer:add(self.display_entity)
	effects.texts_layer:add(self.texts)
end

function _M:delete()
	self.texts:removeFromParent()
	self.frame.container:removeFromParent()
	self.display_entity:removeFromParent()
end

function _M:move(x, y)
	self.x, self.y = x, y
	self.texts:translate(x, y)
	self.frame.container:translate(x, y)
	self.display_entity:translate(x + 2, y + 2)
end

function _M:getDescription(player, t, p)
	local displayName = t.name
	if t.getDisplayName then displayName = t.getDisplayName(player, t, p) end
	local desc = "#GOLD##{bold}#"..displayName.."#{normal}##WHITE#\n"..tostring(player:getTalentFullDescription(t))
	return desc
end

function _M:positionMouse(x, y)
	self.effects.mouse:replaceZone(self.x - x, self.y - y, 40, 40, function(button, mx, my, xrel, yrel, bx, by, event)
		local player = self.effects:getPlayer()
		local p = player.sustain_talents[self.tid]
		if not p then return end
		local t = player:getTalentFromId(self.tid)

		game:tooltipDisplayAtMap(game.w, game.h, self:getDescription(player, t, p))
	end, nil, "effects:"..self.tid, true, 1)
end

function _M:update(player)
	local p = player.sustain_talents[self.tid]
	if not p then return end

	if self.text_overlay then
		local t = player:getTalentFromId(self.tid)
		local o, fnt = t.iconOverlay(player, t, p)
		if o ~= self.old_overlay then			
			self.text_overlay:text(o):center()
			if fnt == "buff_font_small" then self.text_overlay:scale(0.8, 0.8, 1)
			elseif fnt == "buff_font_smaller" then self.text_overlay:scale(0.65, 0.65, 1)
			end
			self.old_overlay = o
		end
	end
end
