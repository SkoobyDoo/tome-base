-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2016 Nicolas Casalini
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

newTalent{
	name = "Lethality",
	type = {"cunning/lethality", 1},
	mode = "passive",
	points = 5,
	require = cuns_req1,
	critpower = function(self, t) return self:combatTalentScale(t, 7.5, 20, 0.75) end,
	-- called by _M:combatCrit in mod.class.interface.Combat.lua
	getCriticalChance = function(self, t) return self:combatTalentScale(t, 2.3, 7.5, 0.75) end,
	passives = function(self, t, p)
		self:talentTemporaryValue(p, "combat_critical_power", t.critpower(self, t))
	end,
	info = function(self, t)
		local critchance = t.getCriticalChance(self, t)
		local power = t.critpower(self, t)
		return ([[You have learned to find and hit weak spots. All your strikes have a %0.2f%% greater chance to be critical hits, and your critical hits do %0.1f%% more damage.
		Also, when using knives, you now use your Cunning instead of your Strength for bonus damage.]]):
		format(critchance, power)
	end,
}

newTalent{
	name = "Expose Weakness",
	type = {"cunning/lethality", 2},
	points = 5,
	random_ego = "attack",
	cooldown = 10,
	stamina = 15,
	require = cuns_req2,
	tactical = { ATTACK = {weapon = 2} },
	requires_target = true,
	is_melee = true,
	range = 1,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 0.8, 1.4) end,
	getDuration = function(self, t) return math.floor(self:combatTalentLimit(t, 10, 4, 8)) end, --Limit to <12
	getBonusDamage = function(self, t) return 4 + self:combatTalentStatDamage(t, "cun", 4, 40) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local _, x, y = self:canProject(tg, self:getTarget(tg))
		local target = game.level.map(x, y, game.level.map.ACTOR)
		if not target then return nil end

		local hitted = self:attackTarget(target, nil, t.getDamage(self, t), true)

		if hitted then
			target:setEffect(target.EFF_EXPOSE_WEAKNESS, t.getDuration(self,t), {src = self, power=t.getBonusDamage(self,t), apply_power=self:combatAttack()})
		end

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local bonus = t.getBonusDamage(self, t)
		local duration = t.getDuration(self, t)
		return ([[Attack your target with both weapons for %d%% damage, exposing flaws in their defences for %d turns. Exposed targets have their armor hardiness reduced by 50%%, and your attacks gain 50%% resistance penetration and deal a bonus %0.2f physical damage. 
		The bonus damage will increase with your Cunning, and the chance to expose will increase with your Accuracy.]]):
		format(100 * damage, duration, damDesc(self, DamageType.PHYSICAL, bonus))
	end,
}

newTalent{
	name = "Blade Flurry",
	type = {"cunning/lethality", 3},
	require = cuns_req3,
	mode = "sustained",
	points = 5,
	cooldown = 30,
	sustain_stamina = 50,
	tactical = { BUFF = 2 },
	drain_stamina = 6,
	no_break_stealth = true,
	no_energy = true,
	getSpeed = function(self, t) return self:combatTalentScale(t, 0.14, 0.45, 0.75) end,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 0.2, 0.6) end,
	activate = function(self, t)
		return {
			combat_physspeed = self:addTemporaryValue("combat_physspeed", t.getSpeed(self, t)),
		}
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("combat_physspeed", p.combat_physspeed)
		return true
	end,
	callbackOnMeleeAttack = function(self, t, target, hitted, crit, weapon, damtype, mult, dam)
	
		local tg = {type="ball", range=0, radius=1, friendlyfire=false, act_exclude={[target.uid]=true}}
		local tgts = {}
		
		if hitted and not self.turn_procs.blade_flurry then	
			self:project(tg, self.x, self.y, function(px, py, tg, self)	
				local target = game.level.map(px, py, Map.ACTOR)	
				if target and target ~= self then	
					tgts[#tgts+1] = target
				end	
			end)	
		end
		
		if #tgts <= 0 then return end
		local a, id = rng.table(tgts)
		table.remove(tgts, id)
		self.turn_procs.blade_flurry = true
		self:attackTarget(a, nil, t.getDamage(self,t), true)
	
	end,
	info = function(self, t)
		return ([[Become a whirling storm of blades, increasing attack speed by %d%% and causing melee attacks to strike an additional adjacent target other than your primary target for %d%% weapon damage. 
This talent is exhausting to use, draining 6 stamina each turn.]]):format(t.getSpeed(self, t)*100, t.getDamage(self,t)*100)
	end,
}

newTalent{
	name = "Snap",
	type = {"cunning/lethality",4},
	require = cuns_req4,
	points = 5,
	stamina = 50,
	cooldown = 50,
	tactical = { BUFF = 1 },
	fixed_cooldown = true,
	getTalentCount = function(self, t) return math.floor(self:combatTalentScale(t, 2, 7, "log")) end,
	getMaxLevel = function(self, t) return self:getTalentLevel(t) end,
	speed = "combat",
	action = function(self, t)
		local tids = {}
		for tid, _ in pairs(self.talents_cd) do
			local tt = self:getTalentFromId(tid)
			if not tt.fixed_cooldown then
				if tt.type[2] <= t.getMaxLevel(self, t) and (tt.type[1]:find("^cunning/") or tt.type[1]:find("^technique/")) then
					tids[#tids+1] = tid
				end
			end
		end
		for i = 1, t.getTalentCount(self, t) do
			if #tids == 0 then break end
			local tid = rng.tableRemove(tids)
			self.talents_cd[tid] = nil
		end
		self.changed = true
		return true
	end,
	info = function(self, t)
		local talentcount = t.getTalentCount(self, t)
		local maxlevel = t.getMaxLevel(self, t)
		return ([[Your quick wits allow you to reset the cooldown of up to %d of your combat talents (cunning or technique) of tier %d or less.]]):
		format(talentcount, maxlevel)
	end,
}
