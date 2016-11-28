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

local function generate_traps()
	local answers = {}
	local traps = 
	{	
	}

	local talent = player:getTalentFromId(player.T_TRAP_MASTERY)
	local lev = player:getTalentLevelRaw(talent)
	if lev >= 1 and not player:knowTalent(player.T_SPRINGRAZOR_TRAP) then traps[Talents.T_SPRINGRAZOR_PREP] = 1 end
	if lev >= 4 and not player:knowTalent(player.T_FLASH_BANG_TRAP) then traps[Talents.T_FLASH_BANG_PREP] = 1 end
	if game.state.poison_gas_trap == true and not player:knowTalent(player.T_POISON_GAS_TRAP) 
		then traps[Talents.T_POISON_GAS_PREP] = 1
	end
	if game.state.purging_trap == true and not player:knowTalent(player.T_PURGING_TRAP)
		then traps[Talents.T_PURGING_PREP] = 1 
	end
	if game.state.dragonsfire_trap == true and not player:knowTalent(player.T_DRAGONSFIRE_TRAP)
		then traps[Talents.T_DRAGONSFIRE_PREP] = 1 
	end
	if game.state.freezing_trap == true and not player:knowTalent(player.T_FREEZING_TRAP)
		then traps[Talents.T_FREEZING_PREP] = 1 
	end	
	
	if traps then
		for tid, level in pairs(traps) do
			local t = npc:getTalentFromId(tid)
			
			local doit = function(npc, player)
				if game.player:knowTalentType(t.type[1]) == nil then player:setTalentTypeMastery(t.type[1], 1.0) end
				player:learnTalent(tid, true, 1, {no_unlearn=true})
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
		answers[#answers+1] = {"Cancel"}
	end
	return answers
end

newChat{ id="welcome",
	text = [[Prepare which trap?]],
	answers = generate_traps(),
}

return "welcome"
