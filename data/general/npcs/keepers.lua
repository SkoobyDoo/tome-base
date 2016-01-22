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

newEntity{ define_as = "AKHO", 
	type = "humanoid", subtype = "human",
	display = "p", color=colors.PURPLE,
	faction = "keepers-of-reality",
	name = "Commander Akho",
	image = "npc/humanoid_elf_star_crusader.png", -- replace with custom tile later
	desc = [[A woman clad in dark mail armour, a great bow in her hands. She looks very young, but you have a feeling that she is much, much older.]],
	
	level_range = {50, nil}, exp_worth = 1,
	rarity = false,
	max_life = 1000, life_rating = 15, fixed_rating = true,
	life_regen = 50,
	paradox_regen = -10,
	cant_be_moved = 1,
	
	rank = 4,
	size_category = 3,
	female = true,
	infravision = 10,
	stats = { str=10, dex=10, cun=12, mag=16, con=14 },
	instakill_immune = 1,
	teleport_immune = 1,

	can_talk = "akho",
	
	ai = "tactical", ai_state = { talent_in=1, ai_move="move_astar", },
	ai_tactic = resolvers.tactic"ranged",
	resolvers.inscriptions(5, {}),
	resolvers.inscriptions(1, "rune"),
	
	body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1, QUIVER=1 },
	resolvers.drops{chance=100, nb=5, {tome_drops="boss"} },
	
	resolvers.equip{
		{type="weapon", subtype="bow", forbid_power_source={antimagic=true}, autoreq=true},
		{type="armor", subtype="heavy", forbid_power_source={antimagic=true}, autoreq=true},
		{type="ammo", subtype="arrows", forbid_power_source={antimagic=true}, autoreq=true},
	},
	
	resolvers.talents{
		[Talents.T_FORESIGHT]=5,
		[Talents.T_PRECOGNITION]=5,
		
		[Talents.T_WEAPON_FOLDING]=5,
		[Talents.T_INVIGORATE]=5,
		[Talents.T_WEAPON_MANIFOLD]=5,
		[Talents.T_BREACH]=5,
		
		[Talents.T_STRENGTH_OF_PURPOSE]=5,
		[Talents.T_VIGILANCE]=5,
		
		[Talents.T_SPACETIME_STABILITY]=5,
		[Talents.T_TIME_SHIELD]=5,
	
		[Talents.T_TIME_STOP]=5,
	},

	resolvers.sustains_at_birth(),

}