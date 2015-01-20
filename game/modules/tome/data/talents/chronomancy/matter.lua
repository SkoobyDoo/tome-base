-- ToME -  Tales of Maj'Eyal
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

newTalent{
	name = "Dust to Dust",
	type = {"chronomancy/matter",1},
	require = chrono_req1,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 3,
	tactical = { ATTACKAREA = {TEMPORAL = 1, PHYSICAL = 1} },
	range = 10,
	direct_hit = true,
	reflectable = true,
	requires_target = true,
	target = function(self, t)
		return {type="beam", range=self:getTalentRange(t), talent=t}
	end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 230, getParadoxSpellpower(self, t)) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		self:project(tg, x, y, DamageType.MATTER, self:spellCrit(t.getDamage(self, t)))
		local _ _, _, _, x, y = self:canProject(tg, x, y)
		game.level.map:particleEmitter(self.x, self.y, math.max(math.abs(x-self.x), math.abs(y-self.y)), "matter_beam", {tx=x-self.x, ty=y-self.y})
		game:playSoundNear(self, "talents/arcane")
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		return ([[Fires a beam that turns matter into dust, inflicting %0.2f temporal damage and %0.2f physical (warp) damage.
		The damage will scale with your Spellpower.]]):
		format(damDesc(self, DamageType.TEMPORAL, damage / 2), damDesc(self, DamageType.PHYSICAL, damage / 2))
	end,
}

newTalent{
	name = "Matter Weaving",
	type = {"chronomancy/matter",2},
	require = chrono_req2,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 3,
	tactical = { ATTACKAREA = {TEMPORAL = 1, PHYSICAL = 1} },
	range = 10,
	direct_hit = true,
	reflectable = true,
	requires_target = true,
	target = function(self, t)
		return {type="beam", range=self:getTalentRange(t), talent=t}
	end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 230, getParadoxSpellpower(self, t)) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		self:project(tg, x, y, DamageType.WARP, self:spellCrit(t.getDamage(self, t)))
		local _ _, _, _, x, y = self:canProject(tg, x, y)
		game.level.map:particleEmitter(self.x, self.y, math.max(math.abs(x-self.x), math.abs(y-self.y)), "matter_beam", {tx=x-self.x, ty=y-self.y})
		game:playSoundNear(self, "talents/arcane")
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		return ([[Fires a beam that turns matter into dust, inflicting %0.2f temporal damage and %0.2f physical (warp) damage.
		The damage will scale with your Spellpower.]]):
		format(damDesc(self, DamageType.TEMPORAL, damage / 2), damDesc(self, DamageType.PHYSICAL, damage / 2))
	end,
}

newTalent{
	name = "Materialize Barrier",
	type = {"chronomancy/matter",3},
	require = chrono_req3,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 3,
	tactical = { ATTACKAREA = {TEMPORAL = 1, PHYSICAL = 1} },
	range = 10,
	direct_hit = true,
	reflectable = true,
	requires_target = true,
	target = function(self, t)
		return {type="beam", range=self:getTalentRange(t), talent=t}
	end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 230, getParadoxSpellpower(self, t)) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		self:project(tg, x, y, DamageType.WARP, self:spellCrit(t.getDamage(self, t)))
		local _ _, _, _, x, y = self:canProject(tg, x, y)
		game.level.map:particleEmitter(self.x, self.y, math.max(math.abs(x-self.x), math.abs(y-self.y)), "matter_beam", {tx=x-self.x, ty=y-self.y})
		game:playSoundNear(self, "talents/arcane")
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		return ([[Fires a beam that turns matter into dust, inflicting %0.2f temporal damage and %0.2f physical (warp) damage.
		The damage will scale with your Spellpower.]]):
		format(damDesc(self, DamageType.TEMPORAL, damage / 2), damDesc(self, DamageType.PHYSICAL, damage / 2))
	end,
}

newTalent{
	name = "Disintegration",
	type = {"chronomancy/matter",4},
	require = chrono_req4,
	points = 5,
	sustain_paradox = 24,
	mode = "sustained",
	cooldown = 10,
	tactical = { BUFF = 2 },
	getDigs = function(self, t) return math.floor(self:combatTalentScale(t, 1, 5, "log")) end,
	getChance = function(self, t) return self:combatTalentLimit(t, 40, 10, 30) end, -- Limit < 40%end,
	doStrip = function(self, t, target, type)
		local what = type == "PHYSICAL" and "physical" or "magical"
		local p = self:isTalentActive(self.T_DISINTEGRATION)
		
		if what == "physical" and p.physical[target] then return end
		if what == "magical" and p.magical[target] then return end
		
		if rng.percent(t.getChance(self, t)) then
			local effs = {}
			-- Go through all spell effects
			for eff_id, p in pairs(target.tmp) do
				local e = target.tempeffect_def[eff_id]
				if e.type == what and e.status == "beneficial" then
					effs[#effs+1] = {"effect", eff_id}
				end
			end
	
			if #effs > 0 then
				local eff = rng.tableRemove(effs)
				if eff[1] == "effect" then
					target:removeEffect(eff[2])
					game.logSeen(self, "#CRIMSON#%s's beneficial effect was stripped!#LAST#", target.name:capitalize())
					if what == "physical" then p.physical[target] = true end
					if what == "magical" then p.magical[target] = true end
				end
			end
		end
	end,
	callbackOnActBase = function(self, t)
		-- reset our targets
		local p = self:isTalentActive(self.T_DISINTEGRATION)
		if p then
			p.physical = {}
			p.magical = {}
		end
	end,
	activate = function(self, t)
		return { physical = {}, magical ={}
		}
	end,
	deactivate = function(self, t, p)
		return true
	end,
	info = function(self, t)
		local digs = t.getDigs(self, t)
		local chance = t.getChance(self, t)
		return ([[While active your physical and temporal damage has a %d%% chance to remove one beneficial physical or magical effect (respectively) from targets you hit.
		Only one physical and one magical effect may be removed per turn from each target.
		Additionally your Dust to Dust spell now digs up to %d tiles into walls.]]):
		format(chance, digs)
	end,
}