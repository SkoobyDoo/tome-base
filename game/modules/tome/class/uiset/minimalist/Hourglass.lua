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

function _M:init(minimalist, w, h)
	self.full_container = core.renderer.container()
	self.do_container = core.renderer.container()
	self.full_container:add(self.do_container)

	local shadow
	shadow, self.def_w, self.def_h = self:imageLoader("resources/hourglass_shadow.png")
	self.sand = core.renderer.renderer("static"):setRendererName("Hourglass Sand")
	local front = self:imageLoader("resources/hourglass_front.png")
	local bottom, bw, bh = self:imageLoader("resources/hourglass_bottom.png")
	local top, tw, th = self:imageLoader("resources/hourglass_top.png")
	self.sand:add(top)
	self.sand:add(bottom:translate(0, th))
	self.sand_w = math.max(bw, tw)
	self.sand_h = th + bh

	self.do_container:add(shadow)
	self.do_container:add(self.sand:translate(11, 32))
	self.do_container:add(front)

	local font = FontPackage:get("resources_normal", true)
	self.text = core.renderer.text(font):shadow(1):translate(bw / 2 + 11, font:height() + 32)
	self.do_container:add(self.text)

	MiniContainer.init(self, minimalist)

	self.mouse:registerZone(0, 0, self.w, self.h, function(button, mx, my, xrel, yrel, bx, by, event)
		if event ~= "out" then game.tooltip_x, game.tooltip_y = 1, 1; game:tooltipDisplayAtMap(game.w, game.h, tostring(game.level.turn_counter_desc)) end
	end)

	self:update(0)
end

function _M:getDO()
	return self.full_container
end

function _M:update(nb_keyframes)
	if not game.level or not game.level.turn_counter then
		if self.old_hidden ~= true then
			self.do_container:shown(false)
			self.old_hidden = true
		end
	else
		self.old_hidden = false
		if self.old_turn ~= game.level.turn_counter or self.old_turn_max ~= game.level.max_turn_counter then
			self.do_container:shown(true)

			local c = game.level.turn_counter
			local m = math.max(game.level.max_turn_counter, c)
			local p = c / m
			self.sand:cutoff(0, self.sand_h * (1-p), self.sand_w, self.sand_h * p)

			self.text:text(("%d"):format(game.level.turn_counter / 10)):center()

			self.old_turn = game.level.turn_counter
			self.old_turn_max = game.level.max_turn_counter
		end
	end
end

function _M:getName()
	return "Hourglass"
end

function _M:getDefaultGeometry()
	local w = self.def_w
	local h = self.def_h
	local x = 256
	local y = 150
	return x, y, w, h
end
