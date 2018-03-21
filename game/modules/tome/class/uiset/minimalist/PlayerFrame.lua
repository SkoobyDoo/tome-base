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
local FontPackage = require "engine.FontPackage"
local MiniContainer = require "mod.class.uiset.minimalist.MiniContainer"
local Map = require "engine.Map"

--- Player frame for Minimalist ui
module(..., package.seeall, class.inherit(MiniContainer))

local configs = {
	dark = {
		bg = {x=0, y=-5},
		player = {x=22+5, y=22-4},
		attack = {x=22+8, y=67-8},
		encumber = {x=162, y=38},
		expbar = {x=115+10, y=89-1},
		levelup = {x=269-5, y=78-9},
		exp = {x=87+7, y=89-1},
		name = {x=166+10, y=13-2},
		level = {x=253+9, y=46-2},
		money = {x=112+7, y=43-2},
	},
	metal = {
		bg = {x=0, y=0},
		player = {x=22, y=22},
		attack = {x=22, y=67},
		encumber = {x=162, y=38},
		expbar = {x=115, y=89},
		levelup = {x=269, y=78},
		exp = {x=87, y=89},
		name = {x=166, y=13},
		level = {x=253, y=46},
		money = {x=112, y=43},
	},
}

function _M:init(minimalist, w, h)
	local config = configs[UI.ui] or configs.dark

	local pf_bg, pf_defend_w, pf_defend_h, pf_levelup_w, pf_levelup_h
	pf_bg, self.def_w, self.def_h = self:imageLoader("playerframe/back.png")
	local pf_shadow = self:imageLoader("playerframe/shadow.png")
	self.pf_defend, pf_defend_w, pf_defend_h = self:imageLoader("playerframe/defend.png") 
	self.pf_attack = self:imageLoader("playerframe/attack.png") 
	self.pf_levelup, pf_levelup_w, pf_levelup_h = self:imageLoader("playerframe/levelup.png") 
	self.pf_encumber = self:imageLoader("playerframe/encumber.png") 
	local expbar_w, expbar_h, lexpbar_w, lexpbar_h
	self.pf_exp, expbar_w, expbar_h = self:imageLoader("playerframe/exp.png")
	self.pf_exp_levelup, lexpbar_w, lexpbar_h = self:imageLoader("playerframe/exp_levelup.png")

	local font, smallfont = FontPackage:get("resources_normal", true), FontPackage:get("resources_small", true)

	self.do_container = core.renderer.renderer("static"):zSort(true):setRendererName("playerframe") -- Should we use renderer or container ?
	self.do_container:add(pf_shadow) pf_shadow:translate(0, 0, -0.1)
	self.do_container:add(pf_bg) pf_bg:translate(config.bg.x, config.bg.y, 0)
	self.do_container:add(self.pf_defend) self.pf_defend:translate(config.attack.x, config.attack.y, 0)
	self.do_container:add(self.pf_attack) self.pf_attack:translate(config.attack.x, config.attack.y, 0)
	self.do_container:add(self.pf_levelup) self.pf_levelup:translate(config.levelup.x, config.levelup.y, 0)
	self.do_container:add(self.pf_encumber) self.pf_encumber:translate(config.encumber.x, config.encumber.y, 0)
	self.do_container:add(self.pf_exp) self.pf_exp:translate(config.expbar.x, config.expbar.y - expbar_h / 2, 0)
	self.do_container:add(self.pf_exp_levelup) self.pf_exp_levelup:translate(config.expbar.x, config.expbar.y - lexpbar_h / 2, 0)

	self.text_level = core.renderer.text(font)
	self.do_container:add(self.text_level) self.text_level:translate(config.level.x, config.level.y, 10)

	self.text_name = core.renderer.text(font)
	self.do_container:add(self.text_name) self.text_name:translate(config.name.x, config.name.y, 10)

	self.text_exp = core.renderer.text(font)
	self.do_container:add(self.text_exp) self.text_exp:translate(config.exp.x, config.exp.y, 10)

	self.text_money = core.renderer.text(font)
	self.text_money:textColor(colors.unpack1(colors.GOLD))
	self.do_container:add(self.text_money) self.text_money:translate(config.money.x, config.money.y, 10)

	self.full_container = core.renderer.container()
	self.full_container:add(self.do_container)

	MiniContainer.init(self, minimalist)

	self.mouse:registerZone(config.attack.x, config.attack.y, pf_defend_w, pf_defend_h, self:tooltipButton(function(button, mx, my, xrel, yrel, bx, by, event)
		game.key:triggerVirtual("TOGGLE_BUMP_ATTACK")
	end, "Toggle for movement mode.\nDefault: when trying to move onto a creature it will attack if hostile.\nPassive: when trying to move onto a creature it will not attack (use ctrl+direction, or right click to attack manually)"), nil, "attack", false, 1)
	self.mouse:registerZone(config.levelup.x, config.levelup.y, pf_levelup_w, pf_levelup_h, self:tooltipButton(function(button, mx, my, xrel, yrel, bx, by, event)
		game.key:triggerVirtual("LEVELUP")
	end, "Show character infos"), nil, "levelup", false, 1)
	self.mouse:registerZone(config.player.x, config.player.y, 40, 40, self:tooltipButton(function(button, mx, my, xrel, yrel, bx, by, event)
		game.key:triggerVirtual("SHOW_CHARACTER_SHEET")
	end, "Click to assign stats and talents!"), nil, "charsheet", false, 1)

	self:update(0)
end

function _M:getName()
	return "Player Character"
end

function _M:getDefaultGeometry()
	local x = 0
	local y = 0
	local w = self.def_w
	local h = self.def_h
	return x, y, w, h
end

function _M:update(nb_keyframes)
	local player = self:getPlayer()
	if not player then
		if self.old_player ~= player then self.do_container:shown(false) end
		self.old_player = player
		return
	else
		if self.old_player ~= player then
			local config = configs[UI.ui] or configs.dark
			self.do_container:shown(true)
			if self.player_do then self.do_container:remove(self.player_do) end
			self.player_do = player:getDO(40, 40):translate(config.player.x, config.player.y, 1)
			self.do_container:add(self.player_do)
		end
	end
	self.old_player = player

	if self.old_exp ~= player.exp then
		local cur_exp, max_exp = player.exp, player:getExpChart(player.level+1)
		local v = math.min(1, math.max(0, cur_exp / max_exp))
		self.text_exp:text(("%d%%"):format(v * 100))
		self.text_exp:center()
		self.pf_exp:scale(v, 1, 1)
		self.pf_exp_levelup:scale(v, 1, 1)
		self.old_exp = player.exp
	end
	if self.old_money ~= player.money then self.text_money:text(("%d"):format(player.money)) self.text_money:center() self.old_money = player.money end
	if self.old_level ~= player.level then self.text_level:text("Lvl "..player.level) self.old_level = player.level end
	if self.old_name ~= player.name then self.text_name:text(player.name) self.old_name = player.name end

	local v = (not config.settings.tome.actor_based_movement_mode and self or player).bump_attack_disabled and true or false
	if self.old_attack == nil or self.old_attack ~= v then
		self.pf_defend:shown(v)
		self.pf_attack:shown(not v)
		self.old_attack = v
	end

	if self.old_encumber == nil or self.old_encumber ~= (player:attr("encumbered") and true or false) then
		self.pf_encumber:shown(player:attr("encumbered") and true or false)
		self.old_encumber = player:attr("encumbered") and true or false
	end

	local v = player.unused_stats + player.unused_talents + player.unused_generics + player.unused_talents_types
	if self.old_levelup ~= v then
		self.old_levelup = v
		v = v > 0
		self.pf_levelup:shown(v)
		self.pf_exp_levelup:shown(v)
	end
end

function _M:getPlayer()
	return game:getPlayer()
end

function _M:move(x, y)
	MiniContainer.move(self, x, y)
end

function _M:resize(w, h)
	MiniContainer.resize(self, w, h)
end

function _M:getDO()
	return self.full_container
end

function _M:loadConfig(config)
	MiniContainer.loadConfig(self, config)
	self.do_container:shown(not self.configs.hide)
end

function _M:toggleDisplay()
	self.configs.hide = not self.configs.hide
	self.do_container:shown(not self.configs.hide)
	self.uiset:saveSettings()
end

function _M:editMenu()
	return {
		{ name = "Toggle display", fct=function() self:toggleDisplay() end },
	}
end
