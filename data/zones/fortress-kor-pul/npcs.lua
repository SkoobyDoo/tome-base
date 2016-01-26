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

-- Kor'pul is alive and well and has lots of undead minions
	load("/data/general/npcs/rodent.lua", rarity(0))
	load("/data/general/npcs/vermin.lua", rarity(2))
	load("/data/general/npcs/molds.lua", rarity(1))
	load("/data/general/npcs/skeleton.lua", rarity(0))
	load("/data/general/npcs/snake.lua", rarity(2))
	load("/data/general/npcs/ghoul.lua", rarity(1))
	load("/data/general/npcs/wight.lua", rarity(3))
	load("/data/general/npcs/ghost.lua", rarity(3))

local Talents = require("engine.interface.ActorTalents")

newEntity{ define_as = "KORPUL",
	type = "humanoid", subtype = "human", image = "npc/the_master.png",
	name = "Kor'pul",
	display = "s", color=colors.DARK_GREY,
	shader = "unique_glow",
	desc = [[The grandmaster of necromancy, the great Kor'pul!]],
	killer_message = "and reanimated as a lowly ghoul",
	level_range = {10 , nil},
	exp_worth = 2,
	max_life=300, life_rating = 10, fixed_rating = true,
	max_mana = 120,
	rank = 4,
	size_category = 2,
	lite = 2,
	open_door = true,
	soul_regen = 1,
	
	body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1},

	autolevel = "caster",
	ai = "dumb_talented_simple", ai_state = { ai_move="move_complex", talent_in=1, },
	stats = { str=7, dex=10, mag=25, con=10 },

	equipment = resolvers.equip{ 
		{type="weapon", subtype="staff", forbid_power_source={antimagic=true}, autoreq=true},
		{type="armor", subtype="cloth", forbid_power_source={antimagic=true}, autoreq=true},
	},
	
	resolvers.drops{chance=100, nb=5, {tome_drops="boss"} },
	
-- 	talent_cd_reduction = {[Talents.T_CREATE_MINIONS] = 1,},
		
	resolvers.sustains_at_birth(),
	
	resolvers.talents{
		[Talents.T_AURA_MASTERY] = {base=1, every=3, max=10},
		[Talents.T_CREATE_MINIONS]={base=3, every=5, max=10},
		[Talents.T_RIGOR_MORTIS]={base=1, every=5, max=5},
		[Talents.T_CIRCLE_OF_DEATH]={base=0, every=5, max=5},
		[Talents.T_SURGE_OF_UNDEATH]={base=1, every=5, max=5},
	},
	
	summon = {
		{type="undead", number=2, hasxp=false},
	},
}