-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2014 Nicolas Casalini
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

-- load("/data/general/npcs/skeleton.lua", rarity(0))


local Talents = require("engine.interface.ActorTalents")

newEntity{
	define_as = "BASE_NPC_OGRE",
	type = "giant", subtype = "ogre",
	display = "O", color=colors.WHITE,
	body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1, QUIVER=1 },

	rank = 2,
	size_category = 4,
	infravision = 10,
	
	resolvers.racial(),

	autolevel = "warriormage",
	ai = "dumb_talented_simple", ai_state = { ai_move="move_complex", talent_in=2, },
	stats = { str=14, mag=14, con=14 },
	combat = { dammod={str=1, mag=0.5}},
	combat_armor = 8, combat_def = 6,
	not_power_source = {antimagic=true},

	on_added_to_level = function(self)
		self:setEffect(self.EFF_AEONS_STASIS, 1, {})
	end,
}

newEntity{ base = "BASE_NPC_OGRE",
	name = "yeti cub", color=colors.LIGHT_GREY,
	desc = [[This humanoid form is coated with a thick white fur.]],
	level_range = {1, nil}, exp_worth = 1,
	rarity = 2,
	rank = 1,
	max_life = resolvers.rngavg(40,70), life_rating = 8,
	combat_armor = 1, combat_def = 3,
	combat = { dam=resolvers.levelup(5, 1, 0.7), atk=0, apr=3 },
}
