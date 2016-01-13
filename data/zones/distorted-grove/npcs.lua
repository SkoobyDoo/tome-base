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

local Talents = require("engine.interface.ActorTalents")

-- change the local wildlife
local alter = function(add)
	add = add or 0
	return function(e)
		if e.rarity then
			local list = {"T_DIMENSIONAL_STEP", "T_REALITY_SMEARING"}
			e[#e+1] = resolvers.talents{[ Talents[rng.table(list)] ] = {base=1, every=5, max=5}}
			e.rarity = math.ceil(e.rarity + add)
			e.not_power_source = {nature=true}
			e.desc = "It appears to be a " .. e.name .. ", but that doesn't explain why it continuously flickers in and out of existence." 
			e.name = "distorted ".. e.name
		end
	end
end


load("/data/general/npcs/rodent.lua", alter(1))
load("/data/general/npcs/bear.lua", alter(1))
load("/data/general/npcs/canine.lua", alter(1))
load("/data/general/npcs/plant.lua", alter(1))

-- Insert boss here


