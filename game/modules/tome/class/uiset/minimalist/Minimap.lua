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
local FontPackage = require "engine.FontPackage"
local MiniContainer = require "mod.class.uiset.minimalist.MiniContainer"
local Map = require "engine.Map"

--- Player frame for Minimalist ui
module(..., package.seeall, class.inherit(MiniContainer))

local configs = {
	dark = {
		offset = {x=-5, y=-3},
		compass = {x=169, y=178},
		draw = {x=55, y=32},
	},
	metal = {
		offset = {x=0, y=0},
		compass = {x=169, y=178},
		draw = {x=50, y=30},
	},
}

function _M:init(minimalist, w, h)
	local config = configs[UI.ui] or configs.dark

	self.do_container = core.renderer.container() -- Should we use renderer or container ?

	local font = FontPackage:get("resources_normal", true)
	local font_h = font:lineSkip()

	local mm_shadow = self:imageLoader("minimap/shadow.png"):translate(0, 2, 0)
	local mm_bg
	mm_bg, self.def_w, self.def_h = self:imageLoader("minimap/back.png")
	mm_bg:translate(config.offset.x, config.offset.y, 0)
	local mm_comp = self:imageLoader("minimap/compass.png"):translate(config.compass.x, config.compass.y, 0)
	local mm_transp = self:imageLoader("minimap/transp.png"):translate(config.draw.x, config.draw.y, 0)
	self.mm_container = core.renderer.container():translate(config.draw.x, config.draw.y, 0)

	self.text_name = core.renderer.text(font):translate(self.def_w / 2, 2 + font_h / 2, 10):textColor(colors.unpack1(colors.GOLD))
	self.do_container:add(mm_shadow)
	self.do_container:add(mm_bg)
	self.do_container:add(self.mm_container)
	self.do_container:add(mm_transp)
	self.do_container:add(mm_comp)
	self.do_container:add(self.text_name)

	MiniContainer.init(self, minimalist)
	self:update(0)

	self.mouse:registerZone(config.draw.x, config.draw.y, 150, 150, function(button, mx, my, xrel, yrel, bx, by, event)
		if button == "left" and not xrel and not yrel and event == "button" then
			local tmx, tmy = math.floor(bx / 3), math.floor(by / 3)
			game.player:mouseMove(tmx + game.minimap_scroll_x, tmy + game.minimap_scroll_y)
		elseif button == "right" then
			local tmx, tmy = math.floor(bx / 3), math.floor(by / 3)
			game.level.map:moveViewSurround(tmx + game.minimap_scroll_x, tmy + game.minimap_scroll_y, 1000, 1000)
		elseif event == "button" and button == "middle" then
			game.key:triggerVirtual("SHOW_MAP")
		end
	end, nil, "minimap", true, 1)
end

function _M:getDefaultGeometry()
	local y = 0
	local w = self.def_w
	local h = self.def_h
	local x = game.w - w
	return x, y, w, h
end

function _M:update(nb_keyframes)
	if self.old_name ~= game.zone_name then self.text_name:text(game.zone_name or ""):center() end
	if game.level and game.level.map and self.old_map ~= game.level.map then
		self.mm_do = game.level.map:getMinimapDO()
		self.mm_container:clear()
		self.mm_container:add(self.mm_do)
	end
	if self.mm_do then
		if game.player.x then game.minimap_scroll_x, game.minimap_scroll_y = util.bound(game.player.x - 25, 0, game.level.map.w - 50), util.bound(game.player.y - 25, 0, game.level.map.h - 50)
		else game.minimap_scroll_x, game.minimap_scroll_y = 0, 0 end
		self.mm_do:setMinimapInfo(3, game.minimap_scroll_x, game.minimap_scroll_y, 50, 50, 0.85)
	end
end

function _M:move(x, y)
	MiniContainer.move(self, x, y)
	self:getDO():translate(x, y, 0)
end

function _M:resize(w, h)
	MiniContainer.resize(self, w, h)
end
