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
	name = "Coup de Grace",
	type = {"technique/assassination", 1},
	points = 5,
	random_ego = "attack",
	cooldown = 8,
	stamina = 24,
	require = techs_dex_req_high1,
	getDamage = function (self, t) return self:combatTalentWeaponDamage(t, 1.0, 1.5) end,
	getPercent = function(self, t) return self:combatTalentLimit(t, 30, 10, 25)/100 end,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	range = 1,
	requires_target = true,
	tactical = { ATTACK = { weapon = 2 } },
	on_pre_use = function(self, t, silent) if not self:hasDualWeapon() then if not silent then game.logPlayer(self, "You require two weapons to use this talent.") end return false end return true end,
	action = function(self, t)
		local weapon, offweapon = self:hasDualWeapon()
		if not weapon then
			game.logPlayer(self, "You cannot use Coup de Grace without dual wielding!")
			return nil
		end

		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end

		-- First attack with offhand
		local hit1 = self:attackTargetWith(target, offweapon.combat, nil, t.getDamage(self,t))
		local hit2 = self:attackTargetWith(target, weapon.combat, nil, t.getDamage(self,t))
		
		local percent = t.getPercent(self, t)/target.rank
		local dam = (target.max_life - target.life) * percent

		if hit1 then
			DamageType:get(DamageType.PHYSICAL).projector(self, target.x, target.y, DamageType.PHYSICAL, dam)
		end
		if hit2 then
			DamageType:get(DamageType.PHYSICAL).projector(self, target.x, target.y, DamageType.PHYSICAL, dam)
		end
		
		if hit1 or hit2 then
			if target:checkHit(self:combatAttack(), target:combatPhysicalResist(), 0, 95, 5 - self:getTalentLevel(t) / 2) and target:canBe("instakill") and target.life > target.die_at and target.life < target.max_life * 0.2 then
				-- KILL IT !
				game.logSeen(target, "%s is slain instantly!", target.name:capitalize())
				target:die(self)
			elseif target.life > 0 and target.life < target.max_life * 0.2 then
				game.logSeen(target, "%s resists the deathblow!", target.name:capitalize())
			end
		end

		if target.dead then
			game:onTickEnd(function()
				if self:knowTalent(self.T_STEALTH) and not self:isTalentActive(self.T_STEALTH)  then
					self.hide_chance = 1000
					self.talents_cd[self.T_STEALTH] = 0
					self:forceUseTalent(self.T_STEALTH, {ignore_energy=true, silent = true})
					self.hide_chance = nil
				end
			end)
		end

		return true

	end,
	info = function(self, t)
		dam = t.getDamage(self,t)*100
		perc = t.getPercent(self,t)*100
		return ([[Attempt to finish off a wounded enemy, striking them with both weapons for %d%% weapon damage, and additional physical damage equal to %d%% of their missing life (divided by rank) for each hit that lands. 
		Targets brought below 20%% life may be instantly slain, and you will take advantage of their death to slip back into stealth.]]):
		format(dam, perc)
	end,
}

newTalent{
	name = "Terrorize",
	type = {"technique/assassination", 2},
	require = techs_dex_req_high2,
	points = 5,
	mode = "passive",
	radius = function(self, t) return self:getTalentLevel(t) end,
	range = 0,
	getDuration = function(self, t) return self:combatTalentScale(t, 3, 5) end,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), friendlyfire=false, talent=t}
	end,
	terrorize = function(self, t)
		local tg = self:getTalentTarget(t)
		self:project(tg, self.x, self.y, DamageType.TERROR, {dur=t.getDuration(self,t)})
	end,
	info = function(self, t)
		local radius = self:getTalentRadius(t)
		local duration = t.getDuration(self,t)
		return ([[You strike in a brutal fashion on making your exit from stealth, terrifying those around you. 
		On leaving stealth, all enemies within radius %d will be stricken with terror, randomly inflicting stun, slow (40%% power) or confusion (50%% power) for %d turns.]])
		:format(radius, duration)
	end,
}

newTalent{
	name = "Garrote",
	type = {"technique/assassination", 3},
	require = techs_dex_req_high3,
	points = 5,
	random_ego = "attack",
	cooldown = 6,
	mode = "passive",
	requires_target = true,
	getDamage = function (self, t) return self:combatTalentWeaponDamage(t, 0.2, 0.6) end,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(t, 3, 7)) end,
	getPower = function(self, t) return self:combatTalentScale(t, 8, 25) end,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	range = 1,
	callbackOnMeleeAttack = function(self, t, target, hitted, crit, weapon, damtype, mult, dam)
		
		local dam = t.getDamage(self,t)
		if target and self:isTalentActive(self.T_STEALTH) and not self:isTalentCoolingDown(t) then
			if core.fov.distance(self.x, self.y, target.x, target.y) > 1 then return end
			target:setEffect(target.EFF_GARROTE, t.getDuration(self, t), {power=dam, reduce=t.getPower(self,t), src=self, apply_power=self:combatAttack()})
			self:startTalentCooldown(t)
		end
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)*100
		local dur = t.getDuration(self,t)
		local reduce = t.getPower(self,t)
		return ([[On attacking from stealth, you slip a garrote over the target’s neck (or other vulnerable part) and attempt to strangle them for %d turns. Strangled targets are pinned, deal %d%% reduced damage and take an automatic unarmed melee hit for %d%% damage each turn. 
		This effect ends immediately if you are no longer adjacent to your target.]])
		:format(dur, reduce, damage)
	end,
}

newTalent{
	name = "Marked for Death",
	type = {"technique/assassination", 4},
	require = techs_dex_req_high4,
	points = 5,
	cooldown = 25,
	stamina = 30,
	range = 10,
	requires_target = true,
	no_break_stealth = true,
	tactical = { ATTACK = { PHYSICAL = 4 }},
	getPower = function(self, t) return self:combatTalentScale(t, 10, 25) end,
	getPercent = function(self, t) return self:combatTalentScale(t, 5, 25) end,
	getDamage = function(self,t) return self:combatTalentStatDamage(t, "dex", 15, 180) end,
	target = function(self, t)
		return {type="hit", range=self:getTalentRange(t), talent=t}
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		
		self:project(tg, x, y, function(px, py)
		    target = game.level.map(px, py, engine.Map.ACTOR)
			if not target then return end
				target:setEffect(target.EFF_MARKED_FOR_DEATH, 6, {src=self, power=t.getPower(self,t), perc=t.getPercent(self,t)/100, dam = t.getDamage(self,t)})
		end)

		return true
	end,
	info = function(self, t)
		power = t.getPower(self,t)
		perc = t.getPercent(self,t)
		dam = t.getDamage(self,t)
		return ([[You mark a target for death for 6 turns, causing them to take %d%% increased damage from all sources. When this effect ends they will immediately take %0.2f physical damage, increased by %d%% of all damage taken while marked. 
		If a target dies while marked, the cooldown of this ability is reset and the cost refunded.
		This ability can be used without breaking stealth.
		The base damage dealt will increase with your Dexterity.]]):
		format(power, damDesc(self, DamageType.DARKNESS, dam), perc)
	end,
}