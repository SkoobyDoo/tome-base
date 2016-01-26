-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2015 Nicolas Casalini
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
	define_as = "BASE_NPC_PORT_SEAFOAM",
	type = "humanoid", subtype = "nalore",
	display = "p", color=colors.WHITE,
	faction = "shalore",
	anger_emote = "Catch @himher@!",

	combat = { dam=resolvers.rngavg(1,2), atk=2, apr=0, dammod={str=0.4} },

	body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1, QUIVER=1 },
	lite = 3,

	life_rating = 10,
	rank = 2,
	size_category = 3,

	open_door = true,

	resolvers.racial(),
	resolvers.inscriptions(1, "rune"),

	autolevel = "warrior",
	ai = "dumb_talented_simple", ai_state = { ai_move="move_complex", talent_in=3, },
	stats = { str=8, dex=12, mag=6, con=10 },

}

newEntity{ base = "BASE_NPC_PORT_SEAFOAM",
	name = "naloren guard", color=colors.ROYAL_BLUE,
	image = "npc/naloren_guard.jpg",
	desc = [[A stern-looking guard, he will not let you disturb the town.]],
	level_range = {1, nil}, exp_worth = 1,
	rarity = 3,
	max_life = resolvers.rngavg(70,80),
	resolvers.equip{
		{type="weapon", subtype="trident", autoreq=true, force_drop=true, special_rarity="trident_rarity"},
		{type="armor", subtype="heavy", autoreq=true},
	},
	combat_armor = 4, combat_def = 0,
	resolvers.talents{ 
		[Talents.T_RUSH]=1, 
		[Talents.T_PERFECT_STRIKE]=1, 
		[Talents.T_ARMOUR_TRAINING]=1, 
	},
}