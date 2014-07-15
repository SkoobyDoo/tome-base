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

-- EDGE TODO: Particles, Timed Effect Particles

newTalent{
	name = "Dimensional Step",
	type = {"chronomancy/spacetime-weaving", 1},
	require = chrono_req1,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 10,
	tactical = { CLOSEIN = 2, ESCAPE = 2 },
	range = function(self, t) return math.floor(self:combatTalentScale(t, 5, 9, 0.5, 0, 1)) end,
	requires_target = true,
	target = function(self, t)
		return {type="hit", nolock=true, range=self:getTalentRange(t)}
	end,
	direct_hit = true,
	no_energy = true,
	is_teleport = true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		if not self:hasLOS(x, y) or game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move") then -- To prevent teleporting through walls
			game.logSeen(self, "You do not have line of sight.")
			return nil
		end
		local _ _, x, y = self:canProject(tg, x, y)
		
		-- Swap?
		if self:getTalentLevel(t) >= 5 and target then
			-- Hit?
			if target:canBe("teleport") and self:checkHit(getParadoxSpellpower(self, t), target:combatSpellResist() + (target:attr("continuum_destabilization") or 0)) then
				-- Grab the caster's location
				local ox, oy = self.x, self.y
			
				-- Remove the target so the destination tile is empty
				game.level.map:remove(target.x, target.y, Map.ACTOR)
				
				-- Try to teleport to the target's old location
				if self:teleportRandom(x, y, 0) then
					-- Put the target back in the caster's old location
					game.level.map(ox, oy, Map.ACTOR, target)
					target.x, target.y = ox, oy
					
					game.level.map:particleEmitter(target.x, target.y, 1, "temporal_teleport")
					game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
				else
					-- If we can't teleport, return the target
					game.level.map(target.x, target.y, Map.ACTOR, target)
					game.logSeen(self, "The spell fizzles!")
				end
			else
				game.logSeen(target, "%s resists the swap!", target.name:capitalize())
			end
		else
			game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
			-- since we're using a precise teleport we'll look for a free grid first
			local tx, ty = util.findFreeGrid(x, y, 5, true, {[Map.ACTOR]=true})
			if tx and ty then
				if not self:teleportRandom(tx, ty, 0) then
					game.logSeen(self, "The spell fizzles!")
				else
					game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
				end
			end
		end
		
		game:playSoundNear(self, "talents/teleport")
		return true
	end,
	info = function(self, t)
		local range = self:getTalentRange(t)
		return ([[Teleports you to up to %d tiles away, to a targeted location in line of sight.
		At talent level 5 you may swap positions with a target creature.]]):format(range)
	end,
}

newTalent{
	name = "Dimensional Shift",
	type = {"chronomancy/spacetime-weaving", 2},
	mode = "passive",
	require = chrono_req2,
	points = 5,
	getReduction = function(self, t) return math.ceil(self:getTalentLevel(t)) end,
	getCount = function(self, t)
		return 1 + math.floor(self:combatTalentLimit(t, 3, 0, 2))
	end,
	doShift = function(self, t)
		local effs = {}
		for eff_id, p in pairs(self.tmp) do
			local e = self.tempeffect_def[eff_id]
			if e.type ~= "other" and e.status == "detrimental" and e.subtype ~= "cross tier" then
				effs[#effs+1] = p
			end
		end
		
		for i=1, t.getCount(self, t) do
			local eff = rng.tableRemove(effs)
			if not eff then break end
			eff.dur = eff.dur - t.getReduction(self, t)
			if eff.dur <= 0 then
				self:removeEffect(eff.effect_id)
			end
		end

	end,
	info = function(self, t)
		local count = t.getCount(self, t)
		local reduction = t.getReduction(self, t)
		return ([[When you teleport you reduce the duration of up to %d detrimental effects by %d turns.]]):
		format(count, reduction)
	end,
}

newTalent{
	name = "Phase Shift",
	type = {"chronomancy/spacetime-weaving", 3},
	require = chrono_req3,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 20) end,
	cooldown = 24,
	tactical = { DEFEND = 2 },
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentLimit(t, 25, 3, 7, true))) end,
	action = function(self, t)
		self:setEffect(self.EFF_PHASE_SHIFT, t.getDuration(self, t), {})
		game:playSoundNear(self, "talents/teleport")
		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		return ([[Phase shift yourself for %d turns; any damage greater than 10%% of your maximum life will teleport you to an adjacent tile and be reduced by 50%% (can only happen once per turn).]]):
		format(duration)
	end,
}

newTalent{
	name = "Phase Pulse",
	type = {"chronomancy/spacetime-weaving", 4},
	require = chrono_req4,
	tactical = { ATTACKAREA = {TEMPORAL = 1, PHYSICAL = 1} },
	mode = "sustained",
	sustain_paradox = 36,
	cooldown = 10,
	points = 5,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 15, 70, getParadoxSpellpower(self, t)) end,
	range = 0,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 1.5, 3.5)) end,
	target = function(self, t)
		return {type="ball", range=100, radius=self:getTalentRadius(t), selffire=false, talent=t}
	end,
	doPulse = function(self, t, ox, oy, fail)
		local tg = self:getTalentTarget(t)
		local dam = self:spellCrit(t.getDamage(self, t))
		local distance = core.fov.distance(self.x, self.y, ox, oy)
		local chance = distance * 10
		
		if not fail then
			dam = dam * (1 + math.min(1, distance/10))
			game:onTickEnd(function()
				self:project(tg, ox, oy, DamageType.WARP, dam)
				self:project(tg, self.x, self.y, DamageType.WARP, dam)
			end)
		else
			dam = dam *2
			chance = 100
			tg.radius = tg.radius * 2
			game:onTickEnd(function()
				self:project(tg, self.x, self.y, DamageType.WARP, dam)
			end)
		end
	end,
	activate = function(self, t)
		game:playSoundNear(self, "talents/spell_generic")
		return {}
	end,
	deactivate = function(self, t, p)
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)/2
		local radius = self:getTalentRadius(t)
		return ([[When you teleport with Phase Pulse active you deal %0.2f physical and %0.2f temporal (warp) damage to all targets in a radius of %d around you.
		For each space you move from your original location the damage is increased by 10%% (to a maximum bonus of 100%%).  If the teleport fails, the blast radius and damage will be doubled.
		This effect occurs both at the entrance and exist locations and the damage will scale with your Spellpower.]]):
		format(damDesc(self, DamageType.PHYSICAL, damage), damDesc(self, DamageType.TEMPORAL, damage), radius)
	end,
}
