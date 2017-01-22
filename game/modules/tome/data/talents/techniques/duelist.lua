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
	name = "Dual Weapon Mastery",
	type = {"technique/duelist", 1},
	points = 5,
	require = techs_dex_req1,
	mode = "passive",
	getDeflectChance = function(self, t) --Chance to parry with an offhand weapon
		local mult = 1
		if self:hasEffect(self.EFF_FEINT) then 
			local eff = self:hasEffect(self.EFF_FEINT)
			mult = mult + eff.power
		end
		return math.min(100,self:combatLimit(self:getTalentLevel(t)*self:getDex(), 100, 15, 20, 60, 250)*mult) -- ~68% at TL 6.5, 55 dex
	end,
	getDeflectPercent = function(self, t) -- Percent of offhand weapon damage used to deflect
		local mult = 1
		if self:hasEffect(self.EFF_FEINT) then 
			local eff = self:hasEffect(self.EFF_FEINT)
			mult = mult + eff.power
		end
		return math.max(0, self:combatTalentLimit(t, 100, 15, 50)*mult)
	end,
	-- deflect count handled in physical effect "PARRY" in mod.data.timed_effects.physical.lua
	getDeflects = function(self, t, fake)
		if fake or self:hasDualWeapon() then
			return self:combatStatScale("cun", 2, 3)
		else return 0
		end
	end,
	getDamageChange = function(self, t, fake)
		local dam,_,weapon = 0,self:hasDualWeapon()
		if not weapon or weapon.subtype=="mindstar" and not fake then return 0 end
		if weapon then
			dam = self:combatDamage(weapon.combat) * self:getOffHandMult(weapon.combat)
		end
		return t.getDeflectPercent(self, t) * dam/100
	end,
	getoffmult = function(self,t) return self:combatTalentLimit(t, 1, 0.6, 0.80) end, -- limit <100%
	callbackOnActBase = function(self, t)
		local mh, oh = self:hasDualWeapon()
		if (mh and oh) and oh.subtype ~= "mindstar" then
			self:setEffect(self.EFF_PARRY,1,{chance=t.getDeflectChance(self, t), dam=t.getDamageChange(self, t), deflects=t.getDeflects(self, t), parry_ranged=true})
		end
	end,
	on_unlearn = function(self, t) self:removeEffect(self.EFF_PARRY) end,
	info = function(self, t)
		mult = t.getoffmult(self,t)*100
		block = t.getDamageChange(self, t, true)
		chance = t.getDeflectChance(self,t)
		perc = t.getDeflectPercent(self,t)
		return ([[Your offhand weapon damage penalty is reduced to %d%%.
		Up to %0.1f times a turn, you have a %d%% chance to parry up to %d damage (%d%% of your offhand weapon damage) from a melee or ranged attack.  The number of parries increases with your Cunning.  (A fractional parry has a reduced chance to succeed.)
		A successful parry reduces damage like armour (before any attack multipliers) and prevents critical strikes.  It is difficult to parry attacks from unseen attackers and you cannot parry with a mindstar.]]):
		format(100 - mult, t.getDeflects(self, t, true), chance, block, perc)
	end,
}

local function do_tempo(self, t, src) -- handle Tempo defensive bonuses
--game.log("do_tempo called for %s (%s)", self.name, src and src.name)
	if self.turn_procs.tempo then return end
	local mh, oh = self:hasDualWeapon()
	if mh and oh then
		self:incStamina(t.getStamina(self,t))
		self.energy.value = self.energy.value + game.energy_to_act*t.getSpeed(self,t)/100
		local cooldown = self.talents_cd["T_LUNGE"] or 0
		if cooldown > 0 then self.talents_cd["T_LUNGE"] = math.max(cooldown - 1, 0)	end
	end
	self.turn_procs.tempo = true
end

newTalent{
	name = "Tempo",
	type = {"technique/duelist", 2},
	require = techs_dex_req2,
	points = 5,
	mode = "passive",
	getStamina = function(self, t) return self:combatTalentLimit(t, 15, 1, 4) end, -- Limit < 15 (effectively scales with actor speed)
	getSpeed = function(self, t) return self:combatTalentLimit(t, 25, 5, 10) end, -- Limit < 25% of a turn gained
	do_tempo = do_tempo,
	callbackOnMeleeMiss = do_tempo,
	callbackOnArcheryMiss = do_tempo,
	-- handle offhand crit
	callbackOnMeleeAttack = function(self, t, target, hitted, crit, weapon, damtype, mult, dam)
		if crit and not self.turn_procs.tempo_attack then
			local mh, oh = self:hasDualWeapon()
			if oh and oh.combat == weapon then
				self:incStamina(t.getStamina(self,t))
			end
			self.turn_procs.tempo_attack = true
		end
	end,
	info = function(self, t)
		local sta = t.getStamina(self,t)
		local speed = t.getSpeed(self,t)
		return ([[The flow of battle invigorates you, allowing you to press your advantage as the fight progresses.
		Up to once each per turn, while dual wielding, you may:
		Reposte -- If a melee or archery attack misses you or you parry it, you instantly restore %0.1f stamina and gain %d%% of a turn.
		Recover -- On performing a critical strike with your offhand weapon, you instantly restore %0.1f stamina.]]):format(sta, speed, sta)
	end,
}

newTalent{
	name = "Feint",
	type = {"technique/duelist", 3},
	require = techs_dex_req3,
	points = 5,
	random_ego = "defensive",
	cooldown = 8,
	stamina = 12,
	requires_target = true,
	tactical = { DISABLE = 2 },
	is_melee = true,
	range = 1,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(t, 2, 5)) end,
	getEvasion = function(self, t) return math.floor(self:combatTalentLimit(t, 75, 15, 50)) end,
	on_pre_use = function(self, t)
		if self:attr("never_move") then return false end
		return true
	end,
	speed = "weapon",
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end
		local tx, ty, sx, sy = target.x, target.y, self.x, self.y

		if target:canBe("stun") then
			target:setEffect(target.EFF_DAZED, 2, {apply_power=self:combatAttack()})
		end

		if not self.dead and tx == target.x and ty == target.y then
			if not self:canMove(tx,ty,true) or not target:canMove(sx,sy,true) then
				self:logCombat(target, "Terrain prevents #Source# from switching places with #Target#.")
				return true
			end
			self:setEffect(self.EFF_FEINT, t.getDuration(self, t), {power=t.getEvasion(self,t)/100})
			-- Displace
			if not target.dead then
				self:move(tx, ty, true)
				target:move(sx, sy, true)
			end
		end

		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local power = t.getEvasion(self, t)
		return ([[Make a cunning feint that tricks your target into swapping places with you. As you swap you take the opportunity to trip them, dazing them for 2 turns.
		Switching places will distract your foes, making your parries from Dual Weapon Mastery %d%% more effective for %d turns.
		The chance to daze increases with your Accuracy]]):
		format(power, duration)
	end,
}

newTalent{
	name = "Lunge",
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
	getDuration = function(self, t) return math.floor(self:combatTalentLimit(t, 10, 3, 7)) end,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 1.8, 3.5) end, --super high scaling because this is offhand only
	on_pre_use = function(self, t, silent)
		if not self:hasDualWeapon() then
			if not silent then game.logPlayer(self, "You require two weapons to use this talent.") end
			return false
		end
		return true
	end,
	speed = "weapon",
	action = function(self, t)
		local weapon, offweapon = self:hasDualWeapon()
		if not weapon then
			game.logPlayer(self, "You cannot use Lunge without dual wielding!")
			return nil
		end

		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or core.fov.distance(self.x, self.y, x, y) ~= 1 or not self:canProject(tg, x, y) then return nil end

		-- Attack		
		local dam = t.getDamage(self,t)
		local spd, hitted, dmg = self:attackTargetWith(target, offweapon.combat, nil, self:getOffHandMult(offweapon.combat, dam))
		if hitted then
			target:setEffect(target.EFF_DISARMED, t.getDuration(self, t), {apply_power=self:combatAttack()})
		end
		return true
	end,
	info = function(self, t)
		local dam = t.getDamage(self, t)
		local dur = t.getDuration(self,t)
		return ([[Exploiting a gap in your target's defenses, you make a lethal strike with your offhand for %d%% damage that causes them to drop their weapon, disarming them for %d turns.
		Tempo will reduce the cooldown of this talent by 1 turn each time it is triggered defensively.
		The chance to disarm increases with your Accuracy.]]):
		format(dam*100, dur)
	end,
}