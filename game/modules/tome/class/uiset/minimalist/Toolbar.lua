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
local MiniContainer = require "mod.class.uiset.minimalist.MiniContainer"
local Map = require "engine.Map"

--- Player frame for Minimalist ui
module(..., package.seeall, class.inherit(MiniContainer))

_M.iconslist = {
	{name="tb_talents", file="hotkeys/talents.png", fct=function() game.key:triggerVirtual("USE_TALENTS") end, tooltip="Click to show known talents"},
	{name="tb_inven", file="hotkeys/inventory.png", fct=function() game.key:triggerVirtual("SHOW_INVENTORY") end, tooltip="Click to show inventory"},
	{name="tb_lore", file="hotkeys/lore.png", fct=function(button) if button == "left" then game.key:triggerVirtual("SHOW_QUESTS") elseif button == "right" then game:registerDialog(require("mod.dialogs.ShowLore").new("Tales of Maj'Eyal Lore", game.party)) end end, tooltip="Left mouse to show quest log.\nRight mouse to show all known lore."},
	{name="tb_quest", file="hotkeys/quest.png", fct=function() game.key:triggerVirtual("SHOW_MESSAGE_LOG") end, tooltip="Click to show message/chat log."},
	{name="tb_mainmenu", file="hotkeys/mainmenu.png", fct=function() game.key:triggerVirtual("EXIT") end, tooltip="Click to show main menu"},
	{name="tb_padlock_closed", file="padlock_closed.png", fct=function() game.uiset:switchLocked() end, tooltip="Unlock all interface elements so they can be moved and resized."},
	{name="tb_padlock_open", file="padlock_open.png", no_increment=true, fct=function() game.uiset:switchLocked() end, tooltip="Lock all interface elements so they can not be moved nor resized."},
}

function _M:init(minimalist, w, h)
	self.do_container = core.renderer.container() -- Should we use renderer or container ?

	self.nb_icons = 0
	for _, d in ipairs(self.iconslist) do
		local icon = core.renderer.container():scale(0.5, 0.5, 1)
		local bg
		bg, self.icon_w, self.icon_h = self:imageLoader("hotkeys/icons_bg.png")
		self.icon_w, self.icon_h = self.icon_w / 2, self.icon_h / 2 -- because of 0.5 scale
		icon:add(bg:translate(0, 0, 0))
		icon:add(self:imageLoader(d.file):translate(0, 0, 0))
		self.do_container:add(icon)
		self[d.name] = icon:color(1, 1, 1, 0.5)
		self[d.name.."_bg"] = bg
		if not d.no_increment then self.nb_icons = self.nb_icons + 1 end
	end

	MiniContainer.init(self, minimalist)

	for _, d in ipairs(self.iconslist) do
		self.mouse:registerZone(0, 0, self.icon_w, self.icon_h, self:tooltipAll(function(button, mx, my, xrel, yrel, bx, by, event)
			if event == "button" then d.fct(button)
			elseif event == "out" then self[d.name]:tween(8, "a", nil, 0.5)
			elseif event == "motion" then self[d.name]:tween(5, "a", nil, 1)
			end
		end, d.tooltip), nil, d.name, true, 1)
	end

	self:update(0)
end

function _M:onFocus(v)
	if v then return end
	for _, d in ipairs(self.iconslist) do self[d.name]:tween(8, "a", nil, 0.5) end
end

function _M:update(nb_keyframes)
	if self.old_orientation ~= self.orientation then
		local x, y = 0, 0
		for _, d in ipairs(self.iconslist) do
			self[d.name]:translate(x, y, 0)
			self.mouse:updateZone(d.name, x, y, self.icon_w, self.icon_h, nil, self.scale)
			if not d.no_increment then y = y + self.icon_h end
		end
	end
	if self.old_locked ~= self.locked then
		self.tb_padlock_closed:shown(self.locked)
		self.tb_padlock_open:shown(not self.locked)
	end
end

function _M:getDefaultGeometry()
	local w = self.icon_w
	local h = self.icon_h * self.nb_icons
	local x = game.w - w
	local y = game.h - h
	return x, y, w, h
end

function _M:move(x, y)
	MiniContainer.move(self, x, y)
	self:getDO():translate(x, y, 0)
end

function _M:resize(w, h)
	MiniContainer.resize(self, w, h)
end
