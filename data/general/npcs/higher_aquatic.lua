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

newEntity{
	define_as = "BASE_NPC_HIGHER_AQUATIC_CRITTER",
	type = "aquatic", subtype = "critter",
	display = "A", color=colors.WHITE,
	body = { INVEN = 10 },
	autolevel = "warrior",
	ai = "dumb_talented_simple", ai_state = { ai_move="move_complex", talent_in=1, },
	stats = { str=15, dex=12, mag=3, con=15 },
	combat_armor = 1, combat_def = 1,
	combat = { dam=resolvers.levelup(resolvers.mbonus(36, 10), 1, 1), atk=25, apr=7, dammod={str=0.8} },
	max_life = resolvers.rngavg(20,30), life_rating = 9,
	infravision = 10,
	rank = 1,
	size_category = 2,
	can_breath={water=1},

	resists = { [DamageType.COLD] = 25, },
	not_power_source = {arcane=true, technique_ranged=true},
}

newEntity{ base = "BASE_NPC_HIGHER_AQUATIC_CRITTER",
	name = "shark", color = colors.LIGHT_SLATE, image = "npc/shark.png",
	desc = "A great shark, very fast and very hungry.",
	level_range = {10, nil}, exp_worth = 1,
	rank = 2,
	stats = { str=30, dex=20, mag=3, con=20 },
	resists = { [DamageType.PHYSICAL] = 20, },
	resolvers.talents{ [Talents.T_RUSH]=5, [Talents.T_LACERATING_STRIKES]=5},
	rarity = 2,
}

newEntity{ base = "BASE_NPC_HIGHER_AQUATIC_CRITTER",
	name = "crocodile", color = colors.DARK_GREEN, image = "npc/crocodile.png",
	desc = "A great crocodile, protected by hard scales and a jaw full of sharp teeth.",
	level_range = {10, nil}, exp_worth = 1,
	rank = 2,
	stats = { str=30, dex=20, mag=3, con=30 },
	resists = { [DamageType.PHYSICAL] = 20, },
	resolvers.talents{[Talents.T_LACERATING_STRIKES]=5},
	rarity = 2,
}