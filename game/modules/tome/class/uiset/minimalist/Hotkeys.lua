-- ToME - Tales of Maj'Eyal
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
local FontPackage = require "engine.FontPackage"
local HotkeysIconsDisplay = require "engine.HotkeysIconsDisplay"
local MiniContainer = require "mod.class.uiset.minimalist.MiniContainer"

--- Log display for Minimalist ui
module(..., package.seeall, class.inherit(MiniContainer))

function _M:init(minimalist)
	MiniContainer.init(self, minimalist)

	local font_mono, size_mono = FontPackage:getFont("mono_small", "mono")
	print(config.settings.tome.hotkey_icons_size, config.settings.tome.hotkey_icons_size)
	self.hotkeys_display_icons = HotkeysIconsDisplay.new(nil, 0, 0, self.w, self.h, nil, font_mono, size_mono, config.settings.tome.hotkey_icons_size, config.settings.tome.hotkey_icons_size)
	self.hotkeys_display_icons:enableShadow(0.6)
	self.hotkeys_display_icons.actor = game.player

	minimalist.hotkeys_display_icons = self.hotkeys_display_icons -- for old code compatibility
	minimalist.hotkeys_display = self.hotkeys_display_icons

	self.mouse:registerZone(0, 0, self.w, self.h, function(button, mx, my, xrel, yrel, bx, by, event)
		
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
	self:getDO():translate(self.x, self.y, 0)
end

function _M:update(nb_keyframes)
	self.hotkeys_display_icons:display()
end
