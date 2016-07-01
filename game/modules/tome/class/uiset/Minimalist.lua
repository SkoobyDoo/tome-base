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
local UI = require "engine.ui.Base"
local UISet = require "mod.class.uiset.UISet"
local Dialog = require "engine.ui.Dialog"
local Map = require "engine.Map"
local FontPackage = require "engine.FontPackage"

module(..., package.seeall, class.inherit(UISet, TooltipsData))

function _M:init()
	UISet.init(self)

	self.renderer = core.renderer.renderer():zSort(false)
	self.minicontainers = {}
	self.locked = true
end

function _M:isLocked()
	return self.locked
end

function _M:switchLocked()
	self.locked = not self.locked
	for i, container in ipairs(self.minicontainers) do container:locked(self.locked) end
	if self.locked then
		game.bignews:say(60, "#CRIMSON#Interface locked, mouse enabled on the map")
	else
		game.bignews:say(60, "#CRIMSON#Interface unlocked, mouse disabled on the map")
	end
end

function _M:getMainMenuItems()
	return {
		{"Reset interface positions", function() Dialog:yesnoPopup("Reset UI", "Reset all the interface?", function(ret) if ret then
			self:resetPlaces() self:saveSettings() 
		end end) end},
	}
end

--- Forbid some options from showing up, they are useless for this ui
function _M:checkGameOption(name)
	local list = table.reverse{"icons_temp_effects", "icons_hotkeys", "hotkeys_rows", "log_lines"}
	return not list[name]
end

_M.allcontainers = {
	playerframe = "mod.class.uiset.minimalist.PlayerFrame",
	gamelog = "mod.class.uiset.minimalist.Log",
	minimap = "mod.class.uiset.minimalist.Minimap",
	toolbar = "mod.class.uiset.minimalist.Toolbar",
}

function _M:activate()
	for name, class in pairs(self.allcontainers) do
		self[name] = require(class).new(self)
		self.minicontainers[#self.minicontainers+1] = self[name]
		self.renderer:add(self[name]:getDO())
	end

	game.log = function(style, ...) if type(style) == "number" then game.uiset.logdisplay(...) else game.uiset.logdisplay(style, ...) end end
	game.logChat = function(style, ...)
		if true or not config.settings.tome.chat_log then return end
		if type(style) == "number" then
		local old = game.uiset.logdisplay.changed
		game.uiset.logdisplay(...) else game.uiset.logdisplay(style, ...) end
		if game.uiset.show_userchat then game.uiset.logdisplay.changed = old end
	end
--	game.logSeen = function(e, style, ...) if e and e.player or (not e.dead and e.x and e.y and game.level and game.level.map.seens(e.x, e.y) and game.player:canSee(e)) then game.log(style, ...) end end
	game.logPlayer = function(e, style, ...) if e == game.player or e == game.party then game.log(style, ...) end end

	self:placeContainers()
end

function _M:placeContainers()
	for _, container in ipairs(self.minicontainers) do
		local x, y = container:getDefaultGeometry()
		container:move(x, y)
	end
end

function _M:display(nb_keyframes)
	local d = core.display
	self.now = core.game.getTime()

	-- Now the map, if any
	game:displayMap(nb_keyframes)

	if game.creating_player then return end
	if self.no_ui then return end

	Map.viewport_padding_4 = 0
	Map.viewport_padding_6 = 0
	Map.viewport_padding_8 = 0
	Map.viewport_padding_2 = 0

	for _, container in ipairs(self.minicontainers) do container:update(nb_keyframes) end
	self.renderer:toScreen()
	UISet.display(self, nb_keyframes)
end

function _M:setupMouse(mouse)
	for _, container in ipairs(self.minicontainers) do container:setupMouse(true) end
end
