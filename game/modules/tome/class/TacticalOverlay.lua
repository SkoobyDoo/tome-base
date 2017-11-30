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
local Map = require "engine.Map"
local Tiles = require "engine.Tiles"
local Faction = require "engine.Faction"

module(..., package.seeall, class.make)

local BASE_W, BASE_H = 64, 64

local ichat

local boss_rank_circles = {
	[3.2] = { back="npc/boss_indicators/rare_circle_back.png", front="npc/boss_indicators/rare_circle_front.png" },
	[3.5] = { back="npc/boss_indicators/unique_circle_back.png", front="npc/boss_indicators/unique_circle_front.png" },
	[4]   = { back="npc/boss_indicators/boss_circle_back.png", front="npc/boss_indicators/boss_circle_front.png" },
	[5]   = { back="npc/boss_indicators/elite_boss_circle_back.png", front="npc/boss_indicators/elite_boss_circle_front.png" },
	[10]   = { back="npc/boss_indicators/god_circle_back.png", front="npc/boss_indicators/god_circle_front.png" },
}

function _M:setup(tactic_tiles)
	for rank, data in pairs(boss_rank_circles) do
		data.iback = tactic_tiles:get(nil, 0,0,0, 0,0,0, data.back)
		data.ifront = tactic_tiles:get(nil, 0,0,0, 0,0,0, data.front)
	end
	ichat = tactic_tiles:get(nil, 0,0,0, 0,0,0, "speak_bubble.png")
end

function _M:init()
	self.DO_rank_back = core.renderer.colorQuad(0, 0, 1, 1, 1, 1, 1, 1):shown(false)
	self.DO_rank_front = core.renderer.colorQuad(0, 0, 1, 1, 1, 1, 1, 1):shown(false)
	self.DO_chat = core.renderer.colorQuad(0, 0, 1, 1, 1, 1, 1, 1):texture(ichat):shown(false)

	self.DO_front = core.renderer.renderer():setRendererName("TacticalFront:UID:"..self.actor.uid)

	self.DO:add(self.DO_rank_back)
	self.DO_front:add(self.DO_rank_front)
	self.DO_front:add(self.DO_chat)
	self:update()
end

function _M:update()
	local w, h = Map.tile_w, Map.tile_h

	if self.actor.rank ~= self.old_rank then
		if boss_rank_circles[self.actor.rank or 1] then
			local b = boss_rank_circles[self.actor.rank]
			self.DO_rank_back:texture(b.iback):translate(0, h - w * 0.616):scale(w, w / 2, 1):shown(true)
			self.DO_rank_front:texture(b.ifront):translate(0, h - w * (0.616 - 0.5)):scale(w, w / 2, 1):shown(true)
		else
			self.DO_rank_back:shown(false)
			self.DO_rank_front:shown(false)
		end
	end
	self.old_rank = self.actor.rank

	-- Chat
	if self.actor.can_talk ~= self.old_talk then
		if self.actor.can_talk then
			self.DO_chat:translate(w - 8, 0):scale(8, 8):shown(true)
		else
			self.DO_chat:shown(false)
		end
	end
	self.old_talk = self.actor.can_talk
end
