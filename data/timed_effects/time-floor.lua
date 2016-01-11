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

-- Temporal Floor Effects

local Stats = require "engine.interface.ActorStats"
local Particles = require "engine.Particles"
local Entity = require "engine.Entity"
local Chat = require "engine.Chat"
local Map = require "engine.Map"
local Level = require "engine.Level"

local function floorEffect(t)
	t.name = t.name or t.desc
	t.name = t.name:upper():gsub("[ ']", "_")
	local d = t.long_desc
	if type(t.long_desc) == "string" then t.long_desc = function() return d end end
	t.type = "other"
	t.subtype = { floor=true }
	t.status = "neutral"
	t.parameters = {}
	t.on_gain = function(self, err) return nil, "+"..t.desc end
	t.on_lose = function(self, err) return nil, "-"..t.desc end

	newEffect(t)
end

floorEffect{
	desc = "Time Storm", image = "talents/shaloren_speed.png",
	long_desc = "The target is passing through a time storm. Increasing global speed by 100%.",
	activate = function(self, eff)
		self:effectTemporaryValue(eff, "global_speed_add", 1)
	end,
}

floorEffect{
	desc = "Time Calm", image = "talents/slow.png",
	long_desc = "The target is passing through a time calm. Decreasing global speed by 50%.",
	activate = function(self, eff)
		self:effectTemporaryValue(eff, "global_speed_add", -1)
	end,
}