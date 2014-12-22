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
	name = "ogre guard", color=colors.LIGHT_GREY,
	desc = [[WRITE ME]],
	level_range = {1, nil}, exp_worth = 1,
	rarity = 2,
	rank = 2,
	max_life = resolvers.rngavg(110,120), life_rating = 14,
}

newEntity{ base = "BASE_NPC_OGRE",
	name = "ogre warmaster", color=colors.LIGHT_GREY,
	desc = [[WRITE ME]],
	level_range = {1, nil}, exp_worth = 1,
	rarity = 2,
	rank = 2,
	max_life = resolvers.rngavg(110,120), life_rating = 14,
}

newEntity{ base = "BASE_NPC_OGRE",
	name = "ogre mauler", color=colors.LIGHT_GREY,
	desc = [[WRITE ME]],
	level_range = {1, nil}, exp_worth = 1,
	rarity = 2,
	rank = 2,
	max_life = resolvers.rngavg(110,120), life_rating = 14,
}

newEntity{ base = "BASE_NPC_OGRE",
	name = "ogre pounder", color=colors.LIGHT_GREY,
	desc = [[WRITE ME]],
	level_range = {1, nil}, exp_worth = 1,
	rarity = 2,
	rank = 2,
	max_life = resolvers.rngavg(110,120), life_rating = 14,
}

newEntity{ base = "BASE_NPC_OGRE",
	name = "degenerated ogre", color=colors.LIGHT_GREY,
	desc = [[WRITE ME]],
	level_range = {1, nil}, exp_worth = 1,
	rarity = 2,
	rank = 2,
	max_life = resolvers.rngavg(110,120), life_rating = 14,
}

newEntity{ base = "BASE_NPC_OGRE",
	name = "ogric abomination", color=colors.LIGHT_GREY,
	desc = [[WRITE ME]],
	level_range = {1, nil}, exp_worth = 1,
	rarity = 2,
	rank = 2,
	max_life = resolvers.rngavg(110,120), life_rating = 14,
}

newEntity{ base = "BASE_NPC_OGRE",
	name = "ogre rune-spinner", color=colors.LIGHT_GREY,
	desc = [[WRITE ME]],
	level_range = {1, nil}, exp_worth = 1,
	rarity = 2,
	rank = 2,
	max_life = resolvers.rngavg(110,120), life_rating = 14,
}

newEntity{ base = "BASE_NPC_OGRE", define_as = "OGRE_SENTRY",
	name = "ogre sentry", color=colors.LIGHT_GREY,
	desc = [[WRITE ME]],
	level_range = {1, nil}, exp_worth = 1,
	rarity = 2,
	rank = 2,
	max_life = resolvers.rngavg(110,120), life_rating = 14,
	seen_by = function(self, who)
		if not game.party:hasMember(who) then return end
		self.seen_by = nil
		self:removeEffect(self.EFF_AEONS_STASIS, nil, true)
	end,
}

newEntity{ base = "OGRE_SENTRY", define_as = "OGRE_SENTRY2",
	seen_by = function(self, who)
		if not game.party:hasMember(who) then return end
		self.seen_by = nil
		self:removeEffect(self.EFF_AEONS_STASIS, nil, true)

		local Chat = require "engine.Chat"
		local chat = Chat.new("conclave-vault-greeting", self, who)
		chat:invoke()
	end,
}
