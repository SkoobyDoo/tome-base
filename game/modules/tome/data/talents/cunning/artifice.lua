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

local DamageType = require "engine.DamageType"
local Object = require "engine.Object"
local Map = require "engine.Map"
local Chat = require "engine.Chat"

newTalent{
	name = "Rogue's Tools",
	type = {"cunning/artifice", 1},
	points = 5,
	require = cuns_req_high1,
	cooldown = 10,
	no_npc_use = true,
	no_unlearn_last = true,
	on_learn = function(self, t)
		self:attr("show_gloves_combat", 1)
	end,
	on_unlearn = function(self, t)
		self:attr("show_gloves_combat", -1)
	end,
	getHBDamage = function (self, t) return self:combatTalentWeaponDamage(t, 1.0, 1.8) end,
	getRBDuration = function(self, t) return math.ceil(self:combatTalentScale(t, 4, 9)) end,
	getRBResist = function(self, t) return self:combatTalentLimit(t, 1, 0.17, 0.5) end,
	getRBRawHeal = function (self, t) return self:getTalentLevel(t) * 40 end,
	getRBMaxHeal = function (self, t) return self:combatTalentLimit(t, 0.4, 0.10, 0.25) end,
	getRBCure = function(self, t) return math.floor(self:combatTalentScale(t, 1, 3)) end,
	getSSDuration = function(self, t) return math.ceil(self:combatTalentScale(t, 3, 5)) end,
	getSSSightLoss = function(self, t) return math.floor(self:combatTalentScale(t,1, 6, "log", 0, 4)) end, -- 1@1 6@5
	getDLDamage = function(self, t) return 15 + self:combatTalentStatDamage(t, "cun", 12, 150) end,
	getDLSleepPower = function(self, t) return 15 + self:combatTalentStatDamage(t, "cun", 15, 180) end,
	action = function(self, t)
		if self.artifice_hidden_blades==1 then 
			self:unlearnTalent(self.T_HIDDEN_BLADES)
			self.artifice_hidden_blades = null
			if self:knowTalent(self.T_ASSASSINATE) then self:unlearnTalent(self.T_ASSASSINATE) end
		end
		if self.artifice_smokescreen==1 then 
			self:unlearnTalent(self.T_SMOKESCREEN)
			self.artifice_smokescreen = null
			if self:knowTalent(self.T_SMOKESCREEN_MASTERY) then self:unlearnTalent(self.T_SMOKESCREEN_MASTERY) end
		end		
		if self.artifice_rogue_s_brew==1 then 
			self:unlearnTalent(self.T_ROGUE_S_BREW)
			self.artifice_rogue_s_brew = null
			if self:knowTalent(self.T_ROGUE_S_BREW_MASTERY) then self:unlearnTalent(self.T_ROGUE_S_BREW_MASTERY) end
		end		
		if self.artifice_dart_launcher==1 then 
			self:unlearnTalent(self.T_DART_LAUNCHER)
			self.artifice_dart_launcher = null
			if self:knowTalent(self.T_DART_LAUNCHER_MASTERY) then self:unlearnTalent(self.T_DART_LAUNCHER_MASTERY) end
		end
		
		local chat = Chat.new("artifice", self, self, {player=self, slot=1})
		self:talentDialog(chat:invoke())
		return true
	end,
	info = function(self, t)
		local tool = ""
		if self:knowTalent(self.T_HIDDEN_BLADES) and self.artifice_hidden_blades==1 then
			tool = ([[#YELLOW#Current Tool: Hidden Blades]]):format()
		elseif self:knowTalent(self.T_SMOKESCREEN) and self.artifice_smokescreen==1 then
			tool = ([[#YELLOW#Current Tool: Smokescreen]]):format()
		elseif self:knowTalent(self.T_ROGUE_S_BREW) and self.artifice_rogue_s_brew==1 then
			tool = ([[#YELLOW#Current Tool: Rogue's Brew]]):format()
		elseif self:knowTalent(self.T_DART_LAUNCHER) and self.artifice_dart_launcher==1 then
			tool = ([[#YELLOW#Current Tool: Dart Launcher]]):format()
		end
		return ([[You learn to create and equip a number of useful tools:
Hidden Blades. Melee criticals inflict %d%% bonus unarmed damage. 4 turn cooldown.
Smokescreen. Throw a vial of smoke that blocks vision in radius 2 for %d turns, and reduces the vision of enemies within by %d. 15 turn cooldown.
Rogue’s Brew. Drink a potion that restores %d life (+%d%% of maximum), %d stamina (+%d%% of maximum) and cures %d negative physical effects. 20 turn cooldown.
Dart Launcher. Fires a dart that deals %0.2f physical damage and puts the target to sleep for 4 turns. 10 turn cooldown.
You can equip a single tool at first.
%s]]):
format(t.getHBDamage(self,t)*100, t.getSSDuration(self,t), t.getSSSightLoss(self,t), t.getRBRawHeal(self,t), t.getRBMaxHeal(self,t)*100, t.getRBRawHeal(self,t)/4, t.getRBMaxHeal(self,t)*40, t.getRBCure(self,t), damDesc(self, DamageType.PHYSICAL, t.getDLDamage(self,t)), tool)
	end,
}

newTalent{
	name = "Cunning Tools",
	type = {"cunning/artifice", 2},
	points = 5,
	require = cuns_req_high2,
	cooldown = 10,
	no_npc_use = true,
	no_unlearn_last = true,
	getHBDamage = function (self, t) return self:combatTalentWeaponDamage(t, 1.0, 1.8) end,
	getRBDuration = function(self, t) return math.ceil(self:combatTalentScale(t, 4, 9)) end,
	getRBResist = function(self, t) return self:combatTalentLimit(t, 1, 0.17, 0.5) end,
	getRBRawHeal = function (self, t) return self:getTalentLevel(t) * 40 end,
	getRBMaxHeal = function (self, t) return self:combatTalentLimit(t, 0.4, 0.10, 0.25) end,
	getRBCure = function(self, t) return math.floor(self:combatTalentScale(t, 1, 3)) end,
	getSSDuration = function(self, t) return math.ceil(self:combatTalentScale(t, 3, 5)) end,
	getSSSightLoss = function(self, t) return math.floor(self:combatTalentScale(t,1, 6, "log", 0, 4)) end, -- 1@1 6@5
	getDLDamage = function(self, t) return 15 + self:combatTalentStatDamage(t, "cun", 12, 150) end,
	getDLSleepPower = function(self, t) return 15 + self:combatTalentStatDamage(t, "cun", 15, 180) end,
	action = function(self, t)
		if self.artifice_hidden_blades==2 then 
			self:unlearnTalent(self.T_HIDDEN_BLADES)
			self.artifice_hidden_blades = null
			if self:knowTalent(self.T_ASSASSINATE) then self:unlearnTalent(self.T_ASSASSINATE) end
		end
		if self.artifice_smokescreen==2 then 
			self:unlearnTalent(self.T_SMOKESCREEN)
			self.artifice_smokescreen = null
			if self:knowTalent(self.T_SMOKESCREEN_MASTERY) then self:unlearnTalent(self.T_SMOKESCREEN_MASTERY) end
		end		
		if self.artifice_rogue_s_brew==2 then 
			self:unlearnTalent(self.T_ROGUE_S_BREW)
			self.artifice_rogue_s_brew = null
			if self:knowTalent(self.T_ROGUE_S_BREW_MASTERY) then self:unlearnTalent(self.T_ROGUE_S_BREW_MASTERY) end
		end		
		if self.artifice_dart_launcher==2 then 
			self:unlearnTalent(self.T_DART_LAUNCHER)
			self.artifice_dart_launcher = null
			if self:knowTalent(self.T_DART_LAUNCHER_MASTERY) then self:unlearnTalent(self.T_DART_LAUNCHER_MASTERY) end
		end

		local chat = Chat.new("artifice", self, self, {player=self, slot=2})
		self:talentDialog(chat:invoke())
		return true
	end,
	info = function(self, t)
		local tool = ""
		if self:knowTalent(self.T_HIDDEN_BLADES) and self.artifice_hidden_blades==2 then
			tool = ([[#YELLOW#Current Tool: Hidden Blades]]):format()
		elseif self:knowTalent(self.T_SMOKESCREEN) and self.artifice_smokescreen==2 then
			tool = ([[#YELLOW#Current Tool: Smokescreen]]):format()
		elseif self:knowTalent(self.T_ROGUE_S_BREW) and self.artifice_rogue_s_brew==2 then
			tool = ([[#YELLOW#Current Tool: Rogue's Brew]]):format()
		elseif self:knowTalent(self.T_DART_LAUNCHER) and self.artifice_dart_launcher==2 then
			tool = ([[#YELLOW#Current Tool: Dart Launcher]]):format()
		end
		return ([[You learn to equip a second tool:
Hidden Blades. Melee criticals inflict %d%% bonus unarmed damage. 4 turn cooldown.
Smokescreen. Throw a vial of smoke that blocks vision in radius 2 for %d turns, and reduces the vision of enemies within by %d. 15 turn cooldown.
Rogue’s Brew. Drink a potion that restores %d life (+%d%% of maximum), %d stamina (+%d%% of maximum) and cures %d negative physical effects. 20 turn cooldown.
Dart Launcher. Fires a dart that deals %0.2f physical damage and puts the target to sleep for 4 turns. 10 turn cooldown.
%s]]):
format(t.getHBDamage(self,t)*100, t.getSSDuration(self,t), t.getSSSightLoss(self,t), t.getRBRawHeal(self,t), t.getRBMaxHeal(self,t)*100, t.getRBRawHeal(self,t)/4, t.getRBMaxHeal(self,t)*40, t.getRBCure(self,t), damDesc(self, DamageType.PHYSICAL, t.getDLDamage(self,t)), tool)
	end,
}


newTalent{
	name = "Intricate Tools",
	type = {"cunning/artifice", 3},
	require = cuns_req_high3,
	points = 5,
	cooldown = 10,
	no_npc_use = true,
	no_unlearn_last = true,
	getHBDamage = function (self, t) return self:combatTalentWeaponDamage(t, 1.0, 1.8) end,
	getRBDuration = function(self, t) return math.ceil(self:combatTalentScale(t, 4, 9)) end,
	getRBResist = function(self, t) return self:combatTalentLimit(t, 1, 0.17, 0.5) end,
	getRBRawHeal = function (self, t) return self:getTalentLevel(t) * 40 end,
	getRBMaxHeal = function (self, t) return self:combatTalentLimit(t, 0.4, 0.10, 0.25) end,
	getRBCure = function(self, t) return math.floor(self:combatTalentScale(t, 1, 3)) end,
	getSSDuration = function(self, t) return math.ceil(self:combatTalentScale(t, 3, 5)) end,
	getSSSightLoss = function(self, t) return math.floor(self:combatTalentScale(t,1, 6, "log", 0, 4)) end, -- 1@1 6@5
	getDLDamage = function(self, t) return 15 + self:combatTalentStatDamage(t, "cun", 12, 150) end,
	getDLSleepPower = function(self, t) return 15 + self:combatTalentStatDamage(t, "cun", 15, 180) end,
	action = function(self, t)
		if self.artifice_hidden_blades==3 then 
			self:unlearnTalent(self.T_HIDDEN_BLADES)
			self.artifice_hidden_blades = null
			if self:knowTalent(self.T_ASSASSINATE) then self:unlearnTalent(self.T_ASSASSINATE) end
		end
		if self.artifice_smokescreen==3 then 
			self:unlearnTalent(self.T_SMOKESCREEN)
			self.artifice_smokescreen = null
			if self:knowTalent(self.T_SMOKESCREEN_MASTERY) then self:unlearnTalent(self.T_SMOKESCREEN_MASTERY) end
		end		
		if self.artifice_rogue_s_brew==3 then 
			self:unlearnTalent(self.T_ROGUE_S_BREW)
			self.artifice_rogue_s_brew = null
			if self:knowTalent(self.T_ROGUE_S_BREW_MASTERY) then self:unlearnTalent(self.T_ROGUE_S_BREW_MASTERY) end
		end		
		if self.artifice_dart_launcher==3 then 
			self:unlearnTalent(self.T_DART_LAUNCHER)
			self.artifice_dart_launcher = null
			if self:knowTalent(self.T_DART_LAUNCHER_MASTERY) then self:unlearnTalent(self.T_DART_LAUNCHER_MASTERY) end
		end
		
		local chat = Chat.new("artifice", self, self, {player=self, slot=3})
		self:talentDialog(chat:invoke())
		return true
	end,
	info = function(self, t)
		local tool = ""
		if self:knowTalent(self.T_HIDDEN_BLADES) and self.artifice_hidden_blades==3 then
			tool = ([[#YELLOW#Current Tool: Hidden Blades]]):format()
		elseif self:knowTalent(self.T_SMOKESCREEN) and self.artifice_smokescreen==3 then
			tool = ([[#YELLOW#Current Tool: Smokescreen]]):format()
		elseif self:knowTalent(self.T_ROGUE_S_BREW) and self.artifice_rogue_s_brew==3 then
			tool = ([[#YELLOW#Current Tool: Rogue's Brew]]):format()
		elseif self:knowTalent(self.T_DART_LAUNCHER) and self.artifice_dart_launcher==3 then
			tool = ([[#YELLOW#Current Tool: Dart Launcher]]):format()
		end
		return ([[You learn to equip a third tool:
Hidden Blades. Melee criticals inflict %d%% bonus unarmed damage. 4 turn cooldown.
Smokescreen. Throw a vial of smoke that blocks vision in radius 2 for %d turns, and reduces the vision of enemies within by %d. 15 turn cooldown.
Rogue’s Brew. Drink a potion that restores %d life (+%d%% of maximum), %d stamina (+%d%% of maximum) and cures %d negative physical effects. 20 turn cooldown.
Dart Launcher. Fires a dart that deals %0.2f physical damage and puts the target to sleep for 4 turns. 10 turn cooldown.
%s]]):
format(t.getHBDamage(self,t)*100, t.getSSDuration(self,t), t.getSSSightLoss(self,t), t.getRBRawHeal(self,t), t.getRBMaxHeal(self,t)*100, t.getRBRawHeal(self,t)/4, t.getRBMaxHeal(self,t)*40, t.getRBCure(self,t), damDesc(self, DamageType.PHYSICAL, t.getDLDamage(self,t)), tool)
	end,
}

newTalent{
	name = "Master Artificer",
	type = {"cunning/artifice", 4},
	require = cuns_req_high4,
	points = 5,
	cooldown = 10,
	no_npc_use = true,
	no_unlearn_last = true,
	getAssassinateDamage = function (self, t) return self:combatTalentWeaponDamage(t, 1.8, 3.0) end,
	getBleed = function(self, t) return self:combatTalentScale(t, 0.2, 0.8) end,
    getSSDamage = function (self, t) return 30 + self:combatTalentStatDamage(t, "cun", 10, 150) end,
	getRBDieAt = function(self, t) return self:combatTalentScale(t, 100, 600) end,
    getDLSlow = function(self, t) return self:combatTalentLimit(t, 50, 15, 40)/100 end,
	action = function(self, t)
		if self:knowTalent(self.T_ASSASSINATE) then self:unlearnTalent(self.T_ASSASSINATE) end
		if self:knowTalent(self.T_SMOKESCREEN_MASTERY) then self:unlearnTalent(self.T_SMOKESCREEN_MASTERY) end
		if self:knowTalent(self.T_ROGUE_S_BREW_MASTERY) then self:unlearnTalent(self.T_ROGUE_S_BREW_MASTERY) end
		if self:knowTalent(self.T_DART_LAUNCHER_MASTERY) then self:unlearnTalent(self.T_DART_LAUNCHER_MASTERY) end
		
		local chat = Chat.new("artifice-mastery", self, self, {player=self})
		self:talentDialog(chat:invoke())
		return true
	end,
	info = function(self, t)
		local tool = ""
		if self:knowTalent(self.T_ASSASSINATE) then
			tool = ([[#YELLOW#Current Mastery: Hidden Blades]]):format()
		elseif self:knowTalent(self.T_SMOKESCREEN_MASTERY) then
			tool = ([[#YELLOW#Current Mastery: Smokescreen]]):format()
		elseif self:knowTalent(self.T_ROGUE_S_BREW_MASTERY) then
			tool = ([[#YELLOW#Current Mastery: Rogue's Brew]]):format()
		elseif self:knowTalent(self.T_DART_LAUNCHER_MASTERY) then
			tool = ([[#YELLOW#Current Mastery: Dart Launcher]]):format()
		end
		return ([[You reach the height of your craft, allowing you to focus on a single tool to greatly improve its capabilities:
Hidden Blades. Grants use of the Assassinate ability, striking twice with your hidden blades for %d%% unarmed damage as a guaranteed critical strike which ignores armor and resistances. Your Hidden Blades also inflict an additional %d%% damage as bleed.
Smokescreen: Infuses your Smokescreen with chokedust, causing %0.2f nature damage each turn to enemies inside as well as silencing them.
Rogue’s Brew. The brew strengthens you for 8 turns, preventing you from dying until you reach -%d life.
Dart Launcher. The sleeping poison becomes potent enough to ignore immunity, and on waking the target will be slowed by %d%% for 4 turns.
%s]]):
format(t.getAssassinateDamage(self,t)*100, t.getBleed(self,t)*100, damDesc(self, DamageType.NATURE, t.getSSDamage(self,t)), t.getRBDieAt(self,t), t.getDLSlow(self,t)*100, tool)
	end,
}

newTalent{
	name = "Hidden Blades",
	type = {"cunning/tools", 1},
	mode = "passive",
	points = 1,
	cooldown = 4,
	getDamage = function(self, t) 
		if self.artifice_hidden_blades == 1 then return self:callTalent(self.T_ROGUE_S_TOOLS, "getHBDamage") 
		elseif self.artifice_hidden_blades == 2 then return self:callTalent(self.T_CUNNING_TOOLS, "getHBDamage") 
		elseif self.artifice_hidden_blades == 3 then return self:callTalent(self.T_INTRICATE_TOOLS, "getHBDamage") 
		else return 0
		end
	end,
	callbackOnCrit = function(self, t, kind, dam, chance, target)
		if not target then return end
		if target.turn_procs.hb then return end
		if core.fov.distance(self.x, self.y, target.x, target.y) > 1 then return end
		if not self:isTalentCoolingDown(t) then
			target.turn_procs.hb = true
			local oldlife = target.life
			self:attackTarget(target, nil, t.getDamage(self,t), true, true)	

			if self:knowTalent(self.T_ASSASSINATE) then
				local scale = nil
				scale = self:callTalent(self.T_ASSASSINATE, "getBleed")	
				local life_diff = oldlife - target.life
				if life_diff > 0 and target:canBe('cut') and scale then
					target:setEffect(target.EFF_CUT, 5, {power=life_diff * scale / 5, src=self})
				end
			end
			self:startTalentCooldown(t)
		end	
	end,
	info = function(self, t)
		local dam = t.getDamage(self, t)
		return ([[You mount spring loaded blades on your wrists. On scoring a critical strike against an adjacent target, you follow up with your blades for %d%% unarmed damage.
This talent has a cooldown.]]):
		format(dam*100)
	end,
}

newTalent{
	name = "Rogue's Brew",
	type = {"cunning/tools", 1},
	points = 1,
	cooldown = 20,
	tactical = { BUFF = 2 },
	requires_target = true,
	getRawHeal = function(self, t) 
		if self.artifice_rogue_s_brew == 1 then return self:callTalent(self.T_ROGUE_S_TOOLS, "getRBRawHeal")
		elseif self.artifice_rogue_s_brew == 2 then return self:callTalent(self.T_CUNNING_TOOLS, "getRBRawHeal") 
		elseif self.artifice_rogue_s_brew == 3 then return self:callTalent(self.T_INTRICATE_TOOLS, "getRBRawHeal") 
		else return 0
		end
	end,
	getMaxHeal = function(self, t) 
		if self.artifice_rogue_s_brew == 1 then return self:callTalent(self.T_ROGUE_S_TOOLS, "getRBMaxHeal")
		elseif self.artifice_rogue_s_brew == 2 then return self:callTalent(self.T_CUNNING_TOOLS, "getRBMaxHeal") 
		elseif self.artifice_rogue_s_brew == 3 then return self:callTalent(self.T_INTRICATE_TOOLS, "getRBMaxHeal") 
		else return 0
		end
	end,
	getCure = function(self,t) 
		if self.artifice_rogue_s_brew == 1 then return self:callTalent(self.T_ROGUE_S_TOOLS, "getRBCure")
		elseif self.artifice_rogue_s_brew == 2 then return self:callTalent(self.T_CUNNING_TOOLS, "getRBCure") 
		elseif self.artifice_rogue_s_brew == 3 then return self:callTalent(self.T_INTRICATE_TOOLS, "getRBCure") 
		else return 0
		end
	end,
	getDieAt = function(self,t) return self:callTalent(self.T_MASTER_ARTIFICER, "getRBDieAt") end,
	action = function(self, t)
	
		local life = t.getRawHeal(self,t) + (t.getMaxHeal(self,t) * self.max_life)
		local sta = t.getRawHeal(self,t)/4 + (t.getMaxHeal(self,t) * self.max_stamina * 0.4)
		self:incStamina(sta)
		self:attr("allow_on_heal", 1)
		self:heal(life, self)
		self:attr("allow_on_heal", -1)
		
		local effs = {}
		-- Go through all temporary effects
		for eff_id, p in pairs(self.tmp) do
			local e = self.tempeffect_def[eff_id]
			if e.type == "physical" and e.status == "detrimental" then
				effs[#effs+1] = {"effect", eff_id}
			end
		end

		for i = 1, t.getCure(self, t) do
			if #effs == 0 then break end
			local eff = rng.tableRemove(effs)

			if eff[1] == "effect" then
				self:removeEffect(eff[2])
				known = true
			end
		end
		if known then
			game.logSeen(self, "%s is cured!", self.name:capitalize())
		end

		if self:knowTalent(self.T_ROGUE_S_BREW_MASTERY) then self:setEffect(self.EFF_ROGUE_S_BREW, 8, {power = t.getDieAt(self,t)}) end
				
		return true

	end,
	info = function(self, t)
	local heal = t.getRawHeal(self,t) + (t.getMaxHeal(self,t) * self.max_life)
	local sta = t.getRawHeal(self,t)/4 + (t.getMaxHeal(self,t) * self.max_stamina * 0.4)
	local cure = t.getCure(self,t)
		return ([[Imbibe a potent mixture of energizing and restorative substances, restoring %d life, %d stamina and curing %d negative physical effects.]]):
		format(heal, sta, cure)
   end,
}

newTalent{
	name = "Smokescreen",
	type = {"cunning/tools", 1},
	points = 1,
	cooldown = 15,
	stamina = 10,
	range = 6,
	direct_hit = true,
	tactical = { DISABLE = 2 },
	requires_target = true,
	radius = 2,
	getSightLoss = function(self, t) 
		if self.artifice_smokescreen == 1 then return self:callTalent(self.T_ROGUE_S_TOOLS, "getSSSightLoss")
		elseif self.artifice_smokescreen == 2 then return self:callTalent(self.T_CUNNING_TOOLS, "getSSSightLoss") 
		elseif self.artifice_smokescreen == 3 then return self:callTalent(self.T_INTRICATE_TOOLS, "getSSSightLoss") 
		else return 0
		end
	end,
	getDamage = function(self,t) 
		if self:knowTalent(self.T_SMOKESCREEN_MASTERY) then
			return self:callTalent(self.T_SMOKESCREEN_MASTERY, "getSSDamage")
		else
			return 0
		end
	end,
	getDuration = function(self, t)
		if self.artifice_smokescreen == 1 then return self:callTalent(self.T_ROGUE_S_TOOLS, "getSSDuration")
		elseif self.artifice_smokescreen == 2 then return self:callTalent(self.T_CUNNING_TOOLS, "getSSDuration") 
		elseif self.artifice_smokescreen == 3 then return self:callTalent(self.T_INTRICATE_TOOLS, "getSSDuration") 
		else return 0
		end
	end,
	action = function(self, t)
		local tg = {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), talent=t}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end

		self:project(tg, x, y, function(px, py)
			local e = Object.new{
				block_sight=true,
				temporary = t.getDuration(self, t),
				x = px, y = py,
				canAct = false,
				act = function(self)
					local t = self.summoner:getTalentFromId(self.summoner.T_SMOKESCREEN)
					local rad = 2
					local Map = require "engine.Map"
					self:useEnergy()
					
					local actor = game.level.map(self.x, self.y, Map.ACTOR)
					if actor then
						self.summoner:project({type="hit", range=10, talent=self.summoner:getTalentFromId(self.summoner.T_SMOKESCREEN)}, actor.x, actor.y, engine.DamageType.SMOKESCREEN, 
						{
						dam=self.summoner:callTalent(self.summoner.T_SMOKESCREEN, "getSightLoss"), 
						poison=self.summoner:callTalent(self.summoner.T_SMOKESCREEN, "getDamage")
						})
					end

					self.temporary = self.temporary - 1
					if self.temporary <= 0 then
						if self.particles then game.level.map:removeParticleEmitter(self.particles) end
						game.level.map:remove(self.x, self.y, engine.Map.TERRAIN+rad)
						self.smokeBomb = nil
						game.level:removeEntity(self)
						game.level.map:scheduleRedisplay()
					end
				end,
				summoner_gain_exp = true,
				summoner = self,
			}
			e.smokeBomb = e -- used for checkAllEntities to return the dark Object itself
			game.level:addEntity(e)
			game.level.map(px, py, Map.TERRAIN+self:getTalentRadius(t), e)
			e.particles = Particles.new("creeping_dark", 1, { })
			e.particles.x = px
			e.particles.y = py
		game.level.map:addParticleEmitter(e.particles)

		end, nil, {type="dark"})

		game:playSoundNear(self, "talents/breath")
		game.level.map:redisplay()
		return true
	end,
	info = function(self, t)
		return ([[Throw a vial of sticky smoke that explodes in radius %d, blocking line of sight for 5 turns. Enemies within will have their vision range reduced by %d.
		Creatures affected by smokescreen can never prevent you from stealthing, even if their proximity would normally forbid it.
		Use of this will not break stealth.]]):
		format(self:getTalentRadius(t), t.getSightLoss(self,t))
	end,
}

newTalent{
	name = "Assassinate",
	type = {"cunning/tools", 1},
	points = 1,
	cooldown = 8,
	message = "@Source@ lashes out with their hidden blades!",
	tactical = { ATTACK = { weapon = 2 } },
	requires_target = true,
	is_melee = true,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	range = 1,
	getDamage = function(self, t) return self:callTalent(self.T_MASTER_ARTIFICER, "getAssassinateDamage") end,
	getBleed = function(self, t) return self:combatTalentScale(t, 0.3, 1) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end
		
		target.turn_procs.hb = true -- we're already using our hidden blades for this attack
		self.turn_procs.auto_melee_hit = true
		
		self:attr("combat_apr", 1000)
		local penstore = self.resists_pen
		local storeeva = target.evasion
		target.evasion=0
		self.resists_pen = nil
		self.resists_pen = {all = 100}
		
		local scale = nil
		scale = t.getBleed(self, t)
		local oldlife = target.life

		self:attackTarget(target, nil, t.getDamage(self, t), true, true)
		self:attackTarget(target, nil, t.getDamage(self, t), true, true)
		
		local life_diff = oldlife - target.life
		if life_diff > 0 and target:canBe('cut') and scale then
			target:setEffect(target.EFF_CUT, 5, {power=life_diff * scale / 5, src=self})
		end

		self:attr("combat_apr", -1000)
		self.turn_procs.auto_melee_hit = nil
		target.evasion = storeeva
		self.resists_pen = nil
		self.resists_pen = penstore

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t) * 100
		local bleed = t.getBleed(self,t) * 100
		return ([[Impale the target on your hidden blades, striking twice for %d%% unarmed damage. This attack always hits and ignores all armor and resistances.
In addition, your hidden blades now inflict a further %d%% of all damage dealt as bleeding over 5 turns.]])
		:format(damage, bleed)
	end,
}

newTalent{
	name = "Rogue's Brew Mastery",
	type = {"cunning/tools", 1},
	mode = "passive",
	points = 1,
	getDieAt = function(self,t) return self:callTalent(self.T_MASTER_ARTIFICER, "getRBDieAt") end,
	info = function(self, t)
		return ([[The brew strengthens you for 8 turns, preventing you from dying until you reach -%d life.]]):
		format(t.getDieAt(self,t))
	end,
}

newTalent{
	name = "Smokescreen Mastery",
	type = {"cunning/tools", 1},
	points = 1,
	mode = "passive",
	getSSDamage = function (self,t) return self:callTalent(self.T_MASTER_ARTIFICER, "getSSDamage") end,
	getSSEvasion = function (self,t) return self:callTalent(self.T_MASTER_ARTIFICER, "getSSEvasion") end,
	no_npc_use = true,
	info = function(self, t)
		return ([[Infuses your smoke bomb with chokedust, causing %0.2f nature damage each turn and silencing enemies inside.]]):
		format(damDesc(self, DamageType.NATURE, t.getSSDamage(self,t)), t.getSSEvasion(self,t))
	end,
}

newTalent{
	name = "Dart Launcher",
	type = {"cunning/tools", 1},
	points = 1,
	tactical = { ATTACK = 2 },
	range = 5,
	no_energy = true,
	cooldown = 10,
	requires_target = true,
	no_break_stealth = true,
	getDamage = function(self, t) 
		if self.artifice_dart_launcher == 1 then return self:callTalent(self.T_ROGUE_S_TOOLS, "getDLDamage")
		elseif self.artifice_dart_launcher == 2 then return self:callTalent(self.T_CUNNING_TOOLS, "getDLDamage") 
		elseif self.artifice_dart_launcher == 3 then return self:callTalent(self.T_INTRICATE_TOOLS, "getDLDamage") 
		else return 0
		end
	end,
	getSleepPower = function(self, t)
		if self.artifice_dart_launcher == 1 then return self:callTalent(self.T_ROGUE_S_TOOLS, "getDLSleepPower")
		elseif self.artifice_dart_launcher == 2 then return self:callTalent(self.T_CUNNING_TOOLS, "getDLSleepPower") 
		elseif self.artifice_dart_launcher == 3 then return self:callTalent(self.T_INTRICATE_TOOLS, "getDLSleepPower") 
		else return 0
		end
	end,
    getSlow = function(self, t) return self:callTalent(self.T_MASTER_ARTIFICER, "getDLSlow") end,
	target = function(self, t)
		return {type="bolt", range=self:getTalentRange(t)}
	end,
		action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		if not tg then return nil end
		
		local slow = 0
		
		if self:knowTalent(self.T_DART_LAUNCHER_MASTERY) then slow = t.getSlow(self,t) end

		self:project(tg, x, y, function(px, py)
			local target = game.level.map(px, py, engine.Map.ACTOR)
			if not target then return nil end
			self:project(tg, x, y, DamageType.PHYSICAL, t.getDamage(self,t))
			if (target:canBe("sleep") and target:canBe("poison")) or self:knowTalent(self.T_DART_LAUNCHER_MASTERY) then
				target:setEffect(target.EFF_SEDATED, 4, {src=self, power=t.getSleepPower(self,t), slow=slow, insomnia=20, no_ct_effect=true, apply_power=self:combatAttack()})
				game.level.map:particleEmitter(target.x, target.y, 1, "generic_charge", {rm=180, rM=200, gm=100, gM=120, bm=30, bM=50, am=70, aM=180})
			else
				game.logSeen(self, "%s resists the sleep!", target.name:capitalize())
			end

		end)

		return true
	end,
	info = function(self, t)
		local dam = t.getDamage(self,t)
		local power = t.getSleepPower(self,t)
		return ([[Uses a wrist mounted launcher to fire a poisoned dart dealing %0.2f physical damage and putting the target to sleep for 4 turns, rendering them unable to act. Every %d points of damage the target take reduces the duration of the sleeping poison by 1 turn.
This can be used without breaking stealth.]]):
	format(damDesc(self, DamageType.PHYSICAL, dam), power)
	end,
}

newTalent{
	name = "Dart Launcher Mastery",
	type = {"cunning/tools", 1},
	mode = "passive",
	points = 1,
    getSlow = function(self, t) return self:callTalent(self.T_MASTER_ARTIFICER, "getDLSlow") end,
	info = function(self, t)
		return ([[The sleeping poison of your Dart Launcher becomes potent enough to ignore immunity, and upon waking the target is slowed by %d%% for 4 turns.]]):
		format(t.getSlow(self, t)*100)
	end,
}