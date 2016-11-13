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

newTalent{
	name = "Parry",
	type = {"technique/duelist", 1},
	points = 5,
	require = techs_dex_req1,
	mode = "passive",
	getDeflectChance = function(self, t) return self:combatTalentLimit(t, 75, 15, 50) end,
	getDeflectPercent = function(self, t) return self:combatTalentScale(t, 15, 40) end,
	getDeflect = function(self, t, fake)
		local dam,_,weapon = 0,self:hasDualWeapon()
		if not weapon or weapon.subtype=="mindstar" and not fake then return 0 end
		if weapon then
			dam = self:combatDamage(weapon.combat) * self:getOffHandMult(weapon.combat)
		end
		return t.getDeflectPercent(self, t) * dam/100
	end,
	getDeflects = function(self, t, fake)
		return 2
	end,
	getDamageChange = function(self, t, fake)
		local dam,_,weapon = 0,self:hasDualWeapon()
		if not weapon or weapon.subtype=="mindstar" and not fake then return 0 end
		if weapon then
			dam = self:combatDamage(weapon.combat) * self:getOffHandMult(weapon.combat)
		end
		return t.getDeflectPercent(self, t) * dam/100
	end,
	doDeflect = function(self, t)
		local eff = self:hasEffect(self.EFF_PARRY)
		if not eff then return 0 end
		local deflected = 0
		if rng.percent(self.tempeffect_def.EFF_PARRY.deflectchance(self, eff)) then
			deflected = eff.dam
		end
		eff.deflects = eff.deflects -1
		if eff.deflects <=0 then self:removeEffect(self.EFF_PARRY) end
		return deflected
	end,
	callbackOnActBase = function(self, t)
		self:setEffect(self.EFF_PARRY,1,{})
	end,
	info = function(self, t)
		block = t.getDeflect(self,t)
		chance = t.getDeflectChance(self,t)
		perc = t.getDeflectPercent(self,t)
		return ([[You have a %d%% chance to parry melee or ranged attacks against you with your offhand weapon (except mindstars), reducing the damage dealt by %d (%d%% of your offhand weapon damage). This reduction is applied alongside your armor value.
You can parry up to 2 attacks per turn.]]):
		format(chance, block, perc)
	end,
}

newTalent{
	name = "Tempo",
	type = {"technique/duelist", 2},
	require = techs_dex_req2,
	points = 5,
	mode = "passive",
	getStamina = function(self, t) return self:combatTalentScale(t, 1, 5) end,
	getSpeed = function(self, t) return self:combatTalentScale(t, 5, 20) end,
	do_tempo = function(self, t, src)
		if self.turn_procs.tempo then return end
		self.turn_procs.tempo = true
		self:incStamina(t.getStamina(self,t))
		local energy = (game.energy_to_act * t.getSpeed(self,t))/100
		self.energy.value = self.energy.value + energy
		local cooldown = self.talents_cd["T_FEINT"] or 0
		if cooldown > 0 then
			self.talents_cd["T_FEINT"] = math.max(cooldown - 1, 0)
		end
	end,
	callbackOnMeleeMiss = function(self, t, src)
		if self.turn_procs.tempo then return end
		self.turn_procs.tempo = true
		self:incStamina(t.getStamina(self,t))
		local energy = (game.energy_to_act * t.getSpeed(self,t))/100
		self.energy.value = self.energy.value + energy
		local cooldown = self.talents_cd["T_FEINT"] or 0
		if cooldown > 0 then
			self.talents_cd["T_FEINT"] = math.max(cooldown - 1, 0)
		end
	end,
	callbackOnArcheryMiss = function(self, t, src)
		if self.turn_procs.tempo then return end
		self.turn_procs.tempo = true
		self:incStamina(t.getStamina(self,t))
		local energy = (game.energy_to_act * t.getSpeed(self,t))/100
		self.energy.value = self.energy.value + energy
		local cooldown = self.talents_cd["T_FEINT"] or 0
		if cooldown > 0 then
			self.talents_cd["T_FEINT"] = math.max(cooldown - 1, 0)
		end
	end,
	info = function(self, t)
		local sta = t.getStamina(self,t)
		local speed = t.getSpeed(self,t)
		return ([[On parrying, evading an attack or avoiding damage you attune to the flow of battle, restoring %0.1f stamina and instantly gaining %d%% of a turn.
This cannot occur more than once per turn.]])
		:format(sta, speed)
	end,
}

newTalent{
	name = "Duelist's Focus",
	type = {"technique/duelist", 3},
	require = techs_dex_req3,
	points = 5,
	mode = "sustained",
	sustain_stamina = 20,
	cooldown = 30,
	no_energy = true,
	getChance = function(self, t) return self:combatTalentScale(t, 5, 20, 0.75) end,
	critResist = function(self, t) return self:combatTalentScale(t, 15, 50, 0.75) end,
	on_pre_use = function(self, t, silent, fake)
		local armor = self:getInven("BODY") and self:getInven("BODY")[1]
		if armor and (armor.subtype == "heavy" or armor.subtype == "massive") then
			if not silent then game.logPlayer(self, "You cannot be stealthy with such heavy armour on!") end
			return nil
		end
		return true
	end,
	activate = function(self, t)
		local ret = {}
		local chance = t.getChance(self, t)
		local crit = t.critResist(self,t)
		self:talentTemporaryValue(ret, "cancel_damage_chance", chance)
		self:talentTemporaryValue(ret, "ignore_direct_crits", crit)
		return ret
	end,
	deactivate = function(self, t, p)
		return true
	end,
	info = function(self, t)
		local chance = t.getChance(self,t)
		local crit = t.critResist(self,t)
		return ([[Your reflexes are lightning quick, giving you a %d%% chance to entirely ignore incoming damage and causing all direct critical hits (physical, mental, spells) against you to have a %d%% lower Critical multiplier (but always do at least normal damage)
This requires unrestricted mobility, and so is not usable while in heavy or massive armor.]])
		:format(chance, crit)
	end,
}

newTalent{
	name = "Feint",
	type = {"technique/duelist", 4},
	require = techs_dex_req4,
	points = 5,
	cooldown = 18,
	stamina = 20,
	requires_target = true,
	tactical = { DISABLE = 2, ATTACK = {weapon = 2} },
	is_melee = true,
	range = 1,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	getDuration = function(self, t) return math.floor(self:combatTalentLimit(t, 8, 3, 5)) end,
	getSpeedPenalty = function(self, t) return self:combatLimit(self:combatTalentStatDamage(t, "dex", 5, 50), 100, 20, 0, 55.7, 35.7) end, -- Limit < 100%
	on_pre_use = function(self, t, silent) if not self:hasDualWeapon() then if not silent then game.logPlayer(self, "You require two weapons to use this talent.") end return false end return true end,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 1.4, 2.9) end,
	on_pre_use = function(self, t)
		if self:attr("never_move") then return false end
		return true
	end,
	speed = "weapon",
	action = function(self, t)
		local weapon, offweapon = self:hasDualWeapon()
		if not weapon then
			game.logPlayer(self, "You cannot use Feint without dual wielding!")
			return nil
		end

		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end
		local tx, ty, sx, sy = target.x, target.y, self.x, self.y

		local dam = t.getDamage(self,t)
		-- Attack
		if not core.fov.distance(self.x, self.y, x, y) == 1 then return nil end
		
		local hitted = self:attackTargetWith(target, offweapon.combat, nil, self:getOffHandMult(offweapon.combat, dam))
		if hitted then
			local speed = t.getSpeedPenalty(self, t) / 100
			target:setEffect(target.EFF_CRIPPLE, t.getDuration(self, t), {speed=speed, apply_power=self:combatAttack()})
		end


		if not self.dead and tx == target.x and ty == target.y then
			if not self:canMove(tx,ty,true) or not target:canMove(sx,sy,true) then
				self:logCombat(target, "Terrain prevents #Source# from switching places with #Target#.")
				return true
			end
			-- Displace
			if not target.dead then
				self:move(tx, ty, true)
				target:move(sx, sy, true)
			end
		end
		return true
	end,
	info = function(self, t)
		local dam = t.getDamage(self, t)
		local speed = t.getSpeedPenalty(self,t)
		local dur = t.getDuration(self,t)
		return ([[Make a cunning feint that tricks your target into swapping places with you. As you swap strike the target with a crippling blow, dealing %d%% offhand damage and reducing their melee, spellcasting and mind speed by %d%% for %d turns.
If you know Tempo, the cooldown of this talent will also be reduced by 1 turn each time it triggers.
The chance to land the status improves with Accuracy, and the status power improves with Dexterity.]]):
		format(dam*100, speed, dur)
	end,
}