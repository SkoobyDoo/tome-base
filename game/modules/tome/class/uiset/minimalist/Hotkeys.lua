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
local FontPackage = require "engine.FontPackage"
local HotkeysIconsDisplay = require "engine.HotkeysIconsDisplay"
local MiniContainer = require "mod.class.uiset.minimalist.MiniContainer"
local UI = require "engine.ui.Base"

--- Log display for Minimalist ui
module(..., package.seeall, class.inherit(MiniContainer))

function _M:init(minimalist)
	MiniContainer.init(self, minimalist)

	local font_mono, size_mono = FontPackage:getFont("mono_small", "mono")
	self.hotkeys_display_icons = HotkeysIconsDisplay.new(nil, 0, 0, self.w, self.h, nil, font_mono, size_mono, config.settings.tome.hotkey_icons_size, config.settings.tome.hotkey_icons_size)
	self.hotkeys_display_icons:setTextOutline(0.7)
	self.hotkeys_display_icons.actor = game.player

	minimalist.hotkeys_display_icons = self.hotkeys_display_icons -- for old code compatibility
	minimalist.hotkeys_display = self.hotkeys_display_icons

	local hkframe = self:makeFrameDO("hotkeys/hotkey_", nil, nil, self.w, self.h)
	self.hotkeys_display_icons.bg_container:add(hkframe.container:translate(-4 - hkframe.b7.w, -4 - hkframe.b7.h))

	self.mouse:dragListener(true)
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, mx, my, xrel, yrel, bx, by, event)
		if event == "button" and button == "left" and ((game.zone and game.zone.wilderness and not game.player.allow_talents_worldmap) or (game.key ~= game.normal_key)) then return end
		self.hotkeys_display_icons:onMouse(button, mx, my, event == "button",
			function(text)
				text = text:toTString()
				text:add(true, "---", true, {"font","italic"}, {"color","GOLD"}, "Left click to use", true, "Right click to configure", true, "Press 'm' to setup", {"color","LAST"}, {"font","normal"})
				game:tooltipDisplayAtMap(game.w, game.h, text)
			end,
			function(i, hk)
				if button == "right" and hk and hk[1] == "talent" then
					local d = require("mod.dialogs.UseTalents").new(game.player)
					d:use({talent=hk[2], name=game.player:getTalentFromId(hk[2]).name}, "right")
					return true
				elseif button == "right" and hk and hk[1] == "inventory" then
					Dialog:yesnoPopup("Unbind "..hk[2], "Remove this object from your hotkeys?", function(ret) if ret then
						for i = 1, 12 * game.player.nb_hotkey_pages do
							if game.player.hotkey[i] and game.player.hotkey[i][1] == "inventory" and game.player.hotkey[i][2] == hk[2] then game.player.hotkey[i] = nil end
						end
					end end)
					return true
				end
			end
		)
	end, nil, "hotkeys", true, 1)
end

function _M:getDefaultGeometry()
	local th = 52
	if config.settings.tome.hotkey_icons then th = (8 + config.settings.tome.hotkey_icons_size) * config.settings.tome.hotkey_icons_rows end

	local x = 10
	local y = game.h - th
	local w = game.w - 60
	local h = th
	return x, y, w, h
end

function _M:getDO()
	return self.hotkeys_display_icons.renderer
end

function _M:move(x, y)
	MiniContainer.move(self, x, y)
	self:getDO():translate(x, y, 100)
end

function _M:resize(w, h)
	MiniContainer.resize(self, w, h)
	self.hotkeys_display_icons:resize(0, 0, w, h)
	self:getDO():translate(self.x, self.y, 100)
end

function _M:update(nb_keyframes)
	self.hotkeys_display_icons:display()
end
