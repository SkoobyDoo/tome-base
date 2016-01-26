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

newChat{ id="welcome",
	text = [[Welcome @playername@ to my shop.]],
	answers = {
		{"Let me see your wares.", action=function(npc, player)
			npc.store:loadup(game.level, game.zone)
			npc.store:interact(player)
		end},
		{"I am looking for martial training.", jump="training"},
		{"I want to learn how to use tridents.", jump="tridents", cond=function(npc, player)
			if not player:knowTalentType("technique/combat-training") then return end
			return true
		end},
		{"I want to learn how to use tridents.", jump="tridents-false", cond=function(npc, player)
			if player:knowTalentType("technique/combat-training") then return end
			return true
		end},
		{"Sorry, I have to go!"},
	}
}

newChat{ id="training",
	text = [[I can indeed offer some martial training (talent category Technique/Combat-training) for a fee of 50 gold pieces; or the basic usage of bows and slings (Shoot talent) for 8 gold pieces.]],
	answers = {
		{"Please train me in generic weapons and armour usage.", action=function(npc, player)
			game.logPlayer(player, "The smith spends some time with you, teaching you the basics of armour and weapon usage.")
			player:incMoney(-50)
			player:learnTalentType("technique/combat-training", true)
			player.changed = true
		end, cond=function(npc, player)
			if player.money < 50 then return end
			if player:knowTalentType("technique/combat-training") then return end
			return true
		end},
		{"Please train me in the basic usage of bows and slings.", action=function(npc, player)
			game.logPlayer(player, "The smith spends some time with you, teaching you the basics of bows and slings.")
			player:incMoney(-8)
			player:learnTalent(player.T_SHOOT, true, nil, {no_unlearn=true})
			player.changed = true
		end, cond=function(npc, player)
			if player.money < 8 then return end
			if player:knowTalent(player.T_SHOOT) then return end
			return true
		end},
		{"No thanks."},
	}
}

newChat{ id="tridents",
	text = [[Well then you have come to the right place! I can teach you combat with one of these fine tridents for a fee of 100 gold pieces.]],
	answers = {
		{"Please train me in trident usage.", action = function(npc, player)
			game.logPlayer(player, "The smith spends some time with you, teaching you how to fight with tridents.")
			player:incMoney(-100)
			player:learnTalent(player.T_EXOTIC_WEAPONS_MASTERY, true, 1, {no_unlearn=true})
			player.__show_special_talents = player.__show_special_talents or {} player.__show_special_talents[player.T_EXOTIC_WEAPONS_MASTERY] = true
			player.changed=true
		end, cond=function(npc, player)
			if player.money < 100 then return end
			if player:knowTalent(player.T_EXOTIC_WEAPONS_MASTERY) then return end
			return true
		end},
		{"No thanks."},
	}
}

newChat{ id="tridents-false",
	text = [[I am sorry, but it would be hard to teach someone without any previous combat training. Perhaps I can help you with that?]],
	answers = {
		{"Yes, please.", jump="training"},
		{"No, thanks."},
	}
	
}

return "welcome"
