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

	--populate the tool list, also apply a temp value so talents display correctly
	if not player.artifice_hidden_blades then 
		tools[Talents.T_HIDDEN_BLADES] = 1
		player.artifice_hidden_blades = slot
	end
	if not player.artifice_smokescreen then 
		tools[Talents.T_SMOKESCREEN] = 1
		player.artifice_smokescreen = slot
	end
	if not player.artifice_rogue_s_brew then 
		tools[Talents.T_ROGUE_S_BREW] = 1
		player.artifice_rogue_s_brew = slot
	end
	if not player.artifice_dart_launcher then 
		tools[Talents.T_DART_LAUNCHER] = 1
		player.artifice_dart_launcher = slot
	end
	
	if tools then
		for tid, level in pairs(tools) do
			local t = npc:getTalentFromId(tid)
			level = math.min(t.points - game.player:getTalentLevelRaw(tid), level)
			
			local doit = function(npc, player)
				if game.player:knowTalentType(t.type[1]) == nil then player:setTalentTypeMastery(t.type[1], 1.0) end
				player:learnTalent(tid, true, level, {no_unlearn=true})
				--remove the temp values set earlier
				if not (t.name=="Hidden Blades" or player:knowTalent(player.T_HIDDEN_BLADES)) then player.artifice_hidden_blades = null end
				if not (t.name=="Smokescreen" or player:knowTalent(player.T_SMOKESCREEN)) then player.artifice_smokescreen = null end
				if not (t.name=="Rogue's Brew" or player:knowTalent(player.T_ROGUE_S_BREW)) then player.artifice_rogue_s_brew = null end
				if not (t.name=="Dart Launcher" or player:knowTalent(player.T_DART_LAUNCHER)) then player.artifice_dart_launcher = null end
				player:startTalentCooldown(tid)
			end
			answers[#answers+1] = {("[Equip %s]"):format(t.name),
				action=doit,
				on_select=function(npc, player)
					local mastery = nil
					if player:knowTalentType(t.type[1]) == nil then mastery = 1.0 end
					game.tooltip_x, game.tooltip_y = 1, 1
					game:tooltipDisplayAtMap(game.w, game.h, "#GOLD#"..t.name.."#LAST#\n"..tostring(player:getTalentFullDescription(t, 1, nil, mastery)))
				end,
			}
		end

	end
	return answers
end

newChat{ id="welcome",
	text = [[Equip which tools?]],
	answers = generate_tools(),
}

return "welcome"
