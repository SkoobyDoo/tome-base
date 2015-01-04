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
	name = "Phase Shift",
	type = {"chronomancy/spacetime-weaving", 2},
	require = chrono_req2,
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
	name = "Dimensional Shift",
	type = {"chronomancy/spacetime-weaving", 3},
	mode = "passive",
	require = chrono_req3,
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
	name = "Banish",
	type = {"chronomancy/spacetime-weaving", 4},
	require = chrono_req4,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 10,
	tactical = { ESCAPE = 2 },
	range = 0,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 2.5, 5.5)) end,
	getTeleport = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(t), 8, 16)) end,
	target = function(self, t)
		return {type="ball", range=0, radius=self:getTalentRadius(t), selffire=false, talent=t}
	end,
	requires_target = true,
	direct_hit = true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local hit = false

		self:project(tg, self.x, self.y, function(px, py)
			local target = game.level.map(px, py, Map.ACTOR)
			if not target or target == self then return end
			game.level.map:particleEmitter(target.x, target.y, 1, "temporal_teleport")
			if self:checkHit(getParadoxSpellpower(self, t), target:combatSpellResist() + (target:attr("continuum_destabilization") or 0)) and target:canBe("teleport") then
				if not target:teleportRandom(target.x, target.y, self:getTalentRadius(t) * 4, self:getTalentRadius(t) * 2) then
					game.logSeen(target, "The spell fizzles on %s!", target.name:capitalize())
				else
					target:setEffect(target.EFF_CONTINUUM_DESTABILIZATION, 100, {power=getParadoxSpellpower(self, t, 0.3)})
					game.level.map:particleEmitter(target.x, target.y, 1, "temporal_teleport")
					hit = true
				end
			else
				game.logSeen(target, "%s resists the banishment!", target.name:capitalize())
			end
		end)
		
		if not hit then
			game:onTickEnd(function()
				if not self:attr("no_talents_cooldown") then
					self.talents_cd[self.T_BANISH] = self.talents_cd[self.T_BANISH] /2
				end
			end)
		end

		game:playSoundNear(self, "talents/teleport")

		return true
	end,
	info = function(self, t)
		local radius = self:getTalentRadius(t)
		local range = t.getTeleport(self, t)
		return ([[Randomly teleports all targets within a radius of %d around you.  Targets will be teleported between %d and %d tiles from their current location.
		If no targets are teleported the cooldown will be halved.
		The chance of teleportion will scale with your Spellpower.]]):format(radius, range / 2, range)
	end,
}