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

local class = require"engine.class"
local Birther = require "engine.Birther"
local PartyLore = require "mod.class.interface.PartyLore"
local ActorTemporaryEffects = require "engine.interface.ActorTemporaryEffects"

class:bindHook("ToME:load", function(self, data)
	Birther:loadDefinition("/data-atof/birth/worlds.lua")
	PartyLore:loadDefinition("/data-atof/lore/distorted-grove.lua")
	ActorTemporaryEffects:loadDefinition("/data-atof/timed_effects/time-floor.lua")

end)