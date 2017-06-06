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
local Shader = require "engine.Shader"
local FontPackage = require "engine.FontPackage"
local Tiles = require "engine.Tiles"
local PartyMember = require "mod.class.uiset.minimalist.sub.PartyMember"

--- Player frame for Minimalist ui
module(..., package.seeall, class.inherit(MiniContainer))

function _M:init(minimalist, w, h)
	self.rw, self.rh = 40, 40

	self.tiles = Tiles.new(38, 38, nil, nil, true, true)
	self.tiles.use_images = true
	self.tiles.force_back_color = {r=0, g=0, b=0}

	MiniContainer.init(self, minimalist)

	local font_mono, size_mono = FontPackage:getFont("mono_small", "mono")
	self.buff_font = core.display.newFont(font_mono, size_mono, true)

	self.do_container = core.renderer.renderer("dynamic"):setRendererName("Party MiniContainer")

	self.all = {}

	self.backs_layer = core.renderer.container()
	self.icons_layer = core.renderer.container()
	self.frames_layer = core.renderer.container()
	self.texts_layer = core.renderer.container()

	self.do_container:add(self.backs_layer):add(self.icons_layer):add(self.frames_layer):add(self.texts_layer)

	self.base_portrait = self:texLoader("party-portrait.png")
	self.base_portrait_unsel = self:texLoader("party-portrait-unselect.png")
	self.base_portrait_lev = self:texLoader("party-portrait-lev.png")
	self.base_portrait_unsel_lev = self:texLoader("party-portrait-unselect-lev.png")

	game:registerEventUI(self, "Party:switchedPlayer")
	game:registerEventUI(self, "Party:addMember")
	game:registerEventUI(self, "Party:removeMember")
	self:onEventUI(nil, nil)
end

function _M:getName()
	return "Party"
end

function _M:getMoveHandleLocation()
	return self.w - self.move_handle_w, self.h - self.move_handle_h
end

function _M:getDefaultGeometry()
	local w = self.rw * 2
	local h = self.rh
	local x = 350
	local y = 0
	return x, y, w, h
end

function _M:getDefaultOrientation()
	return "top"
end

function _M:onSnapChange()
	self.force_reordering = true
end

function _M:move(x, y)
	MiniContainer.move(self, x, y)
	self.force_reordering = true
end

function _M:resize(w, h)
	MiniContainer.resize(self, w, h)
	self.force_reordering = true
end

function _M:toggleFrame()
	self.configs.hide_frame = not self.configs.hide_frame
	for _, res_gfx in ipairs(self.resources_defs) do res_gfx.old = {} end
	self.uiset:saveSettings()
end

function _M:lock(v)
	MiniContainer.lock(self, v)
	if v then
		self.force_reordering = true
	end
end

function _M:forceOrientation(what)
	self.configs.force_orientation = what
	self:onSnapChange()
	self.uiset:saveSettings()
end

function _M:loadConfig(config)
	MiniContainer.loadConfig(self, config)
	self:onSnapChange()
end

function _M:editMenu()
	local list = {
		{ name = "Force orientation: natural", fct=function() self:forceOrientation("natural") end },
		{ name = "Force orientation: horizontal", fct=function() self:forceOrientation("horizontal") end },
		{ name = "Force orientation: vertical", fct=function() self:forceOrientation("vertical") end },
	}
	return list
end

function _M:update(nb_keyframes)
	for _, de in pairs(self.all) do de:update() end
end

function _M:updateList()
	local plist = {}, {}

	if game.party and #game.party.m_list >= 2 and game.level then
		for i = 1, #game.party.m_list do
			local a = game.party.m_list[i]
			local de = self.all[a]
			if not de then de = PartyMember.new(self, a)
			else self.all[a] = nil end
			plist[i] = {a=a, de=de}
		end
	end

	-- Remove old
	for eff_id, de in pairs(self.all) do de:delete() end
	self.all = {}

	local x = 0
	local y = 0
	for i, d in ipairs(plist) do
		self.all[d.a] = d.de
		d.de:move(x, y)
		x = x + self.rw
	end
	self.mouse_zone_x = 0
	self.mouse_zone_y = 0
	self.mouse_zone_w = self.rw + x
	self.mouse_zone_h = self.rh + y
	self:setupMouse()

	for a, de in pairs(self.all) do de:positionMouse(self.mouse_zone_x, self.mouse_zone_y) end
end

function _M:onEventUI(kind, who, v1, ...)
	self:updateList()
end
