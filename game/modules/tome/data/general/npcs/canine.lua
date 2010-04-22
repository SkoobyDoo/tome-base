-- ToME - Tales of Middle-Earth
-- Copyright (C) 2009, 2010 Nicolas Casalini
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

-- last updated:  5:11 PM 1/29/2010

local Talents = require("engine.interface.ActorTalents")

newEntity{
	define_as = "BASE_NPC_CANINE",
	type = "animal", subtype = "canine",
	display = "C", color=colors.WHITE,
	body = { INVEN = 10 },

	max_stamina = 150,
	rank = 1,
	size_category = 2,

	autolevel = "warrior",
	ai = "dumb_talented_simple", ai_state = { talent_in=10, },
	energy = { mod=1.1 },
	stats = { str=10, dex=17, mag=3, con=7 },
	combat_armor = 1, combat_def = 1,
}

newEntity{ base = "BASE_NPC_CANINE",
	name = "wolf", color=colors.UMBER,
	desc = [[Lean, mean and shaggy, it stares at you with hungry eyes.]],
	level_range = {1, 50}, exp_worth = 1,
	rarity = 4,
	max_life = resolvers.rngavg(40,70),
	combat_armor = 1, combat_def = 3,
	combat = { dam=5, atk=15, apr=3 },
}

newEntity{ base = "BASE_NPC_CANINE",
	name = "great wolf", color=colors.UMBER,
	desc = [[Larger than a normal wolf, it prowls and snaps at you.]],
	level_range = {3, 50}, exp_worth = 1,
	rarity = 6,
	max_life = resolvers.rngavg(60,90),
	combat_armor =2, combat_def = 4,
	combat = { dam=6, atk=15, apr=3 },
}

newEntity{ base = "BASE_NPC_CANINE",
	name = "dire wolf", color=colors.DARK_UMBER,
	desc = [[Easily as big as a horse, this wolf menaces you with its claws and fangs.]],
	level_range = {4, 50}, exp_worth = 1,
	rarity = 7,
	max_life = resolvers.rngavg(80,110),
	combat_armor = 3, combat_def = 5,
	combat = { dam=9, atk=15, apr=4 },
}

newEntity{ base = "BASE_NPC_CANINE",
	name = "white wolf", color=colors.WHITE,
	desc = [[A large and muscled wolf from the northern wastes. Its breath is cold and icy and its fur coated in frost.]],
	level_range = {4, 50}, exp_worth = 1,
	rarity = 7,
	max_life = resolvers.rngavg(70,100),
	combat_armor = 3, combat_def = 4,
	combat = { dam=8, atk=15, apr=3 },

	resists = { [DamageType.FIRE] = -50, [DamageType.COLD] = 100 },
}

newEntity{ base = "BASE_NPC_CANINE",
	name = "warg", color=colors.BLACK,
	desc = [[It is a large wolf with eyes full of cunning.]],
	level_range = {6, 50}, exp_worth = 1,
	rarity = 7,
	max_life = resolvers.rngavg(60,100),
	combat_armor = 5, combat_def = 7,
	combat = { dam=10, atk=17, apr=5 },
}

newEntity{ base = "BASE_NPC_CANINE",
	name = "fox", color=colors.RED,
	desc = [[The quick brown fox jumps over the lazy dog.]],
	level_range = {1, 50}, exp_worth = 1,
	rarity = 5,
	max_life = resolvers.rngavg(40,50),
	combat_armor = 1, combat_def = 3,
	combat = { dam=4, atk=10, apr=3 },
}
