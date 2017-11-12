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
local LogDisplay = require "engine.LogDisplay"
local MiniContainer = require "mod.class.uiset.minimalist.MiniContainer"

--- Log display for Minimalist ui
module(..., package.seeall, class.inherit(MiniContainer))

function _M:init(minimalist)
	MiniContainer.init(self, minimalist)
	self.do_container = core.renderer.container()

	self.mouse:registerZone(0, 0, self.w, self.h, function(button, mx, my, xrel, yrel, bx, by, event)
		if self.ui and self.ui.mouseEvent then self.ui:mouseEvent(button, mx, my, xrel, yrel, bx, by, event) end
	end, nil, "customui", true, 1)
end

function _M:getName()
	return "Zone Specific Interface"
end

function _M:getDefaultGeometry()
	local th = 60
	if config.settings.tome.hotkey_icons then th = (19 + config.settings.tome.hotkey_icons_size) * config.settings.tome.hotkey_icons_rows end

	local w = 150
	local h = 150
	local x = 0
	local y = game.h - math.floor(game.h / 4) - th - th - h
	return x, y, w, h
end

function _M:move(x, y)
	MiniContainer.move(self, x, y)
	if self.ui and self.ui.onMove then self.ui:onMove(x, y) end
end

function _M:resize(w, h)
	MiniContainer.resize(self, w, h)
	if self.ui and self.ui.onResize then self.ui:onResize(w, h) end
end

function _M:setupCustom(ui)
	if not ui then
		if self.ui and self.ui.onTakedown then self.ui:onTakedown(self) end
		self.ui = nil
	else
		self.ui = ui
		self.do_container:add(ui:onSetup(self))
	end
end

function _M:loadUI(zone)
	-- Load custom zone UI if it exists
	local basedir = zone:getBaseName()
	if fs.exists(basedir.."custom_ui.lua") then
		local f = loadfile(basedir.."custom_ui.lua")
		setfenv(f, setmetatable({current_zone=zone, UIBase=require "engine.ui.Base", mini_container=self, class=class, FontPackage=FontPackage}, {__index=_G}))
		local custom_ui = f()

		self:triggerHook{"Zone:loadCustomUI", zone=self.short_name, custom_ui=custom_ui}
		return custom_ui
	end
end

function _M:update(nb_keyframes)
	if game.zone and game.zone ~= self.old_zone then
		self:setupCustom(self:loadUI(game.zone))
		self.old_zone = game.zone
	end

	if self.ui and self.ui.onUpdate then self.ui:onUpdate(nb_keyframes) end
end
