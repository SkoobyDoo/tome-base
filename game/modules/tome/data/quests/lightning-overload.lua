-- ToME - Tales of Maj'Eyal
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

name = "Storming the city"
desc = function(self, who)
	local desc = {}
	desc[#desc+1] = "As you came to Derth you saw a huge dark cloud over the small town."
	desc[#desc+1] = "When you entered you were greeted by an army of air elementals slaughtering the population."
	if self:isCompleted("saved-derth") then
		desc[#desc+1] = " * You have dispatched the elementals but the cloud lingers still. You must find a powerful ally to remove it. There are rumours of a secret town in the blue mountains, to the southwest. You could also check out the Ziguranth group that is supposed to fight magic."
	end
	if self:isCompleted("tempest-located") then
		desc[#desc+1] = " * You have learned the real threat comes from a rogue Archmage, a Tempest named Urkis. The mages of Angolwen are ready to teleport you there."
	end
	if self:isCompleted("tempest-entrance") then
		desc[#desc+1] = " * You have learned the real threat comes from a rogue Archmage, a Tempest. You have been shown a secret entrance to his stronghold."
	end

	return table.concat(desc, "\n")
end

on_grant = function(self, who)
	-- Darken the level
	game.level.map:setShown(0.3, 0.3, 0.3, 1)
	game.level.map:setObscure(0.3*0.6, 0.3*0.6, 0.3*0.6, 0.6)
	game.level.level = util.bound(game.player.level, 12, 20)

	-- Add random lightning firing off
	game.level.data.background = function(level)
		local Map = require "engine.Map"
		if rng.chance(30) then
			local x1, y1 = rng.range(10, level.map.w - 11), rng.range(10, level.map.h - 11)
			local x2, y2 = x1 + rng.range(-4, 4), y1 + rng.range(5, 10)
			level.map:particleEmitter(x1, y1, math.max(math.abs(x2-x1), math.abs(y2-y1)), "lightning", {tx=x2-x1, ty=y2-y1})
			game:playSoundNear({x=x1,y=y1}, "talents/thunderstorm")
		end
	end

	-- Populate with nice air elementals
	self.max_count = 0
	for i = 1, 12 do
		local m = game.zone:makeEntity(game.level, "actor", {special_rarity="derth_rarity"}, nil, true)
		local spot = game.level:pickSpot{type="npc", subtype="elemental"}
		if m and spot then
			m.quest = true
			m.on_die = function(self)
				game.player:resolveSource():hasQuest("lightning-overload"):kill_one()
			end
			game.zone:addEntity(game.level, m, "actor", spot.x, spot.y)
			self.max_count = self.max_count + 1
		end
	end
	self.kill_count = 0

	require("engine.ui.Dialog"):simpleLongPopup("Danger...", "As you arrive in Derth you notice a huge dark cloud hovering over the town.\nYou hear screams coming from the central place.", 400)
end

on_status_change = function(self, who, status, sub)
	if self:isCompleted() then
		who:setQuestStatus(self.id, engine.Quest.DONE)
		game:setAllowedBuild("mage_tempest", true)
		world:gainAchievement("EYE_OF_THE_STORM", game.player:resolveSource())
	end
end

kill_one = function(self)
	self.kill_count = self.kill_count + 1

	if self.kill_count >= self.max_count then
		local Chat = require "engine.Chat"
		local chat = Chat.new("derth-attack-over", {name="Scared Halfling"}, game.player)
		chat:invoke()
	end
end

done_derth = function(self)
	game.player:setQuestStatus(self.id, engine.Quest.COMPLETED, "saved-derth")
end

teleport_urkis = function(self)
	game:changeLevel(1, "tempest-peak")
	require("engine.ui.Dialog"):simpleLongPopup("Danger...", [[You step out on unfamiliar grounds. You are nearly on top of one of the highest peaks you can see.
The storm is raging above your head.]], 400)
end

create_entrance = function(self)
	local p = mod.class.Grid.new{
		show_tooltip=true, always_remember = true,
		name="Long road to the Tempest Peak",
		display='>', color=colors.WHITE,
		notice = true,
		change_level=1, change_zone="tempest-peak",
		change_level_check = function()
			game.turn = game.turn + 5 * game.calendar.HOUR
			if not game.player:hasQuest("lightning-overload").walked then
				require("engine.ui.Dialog"):simpleLongPopup("Danger...", [[After an hours long walk you finally reach the end of the way. You are nearly on top of one of the highest peaks you can see.
The storm is raging above your head.]], 400)
				game.player:hasQuest("lightning-overload").walked = true
			end
		end
	}
	p:resolve() p:resolve(nil, true)
	local level = game.memory_levels["wilderness-1"]
	local spot = level:pickSpot{type="zone-pop", subtype="tempest-peak"}
	game.zone:addEntity(level, p, "terrain", spot.x, spot.y)
	game.player:setQuestStatus(self.id, engine.Quest.COMPLETED, "tempest-entrance")
end

reenter_derth = function(self)
	if (self:isCompleted() or self:isEnded()) and not self:isCompleted("restored-derth") then
		game.level.map:setShown(1, 1, 1, 1)
		game.level.map:setObscure(1*0.6, 1*0.6, 1*0.6, 1)
		game.level.data.background = nil

		game.player:setQuestStatus(self.id, engine.Quest.COMPLETED, "restored-derth")
		require("engine.ui.Dialog"):simpleLongPopup("Clear sky", "It seems the mages have kept their word.\nDerth is free of the storm cloud.", 400)
	end
end
