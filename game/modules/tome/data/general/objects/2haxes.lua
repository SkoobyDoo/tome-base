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

newEntity{
	define_as = "BASE_BATTLEAXE",
	slot = "MAINHAND",
	slot_forbid = "OFFHAND",
	type = "weapon", subtype="battleaxe",
	add_name = " (#COMBAT#)",
	display = "/", color=colors.SLATE,
	encumber = 3,
	rarity = 5,
	combat = { talented = "axe", damrange = 1.5, sound = "actions/melee", sound_miss = "actions/melee_miss", },
	desc = [[Massive two-handed battleaxes.]],
	twohanded = true,
	egos = "/data/general/objects/egos/weapon.lua", egos_chance = resolvers.mbonus(40, 5),
}

newEntity{ base = "BASE_BATTLEAXE",
	name = "iron battleaxe",
	level_range = {1, 10},
	require = { stat = { str=11 }, },
	cost = 5,
	combat = {
		dam = resolvers.rngavg(6,12),
		apr = 1,
		physcrit = 4.5,
		dammod = {str=1.2},
	},
}

newEntity{ base = "BASE_BATTLEAXE",
	name = "steel battleaxe",
	level_range = {10, 20},
	require = { stat = { str=16 }, },
	cost = 10,
	combat = {
		dam = resolvers.rngavg(15,23),
		apr = 2,
		physcrit = 5,
		dammod = {str=1.2},
	},
}

newEntity{ base = "BASE_BATTLEAXE",
	name = "dwarven-steel battleaxe",
	level_range = {20, 30},
	require = { stat = { str=24 }, },
	cost = 15,
	combat = {
		dam = resolvers.rngavg(28,35),
		apr = 2,
		physcrit = 6.5,
		dammod = {str=1.2},
	},
}

newEntity{ base = "BASE_BATTLEAXE",
	name = "galvorn battleaxe",
	level_range = {30, 40},
	require = { stat = { str=35 }, },
	cost = 25,
	combat = {
		dam = resolvers.rngavg(40,48),
		apr = 3,
		physcrit = 7.5,
		dammod = {str=1.2},
	},
}

newEntity{ base = "BASE_BATTLEAXE",
	name = "mithril battleaxe",
	level_range = {40, 50},
	require = { stat = { str=48 }, },
	cost = 35,
	combat = {
		dam = resolvers.rngavg(54, 60),
		apr = 4,
		physcrit = 8,
		dammod = {str=1.2},
	},
}
