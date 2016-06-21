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

local function knives(self)
	local combat = {
		talented = "knife",
--		sound = {"actions/melee", pitch=0.6, vol=1.2}, sound_miss = {"actions/melee", pitch=0.6, vol=1.2},

		damrange = 1.4,
		physspeed = 1,
		dam = 0,
		apr = 0,
		atk = 0,
		physcrit = 0,
		dammod = {dex=0.7, cun=0.5},
		melee_project = {},
		special_on_crit = {fct=function(combat, who, target)
			if not self:knowTalent(self.T_PRECISE_AIM) then return end
			if not rng.percent(self:callTalent(self.T_PRECISE_AIM, "getChance")) then return end
			local eff = rng.table{"disarm", "pin", "silence",}
			if not target:canBe(eff) then return end
			local check = who:combatAttack()
			if not who:checkHit(check, target:combatPhysicalResist()) then return end
			if eff == "disarm" then target:setEffect(target.EFF_DISARMED, 2, {})
			elseif eff == "pin" then target:setEffect(target.EFF_PINNED, 2, {})
			elseif eff == "silence" then target:setEffect(target.EFF_SILENCED, 2, {})
			end

		end},
	}
	if self:knowTalent(self.T_THROWING_KNIVES) then
		local t = self:getTalentFromId(self.T_THROWING_KNIVES)
		local t2 = self:getTalentFromId(self.T_PRECISE_AIM)
		combat.dam = 0 + t.getBaseDamage(self, t)
		combat.apr = 0 + t.getBaseApr(self, t)
		combat.physcrit = 0 + t.getBaseCrit(self,t) + t2.getCrit(self,t2)
		combat.atk = 0 + self:combatAttack()
	end
	return combat
end

local function throw(self, range, dam, x, y, dtype, special, fok)
		local eff = self:hasEffect(self.EFF_THROWING_KNIVES)
		if not eff then return nil end
		self.turn_procs.quickdraw = true
		local tg = {type="bolt", range=range, selffire=false, display={display='', particle="arrow", particle_args={tile="particles_images/rogue_throwing_knife"} }}
		self:projectile(tg, x, y, function(px, py, tg, self)
			local target = game.level.map(px, py, engine.Map.ACTOR)
			if target and target ~= self then
				local t = self:getTalentFromId(self.T_THROWING_KNIVES)
				local t2 = self:getTalentFromId(self.T_PRECISE_AIM)
				local critstore = self.combat_critical_power or 0
				self.combat_critical_power = nil
				self.combat_critical_power = critstore + t2.getCritPower(self,t2)
				local hit = self:attackTargetWith(target, t.getKnives(self, t), dtype, dam)
				self.combat_critical_power = nil
				self.combat_critical_power = critstore
				if hit then
					if special==1 then
						local t2 = self:getTalentFromId(self.T_VENOMOUS_STRIKE)
						local dam = t2.getDamage(self,t2)
						local idam = t2.getSecondaryDamage(self,t2)
						local vdam = t2.getSecondaryDamage(self,t2)*0.6
						local power = t2.getPower(self,t2)
						local heal = t2.getSecondaryDamage(self,t2)
						local nb = t2.getNb(self,t2)
						
						if hit and self:isTalentActive(self.T_NUMBING_POISON) then target:setEffect(target.EFF_SLOW, 5, {power=power, no_ct_effect=true}) end
						if hit and self:isTalentActive(self.T_INSIDIOUS_POISON) then target:setEffect(target.EFF_POISONED, 5, {src=self, power=idam/5, no_ct_effect=true}) end		
						if hit and self:isTalentActive(self.T_CRIPPLING_POISON) then 
							local tids = {}
							for tid, lev in pairs(target.talents) do
								local t = target:getTalentFromId(tid)
								if t and not target.talents_cd[tid] and t.mode == "activated" and not t.innate then tids[#tids+1] = t end
							end
						
							local count = 0
							local cdr = nb*1.5
						
							for i = 1, nb do
								local t = rng.tableRemove(tids)
								if not t then break end
								target.talents_cd[t.id] = cdr
								game.logSeen(target, "%s's %s is disrupted by the crippling poison!", target.name:capitalize(), t.name)
								count = count + 1
							end		
						end
						if hit and self:isTalentActive(self.T_LEECHING_POISON) then self:heal(heal, target) end
						if hit and self:isTalentActive(self.T_VOLATILE_POISON) then 
							local tg = {type="ball", radius=nb, friendlyfire=false, x=target.x, y=target.y}
							self:project(tg, target.x, target.y, DamageType.NATURE, vdam)
						end
					end
				end
			end
		end)
		if not fok then eff.stacks = eff.stacks - 1 end
		if eff.stacks <= 0 then self:removeEffect(self.EFF_THROWING_KNIVES) end
end


newTalent{
	name = "Throwing Knives",
	type = {"technique/throwing-knives", 1},
	points = 5,
	random_ego = "attack",
	require = {
		stat = { dex=function(level) return 12 + (level-1) * 2 end },
		level = function(level) return 0 + (level-1) * 8  end,
	},
	on_learn = function(self, t)
		if self:knowTalent(self.T_VENOMOUS_STRIKE) and not self:knowTalent(self.T_VENOMOUS_THROW) then
			self:learnTalent(self.T_VENOMOUS_THROW, true, nil, {no_unlearn=true})
		end
		local max = self:callTalent(self.T_THROWING_KNIVES, "getNb")
		self:setEffect(self.EFF_THROWING_KNIVES, 1, {stacks=max, max_stacks=max })
	end,
	on_unlearn = function(self, t)
		if self:knowTalent(self.T_VENOMOUS_THROW) then
			self:unlearnTalent(self.T_VENOMOUS_THROW)
		end
		self:removeEffect(self.EFF_THROWING_KNIVES)
	end,
	speed = "throwing",
	tactical = { ATTACK = { weapon = 2 } },
	range = function(self, t) return math.floor(self:combatTalentScale(t, 4, 7)) end,
	requires_target = true,
	target = function(self, t)
		return {type="bolt", range=self:getTalentRange(t), selffire=false, talent=t, display={display='', particle="arrow", particle_args={tile="shockbolt/object/knife_steel"} }}
	end,
	on_pre_use = function(self, t)
		local eff = self:hasEffect(self.EFF_THROWING_KNIVES)
		if eff then
			return true
		end	
	end,
	callbackOnActBase = function(self, t)
		if self.resting then
			local reload = self:callTalent(self.T_THROWING_KNIVES, "getReload")
			local max = self:callTalent(self.T_THROWING_KNIVES, "getNb")
			self:setEffect(self.EFF_THROWING_KNIVES, 1, {stacks=reload, max_stacks=max })
		end
	end,
	getBaseDamage = function(self, t) return 5 + self:combatTalentScale(t, 10, 40) end,
	getBaseApr = function(self, t) return self:combatTalentScale(t, 2, 10) end,
	getReload = function(self, t) return 2 end,
	getNb = function(self, t) return 6 end,
	getBaseCrit = function(self, t) return self:combatTalentScale(t, 2, 5) end,
	getKnives = function(self, t) return knives(self) end, -- To prevent upvalue issues
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)

		throw(self, self:getTalentRange(t), 1, x, y, nil, nil, nil)

		return true
	end,
	callbackOnMove = function(self, t, moved, force, ox, oy)
		if moved and not force and ox and oy and (ox ~= self.x or oy ~= self.y) then
			if self.turn_procs.tkreload then return end
			local reload = self:callTalent(self.T_THROWING_KNIVES, "getReload")
			local max = self:callTalent(self.T_THROWING_KNIVES, "getNb")
			self:setEffect(self.EFF_THROWING_KNIVES, 1, {stacks=reload, max_stacks=max })
			self.turn_procs.tkreload = true
		end
	end,

	info = function(self, t)
		local nb = t.getNb(self,t)
		local reload = t.getReload(self,t)
		local weapon_damage = knives(self).dam
		local weapon_range = knives(self).dam * knives(self).damrange
		local weapon_atk = knives(self).atk
		local weapon_apr = knives(self).apr
		local weapon_crit = knives(self).physcrit
		return ([[Equip a bandolier of throwing knives, allowing you to attack from range. You can hold up to a maximum of %d knives, and will reload %d per turn while waiting, resting or moving.
		The base power, Accuracy, Armour penetration, and critical strike chance of your knives will increase with your talent investment, and their damage will be further improved with Dagger Mastery.
		Throwing Knives count as melee attacks for the purpose of on-hit effects.

		Current Throwing Knife Stats
		Base Power: %0.2f - %0.2f
		Uses Stats: 70%% Dex 50%% Cun
		Damage Type: Physical
		Accuracy: +%d
		Armour Penetration: +%d
		Physical Crit. Chance: +%d]]):format(nb, reload, weapon_damage, weapon_range, weapon_atk, weapon_apr, weapon_crit)
	end,
}

newTalent{
	name = "Fan of Knives",
	type = {"technique/throwing-knives", 2},
	require = techs_dex_req2,
	points = 5,
	tactical = { ATTACKAREA = 3 },
	speed = "throwing",
	getDamage = function (self, t) return self:combatTalentWeaponDamage(t, 0.4, 1.0) end,
	getNb = function(self, t) return math.floor(self:combatTalentScale(t, 4, 8)) end,
	range = 0,
	cooldown = 10,
	stamina = 30,
	on_pre_use = function(self, t)
		local eff = self:hasEffect(self.EFF_THROWING_KNIVES)
		if eff then
			return true
		end	
	end,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 3, 7)) end,
	target = function(self, t)
		return {type="cone", range=self:getTalentRange(t), friendlyfire=false, radius=self:getTalentRadius(t)}
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return end


		local count = t.getNb(self,t)
		local eff = self:hasEffect(self.EFF_THROWING_KNIVES)
		local reload = self:callTalent(self.T_THROWING_KNIVES, "getReload")
		local max = self:callTalent(self.T_THROWING_KNIVES, "getNb")
		
		local tgts = {}
		grids = self:project(tg, x, y, function(px, py)
			local target = game.level.map(px, py, engine.Map.ACTOR)
			if not target then return end
			tgts[#tgts+1] = target
		end)

		table.shuffle(tgts)
		
		while count > 0 and #tgts > 0 and eff do
			for i = 1, math.min(count, #tgts) do
				if #tgts <= 0 then break end
				local a, id = tgts[i]
				if a then
					throw(self, self:getTalentRadius(t), t.getDamage(self,t), a.x, a.y, nil, nil, 1)
					count = count - 1
					a.turn_procs.fan_of_knives = 1 + (a.turn_procs.fan_of_knives or 0)
					if a.turn_procs.fan_of_knives==3 then table.remove(tgts, id) end
				end
			end
		end


		return true
	end,
	info = function(self, t)
		return ([[Throw up to %d throwing knives at enemies within a radius %d cone, for %d%% damage each. If the number of knives exceeds the number of enemies, a target can be hit up to 3 times.
This does not consume throwing knives, but requires at least one throwing knife available.]]):
		format(t.getNb(self,t), self:getTalentRadius(t), t.getDamage(self, t)*100)
	end,
}

newTalent{
	name = "Precise Aim",
	type = {"technique/throwing-knives", 3},
	require = techs_dex_req3,
	points = 5,
	mode = "passive",
	range = 0,
	no_npc_use = true,
	getCrit = function(self, t) return self:combatTalentScale(t, 3, 15) end,
	getCritPower = function(self, t) return self:combatTalentScale(t, 10, 40) end,
	getChance = function(self, t) return self:combatTalentLimit(t, 100, 15, 45) end,
	info = function(self, t)
		local crit = t.getCrit(self,t)
		local power = t.getCritPower(self,t)
		local chance = t.getChance(self,t)
		return ([[You are able to target your throwing knives with pinpoint accuracy, increasing their critical strike chance by %d%% and critical strike damage by %d%%. 
In addition, your critical strikes with throwing knives will now randomly strike your target’s hand, throat or leg, giving them a %d%% chance to disarm, silence or pin them for 2 turns.]])
		:format(crit, power, chance)
	end,
}

newTalent{
	name = "Quickdraw",
	type = {"technique/throwing-knives", 4},
	require = techs_dex_req4,
	mode = "sustained",
	points = 5,
	cooldown = 50,
	sustain_stamina = 30,
	tactical = { BUFF = 2 },
	range = 7,
	getSpeed = function(self, t) return self:combatTalentLimit(t, 50, 10, 35) end,
	getChance = function(self, t) return self:combatTalentLimit(t, 100, 8, 25) end,
	activate = function(self, t)
		local ret = {
		}
		return ret
	end,
	deactivate = function(self, t, p)
		return true
	end,
	callbackOnMeleeAttack = function(self, t, target, hitted, crit, weapon, damtype, mult, dam)
	
		if not rng.percent(t.getChance(self,t)) then return nil end
		
		local tg = {type="ball", range=0, radius=7, friendlyfire=false }
		local tgts = {}
		
		local eff = self:hasEffect(self.EFF_THROWING_KNIVES)

		if hitted and not self.turn_procs.quickdraw and eff then
			self:project(tg, self.x, self.y, function(px, py, tg, self)	
				local target = game.level.map(px, py, Map.ACTOR)	
				if target and target ~= self then	
					tgts[#tgts+1] = target
				end	
			end)	
		end
		
		if #tgts <= 0 then return nil end
		local a, id = rng.table(tgts)
		throw(self, self:getTalentRange(t), 1, a.x, a.y, nil, nil, nil)
		self.turn_procs.quickdraw = true

	end,
	info = function(self, t)
		local speed = t.getSpeed(self, t)
		local chance = t.getChance(self, t)
		return ([[You can throw knives with lightning speed, increasing your attack speed with them by %d%% and giving you a %d%% chance when striking a target in melee to throw a knife at a random target within 7 tiles for 100%% damage. 
		This bonus knife can only trigger once per turn, and does not trigger from throwing knife attacks.]]):
		format(speed, chance)
	end,
}

newTalent{
	name = "Venomous Throw",
	type = {"technique/other", 1},
	points = 1,
	random_ego = "attack",
	cooldown = 8,
	stamina = 14,
	speed = "throwing",
	tactical = { ATTACK = { weapon = 2 } },
	range = function(self, t) 
		local t = self:getTalentFromId(self.T_THROWING_KNIVES)
		return self:getTalentRange(t) 
	end,
	requires_target = true,
	target = function(self, t)
		return {type="bolt", range=self:getTalentRange(t), selffire=false, talent=t, display={display='', particle="arrow", particle_args={tile="shockbolt/object/knife_steel"} }}
	end,
	on_pre_use = function(self, t)
		local eff = self:hasEffect(self.EFF_THROWING_KNIVES)
		if eff then
			return true
		end	
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		
		local t2 = self:getTalentFromId(self.T_VENOMOUS_STRIKE)
		local dam = t2.getDamage(self,t2)

		throw(self, self:getTalentRange(t), dam, x, y, DamageType.NATURE, 1, nil)
		self.talents_cd[self.T_VENOMOUS_STRIKE] = 8

		return true
	end,
info = function(self, t)
		local t = self:getTalentFromId(self.T_VENOMOUS_STRIKE)
		local dam = 100 * t.getDamage(self,t)
		local idam = t.getSecondaryDamage(self,t)
		local vdam = t.getSecondaryDamage(self,t)*0.6
		local power = t.getPower(self,t)
		local heal = t.getSecondaryDamage(self,t)
		local nb = t.getNb(self,t)
		return ([[Throw a knife coated with venom, doing %d%% damage as nature and inflicting additional effects based on the poisons the target is affected by:
Numbing Poison - Reduces global speed by 5 for %d turns.
Insidious Poison - Deals a further %0.2f nature damage over 5 turns.
Crippling Poison - Places %d talents on cooldown for %d turns.
Leeching Poison - Heals you for %d.
Volatile Poison - Deals a further %0.2f nature damage in a %d radius ball.]]):
		format(dam, power*100, damDesc(self, DamageType.NATURE, idam), nb, nb*1.5, heal, damDesc(self, DamageType.NATURE, vdam), nb, nb)
	end,
}