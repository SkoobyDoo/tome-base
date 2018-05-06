-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2018 Nicolas Casalini
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
local KeyBind = require "engine.KeyBind"

module(..., package.seeall, class.inherit(UISet, TooltipsData))

function _M:init()
	UISet.init(self)

	self.renderer = core.renderer.renderer():setRendererName("Minimalist Main Renderer"):zSort(true)
	self.minicontainers = {}
	self.locked = true
end

function _M:isLocked()
	return self.locked
end

function _M:switchLocked()
	self.locked = not self.locked
	for i, container in ipairs(self.minicontainers) do
		container:lock(self.locked)
		if not self.locked then container:getDO():add(container:getUnlockedDO())
		else container:getDO():remove(container:getUnlockedDO()) end
	end
	if self.locked then
		game.key = self.unlock_game_key_save
		game.key:setCurrent()
		game.bignews:say(60, "#CRIMSON#Interface locked, keyboard and mouse enabled.")
	else
		self.unlock_game_key_save = game.key
		local key = KeyBind.new()
		game.key = key
		game.key:setCurrent()
		game.bignews:say(60, "#CRIMSON#Interface unlocked, keyboard and mouse disabled.")

		key:addCommand(key._ESCAPE, nil, function() self:switchLocked() end)
	end
end

function _M:resetPlaces()
	config.settings.tome.uiset_minimalist2.places = {}
	for i, container in ipairs(self.minicontainers) do
		local x, y, w, h = container:getDefaultGeometry()
		container:move(x, y)
		container:resize(w, h)
		container:setScale(1)
		container:setAlpha(1)
		container.configs = {}
		container:loadConfig{}
	end	
	self:saveSettings()
end

function _M:getMainMenuItems()
	return {
		{"Reset interface positions", function() Dialog:yesnoPopup("Reset UI", "Reset all the interface?", function(ret) if ret then
			self:resetPlaces()
		end end) end},
	}
end

--- Forbid some options from showing up, they are useless for this ui
function _M:checkGameOption(name)
	local list = table.reverse{"icons_temp_effects", "icons_hotkeys", "hotkeys_rows", "log_lines"}
	return not list[name]
end

_M.allcontainers = {
	"mod.class.uiset.minimalist.PlayerFrame",
	"mod.class.uiset.minimalist.Minimap",
	"mod.class.uiset.minimalist.Resources",
	"mod.class.uiset.minimalist.Effects",
	"mod.class.uiset.minimalist.Hourglass",
	"mod.class.uiset.minimalist.Hotkeys",
	"mod.class.uiset.minimalist.Party",
	"mod.class.uiset.minimalist.Log",
	"mod.class.uiset.minimalist.UserChat",
	"mod.class.uiset.minimalist.CustomZone",
	"mod.class.uiset.minimalist.Toolbar",
}

function _M:saveSettings()
	-- self:boundPlaces()

	local lines = {}
	lines[#lines+1] = ("tome.uiset_minimalist2 = {}"):format()
	lines[#lines+1] = ("tome.uiset_minimalist2.save_size = {w=%d, h=%d}"):format(game.w, game.h)
	lines[#lines+1] = ("tome.uiset_minimalist2.places = {}"):format(w)
	for _, container in ipairs(self.minicontainers) do
		local id = container.container_id
		lines[#lines+1] = ("tome.uiset_minimalist2.places[%q] = {}"):format(id)
		lines[#lines+1] = ("tome.uiset_minimalist2.places[%q].x = %f"):format(id, container.x)
		lines[#lines+1] = ("tome.uiset_minimalist2.places[%q].y = %f"):format(id, container.y)
		lines[#lines+1] = ("tome.uiset_minimalist2.places[%q].w = %f"):format(id, container.w)
		lines[#lines+1] = ("tome.uiset_minimalist2.places[%q].h = %f"):format(id, container.h)
		lines[#lines+1] = ("tome.uiset_minimalist2.places[%q].scale = %f"):format(id, container.scale)
		lines[#lines+1] = ("tome.uiset_minimalist2.places[%q].alpha = %f"):format(id, container.alpha)
		if next(container.configs) then
			lines[#lines+1] = ("tome.uiset_minimalist2.places[%q].configs = {}"):format(id)
			for k, v in pairs(container.configs) do
				if type(v) == "string" then
					lines[#lines+1] = ("tome.uiset_minimalist2.places[%q].configs[%q] = %q"):format(id, k, v)
				elseif type(v) == "number" then
					lines[#lines+1] = ("tome.uiset_minimalist2.places[%q].configs[%q] = %f"):format(id, k, v)
				elseif type(v) == "boolean" then
					lines[#lines+1] = ("tome.uiset_minimalist2.places[%q].configs[%q] = %s"):format(id, k, v and "true" or "false")
				else
					error("Saving MiniContainer configs, key "..tostring(k).." has wrong value")
				end
			end
		end
	end

	self:triggerHook{"UISet:Minimalist:saveSettings", lines=lines}

	game:saveSettings("tome.uiset_minimalist2", table.concat(lines, "\n"))
end

function _M:activate()
	local font_mono, size_mono = FontPackage:getFont("mono_small", "mono")
	local font_mono_h, font_h

	local font, size = FontPackage:getFont("default")
	local f = core.display.newFont(font, size)
	font_h = f:lineSkip()
	fm = core.display.newFont(font_mono, size_mono)
	font_mono_h = fm:lineSkip()
	self.font = f
	self.init_font = font
	self.init_size_font = size
	self.init_font_h = font_h
	self.font_mono = fm
	self.init_font_mono = font_mono
	self.init_size_mono = size_mono
	self.init_font_mono_h = font_mono_h

	for _, class in ipairs(self.allcontainers) do
		local c = require(class).new(self)
		self.minicontainers[#self.minicontainers+1] = c
		self.renderer:add(c:getDO())
	end

	game.log = function(style, ...) if type(style) == "number" then game.uiset.logdisplay(...) else game.uiset.logdisplay(style, ...) end end
	game.logChat = function(style, ...)
		if true or not config.settings.tome.chat_log then return end
		if type(style) == "number" then
		local old = game.uiset.logdisplay.changed
		game.uiset.logdisplay(...) else game.uiset.logdisplay(style, ...) end
		if game.uiset.show_userchat then game.uiset.logdisplay.changed = old end
	end
	game.logRollback = function(line, ...) return self.logdisplay:rollback(line, ...) end
	game.logNewest = function() return self.logdisplay:getNewestLine() end
--	game.logSeen = function(e, style, ...) if e and e.player or (not e.dead and e.x and e.y and game.level and game.level.map.seens(e.x, e.y) and game.player:canSee(e)) then game.log(style, ...) end end
	game.logPlayer = function(e, style, ...) if e == game.player or e == game.party then game.log(style, ...) end end

	self:placeContainers()
end

function _M:placeContainers()
	for _, container in ipairs(self.minicontainers) do
		local x, y = container:getDefaultGeometry()
		container:move(x, y)
		if config.settings.tome.uiset_minimalist2 and config.settings.tome.uiset_minimalist2.places and config.settings.tome.uiset_minimalist2.places[container.container_id] then
			container:loadConfig(config.settings.tome.uiset_minimalist2.places[container.container_id])
		end
	end
end

function _M:handleResolutionChange(w, h, ow, oh)
	game:resizeMapViewport(w, h, 0, 0)

	for _, container in ipairs(self.minicontainers) do container:onResolutionChange(w, h, ow, oh) end
	return false
end

function _M:display(nb_keyframes)
	local d = core.display
	self.now = core.game.getTime()

	-- Now the map, if any
	game:displayMap(nb_keyframes, game.full_fbo)

	if game.creating_player then return end
	if self.no_ui then return end

	Map.viewport_padding_4 = 0
	Map.viewport_padding_6 = 0
	Map.viewport_padding_8 = 0
	Map.viewport_padding_2 = 0
	self.map_h_stop_tooltip = game.h

	for _, container in ipairs(self.minicontainers) do container:update(nb_keyframes) end
	self.renderer:toScreen()
	UISet.display(self, nb_keyframes)
end

function _M:setupMouse(mouse)
	for _, container in ipairs(self.minicontainers) do container:setupMouse(true) end
end
