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
	ok = {0.3, 0.6, 0.3, 1},
	ko = {0.6, 0, 0, 1},
}

function _M:init(effects, eff_id)
	local e = effects:getPlayer():getEffectFromId(eff_id)

	self.removable = (e.status == "beneficial") or config.settings.cheat

	local color = e.status ~= "detrimental" and frames_colors.ok or frames_colors.ko

	self.effects = effects
	self.eff_id = eff_id
	self.frame = UI:cloneFrameDO(effects.base_frame)
	self.display_entity = e.display_entity:getEntityDisplayObject(effects.tiles, 38, 38, 1, false, false, true)
	self.texts = core.renderer.container()
	if e.decrease > 0 then
		local font = e.charges and effects.buff_font_small or effects.buff_font
		self.text_dur = core.renderer.text(font):outline(1, 0, 0, 0, 1)
		if not e.charges then self.text_dur:translate(20, 20, 10) else self.text_dur:translate(20, (38 - font:height()) / 2, 10) self.no_center = true end
		self.texts:add(self.text_dur)
	end
	if e.charges then
		local font = e.decrease > 0 and effects.buff_font_small or effects.buff_font
		self.text_charges = core.renderer.text(font):outline(1, 0, 0, 0, 1)
		if e.decrease == 0 then self.text_charges:translate(20, 20, 10) else self.text_charges:translate(2, 38 - font:height(), 10) self.no_center = true end
		self.texts:add(self.text_charges)
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

function _M:getDescription(player, e, p)
	local name = e.desc
	local desc = nil
	local eff_subtype = table.concat(table.keys(e.subtype), "/")
	if e.display_desc then name = e.display_desc(self, p) end
	if p.save_string and p.amount_decreased and p.maximum and p.total_dur then
		desc = ("#{bold}##GOLD#%s\n(%s: %s)#WHITE##{normal}#\n"):format(name, e.type, eff_subtype)..e.long_desc(player, p).." "..("%s reduced the duration of this effect by %d turns, from %d to %d."):format(p.save_string, p.amount_decreased, p.maximum, p.total_dur)
	else
		desc = ("#{bold}##GOLD#%s\n(%s: %s)#WHITE##{normal}#\n"):format(name, e.type, eff_subtype)..e.long_desc(player, p)
	end
	if self.removable then desc = desc.."\n---\nRight click to cancel early." end
	return desc
end

function _M:positionMouse(x, y)
	self.effects.mouse:replaceZone(self.x - x, self.y - y, 40, 40, function(button, mx, my, xrel, yrel, bx, by, event)
		local player = self.effects:getPlayer()
		local p = player.tmp[self.eff_id]
		if not p then return end
		local e = player:getEffectFromId(self.eff_id)

		if config.settings.cheat and event == "button" and core.key.modState("shift") then
			if button == "left" then
				p.dur = p.dur + 1
			elseif button == "right" then
				p.dur = p.dur - 1
			end
		elseif self.removable and event == "button" and button == "right" then
			Dialog:yesnoPopup(e.desc, "Really cancel "..e.desc.."?", function(ret)
				if ret then
					player:removeEffect(self.eff_id)
				end
			end)
		end

		game:tooltipDisplayAtMap(game.w, game.h, self:getDescription(player, e, p))
	end, nil, "effects:"..self.eff_id, true, 1)
end

function _M:update(player)
	local p = player.tmp[self.eff_id]
	if not p then return end

	if self.text_dur and p.dur ~= self.old_dur then
		self.text_dur:text(p.dur + 1)
		if not self.no_center then self.text_dur:center() end
		self.old_dur = p.dur
	end

	if self.text_charges then
		local e = player:getEffectFromId(self.eff_id)
		local charges = e.charges(player, p) or 0
		if charges ~= self.old_charges then
			self.text_charges:text(charges)
			if not self.no_center then self.text_charges:center() end
			self.old_charges = charges
		end
	end
end
