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

function _M:init(minimalist, w, h)
	self.full_container = core.renderer.container()
	self.do_container = core.renderer.renderer("static"):setRendererName("Hourglass MiniContainer")
	self.full_container:add(self.do_container)

	local shadow
	shadow, self.def_w, self.def_h = self:imageLoader("resources/hourglass_shadow.png")
	local front = self:imageLoader("resources/hourglass_front.png")
	self.bottom_t = self:texLoader("resources/hourglass_bottom.png")
	self.top_t = self:texLoader("resources/hourglass_top.png")

	self.fill_top = core.renderer.container()
	self.fill_bottom = core.renderer.container()

	self.do_container:add(shadow)
	self.do_container:add(self.fill_top)
	self.do_container:add(self.fill_bottom)
	self.do_container:add(front)

	MiniContainer.init(self, minimalist)

	self.mouse:registerZone(0, 0, self.w, self.h, self:tooltipAll(function(button, mx, my, xrel, yrel, bx, by, event)
		-- DGDGDGDG: handle tooltip from game.level.turn_counter_desc
	end, ""))

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
			self.fill_bottom:clear()
			self.fill_top:clear()

			local c = game.level.turn_counter
			local m = math.max(game.level.max_turn_counter, c)
			local p = c / m
			if p >= 0.5 then
				self.fill_bottom:add(core.renderer.fromTextureTableCut(self.top_t, 11, 32, nil, nil, 1-(p-0.5)*2, 1))
				self.fill_bottom:add(core.renderer.fromTextureTable(self.bottom_t, 12, 72))
			else
				self.fill_bottom:add(core.renderer.fromTextureTableCut(self.bottom_t, 12, 72, nil, nil, 1-(p)*2, 1))
				-- self.fill_bottom:add(core.renderer.fromTextureTableCut(self.bottom_t, 12, 72 + (self.bottom_t.h * (1-p*2)), self.bottom_t.w+0.001, self.bottom_t.h * p*2))
			end

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
