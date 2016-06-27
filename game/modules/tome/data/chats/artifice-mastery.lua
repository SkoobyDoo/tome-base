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

local function generate_tools()
	local answers = {}
	local tools = 
	{	
	}
	
	if player:knowTalent(player.T_HIDDEN_BLADES) then tools[Talents.T_ASSASSINATE] = 1 end 
	if player:knowTalent(player.T_SMOKESCREEN) then tools[Talents.T_SMOKESCREEN_MASTERY] = 1 end 
	if player:knowTalent(player.T_ROGUE_S_BREW) then tools[Talents.T_ROGUE_S_BREW_MASTERY] = 1 end 
	if player:knowTalent(player.T_DART_LAUNCHER) then tools[Talents.T_DART_LAUNCHER_MASTERY] = 1 end 

	
	if tools then
		for tid, level in pairs(tools) do
			local t = npc:getTalentFromId(tid)
			level = math.min(t.points - game.player:getTalentLevelRaw(tid), level)
			
			local doit = function(npc, player)
				if game.player:knowTalentType(t.type[1]) == nil then player:setTalentTypeMastery(t.type[1], 1.0) end
				player:learnTalent(tid, true, level, {no_unlearn=true})
				player:startTalentCooldown(tid)
			end
			answers[#answers+1] = {("[%s]"):format(t.name),
				action=doit,
				on_select=function(npc, player)
					local mastery = nil
					if player:knowTalentType(t.type[1]) == nil then mastery = 1.0 end
					game.tooltip_x, game.tooltip_y = 1, 1
					game:tooltipDisplayAtMap(game.w, game.h, "#GOLD#"..t.name.."#LAST#\n"..tostring(player:getTalentFullDescription(t, 1, nil, mastery)))
				end,
			}
		end
		answers[#answers+1] = {"Cancel"}
	end
	return answers
end

newChat{ id="welcome",
	text = [[Master which tool?]],
	answers = generate_tools(),
}

return "welcome"
