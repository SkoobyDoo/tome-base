-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2017 Nicolas Casalini
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

local Map = require "engine.Map"

newTalent{
	name = "Dirty Fighting",
	type = {"cunning/dirty", 1},
	points = 5,
	random_ego = "attack",
	cooldown = 10,
	stamina = 12,
	tactical = { DISABLE = 2, ATTACK = {weapon = 0.5} },
	require = cuns_req1,
	requires_target = true,
	range = 1,
	is_melee = true,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 1.0, 1.5) end,
	getDuration = function(self, t) return math.floor(self:combatTalentLimit(t, 10, 4, 8)) end,
	getPower = function(self, t) return math.floor(self:combatTalentScale(t, 5, 20)) end,
	speed = "weapon",
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end
		local hitted = self:attackTarget(target, nil, t.getDamage(self, t), true, true)
		if hitted then
			target:setEffect(target.EFF_DIRTY_FIGHTING, t.getDuration(self, t), {power = t.getPower(self,t), apply_power=self:combatAttack()})
		end

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local duration = t.getDuration(self, t)
		local power = t.getPower(self,t)
		return ([[You make a low blow against a vulnerable point on the target, dealing %d%% unarmed damage. If your attack hits, the target is left reeling, reducing their stun, blind, confusion and pin resistance by 50%% and physical save by %d for %d turns.
The chance to apply this effect increases with your Accuracy.]]):
		format(100 * damage, power, duration)
	end,
}

newTalent{
	name = "Backstab",
	type = {"cunning/dirty", 2},
	mode = "passive",
	points = 5,
	require = cuns_req2,
	getDamageBoost = function(self, t) return math.floor(self:combatTalentScale(t, 4, 10, 0.75)) end,
	getDisableChance = function(self, t) return math.floor(self:combatTalentLimit(t, 30, 1, 5)) end, -- Limit < 100%
	callbackOnMeleeAttack = function(self, t, target, hitted, crit, weapon, damtype, mult, dam)
		if target then
		
			local nb = 0
			for eff_id, p in pairs(target.tmp) do
				local e = target.tempeffect_def[eff_id]
				if (e.subtype.stun or e.subtype.blind or e.subtype.pin or e.subtype.disarm or e.subtype.cripple or e.subtype.confusion or e.subtype.silence)then nb = nb + 1 end
			end
			local chance = math.min(nb*t.getDisableChance(self,t),t.getDisableChance(self,t)*3)
			if rng.percent(chance) then
				if not self:checkHit(self:combatAttack(), target:combatPhysicalResist()) then return end
				local effect = rng.range(1, 3)
				if effect == 1 then
					-- disarm
					if target:canBe("disarm") then
						target:setEffect(target.EFF_DISARMED, 2, {})
					end
				elseif effect == 2 then
					-- pin
					if target:canBe("pinned") then
						target:setEffect(target.EFF_PINNED, 2, {})
					end
				elseif effect == 3 then
					-- cripple
					target:setEffect(target.EFF_CRIPPLE, 2, {speed=0.4})
				end
			end
		end
	end,
	info = function(self, t)
	local dam = t.getDamageBoost(self, t)
	local chance = t.getDisableChance(self,t)
		return ([[Your quick wit gives you a big advantage against disabled targets, increasing your damage by %d%% for each disabling effect the target is under, to a maximum of %d%%.
In addition, for each disabling effect the target is under, your melee attacks have a %d%% (to a maximum of %d%%) chance to disarm, cripple (40%% power) or pin them for 2 turns.
Disabling effects are stun, blind, daze, confuse, pin, disarm, cripple and silence.]]):
		format(dam, dam*3, chance, chance*3)
	end,
}

newTalent{
	name = "Blinding Powder",
	type = {"cunning/dirty", 3},
	require = cuns_req3,
	points = 5,
	random_ego = "attack",
	stamina = 18,
	cooldown = 12,
	tactical = { DISABLE = { blind = 2, } },
	range = 0,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 1, 2.5)) end,
	direct_hit = true,
	requires_target = true,
	target = function(self, t)
		return {type="cone", range=self:getTalentRange(t), radius=self:getTalentRadius(t), selffire=false, talent=t}
	end,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(t, 3, 5)) end,
	getSlow = function(self, t) return math.ceil(self:combatTalentScale(t, 15, 30, 0.75)) end,
	getAcc = function(self, t) return math.ceil(self:combatTalentScale(t, 8, 24, 0.75)) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		self:project(tg, x, y, DamageType.BLINDING_POWDER, {dur=t.getDuration(self, t), acc=t.getAcc(self,t), slow=t.getSlow(self,t)/100})
		game.level.map:particleEmitter(self.x, self.y, tg.radius, "breath_earth", {radius=tg.radius, tx=x-self.x, ty=y-self.y})

		return true
	end,
	info = function(self, t)
		local accuracy = t.getAcc(self,t)
		local speed = t.getSlow(self,t)
		local duration = t.getDuration(self, t)
		return ([[Throw a cloud of blinding dust in a radius %d cone. Enemies within will be blinded, as well as having their accuracy reduced by %d and movement speed by %d%% for %d turns.
		The chance to inflict these effects increase with your Accuracy.]]):format(self:getTalentRadius(t), accuracy, speed, duration)
	end,
}

newTalent{
	name = "Twist the Knife",
	type = {"cunning/dirty", 4},
	require = cuns_req4,
	points = 5,
	random_ego = "attack",
	cooldown = 15,
	fixed_cooldown = true,
	stamina = 20,
	requires_target = true,
	tactical = { DISABLE = 2, ATTACK = {weapon = 2} },
	is_melee = true,
	range = 1,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 1, 1.5) end,
	getDuration = function(self, t) return self:combatTalentScale(t, 2, 4, "log") end,
	getDebuffs = function(self, t) return math.floor(self:combatTalentScale(t, 1, 3, "log")) end,
	speed = "weapon",
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end
		local hitted = self:attackTarget(target, nil, t.getDamage(self, t), true)
		if not hitted then return true end

		local max_nb, dur = t.getDebuffs(self,t), t.getDuration(self, t)
		local nb = 0

		for eff_id, p in pairs(target.tmp) do
			local e = target.tempeffect_def[eff_id]
			if e.status == "detrimental" and e.type ~= "other" and e.decrease ~= 0 then
				p.dur = p.dur + dur
				nb = nb + 1
				game.logSeen(target, "#CRIMSON#%s's %s was extended!#LAST#", target.name:capitalize(), util.getval(p.getName, p) or e.desc)
				if nb >= max_nb then break end
			end
		end
		
		if nb > 0 then
			local effs = {}
			for eff_id, p in pairs(target.tmp) do
				local e = target.tempeffect_def[eff_id]
				if e.status == "beneficial" and e.type ~= "other" and e.decrease ~= 0 then
					effs[#effs+1] = {eff_id, e}
				end
			end
			
			for i = 1, nb do
				if #effs == 0 then break end
				local eff = rng.tableRemove(effs)
				if eff then
					local p = target.tmp[eff[1]]
					p.dur = p.dur - dur
					if p.dur <= 0 then
						target:removeEffect(eff[1])
						game.logSeen(target, "#CRIMSON#%s's %s was stripped!#LAST#", target.name:capitalize(), util.getval(p.getName, p) or eff[2].desc)
					else
						game.logSeen(target, "#CRIMSON#%s's %s was disrupted!#LAST#", target.name:capitalize(), util.getval(p.getName, p) or eff[2].desc)
					end
				else break
				end
			end			
		end

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local dur = t.getDuration(self, t)
		local nb = t.getDebuffs(self, t)
		return ([[Make a painful strike dealing %d%% weapon damage that increases the duration of up to %d negative effect(s) on the target by %d turns. For each negative effect extended this way, the duration of a beneficial effect is reduced by the same amount, possibly canceling it.]]):
		format(100 * damage, nb, dur)
	end,
}