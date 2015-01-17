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
	name = "Strength of Purpose",
	type = {"chronomancy/guardian", 1},
	points = 5,
	require = { stat = { mag=function(level) return 12 + level * 6 end }, },
	mode = "passive",
	getDamage = function(self, t) return self:getTalentLevel(t) * 10 end,
	getPercentInc = function(self, t) return math.sqrt(self:getTalentLevel(t) / 5) / 2 end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local inc = t.getPercentInc(self, t)
		return ([[Increases Physical Power by %d, and increases weapon damage by %d%% when using swords, axes, maces, knives, or bows.
		You now also use your Magic in place of Strength when equipping weapons and ammo.
		These bonuses override rather than stack with weapon mastery, knife mastery, and bow mastery.]]):
		format(damage, 100*inc)
	end,
}

newTalent{
	name = "Guardian Unity",
	type = {"chronomancy/guardian", 2},
	require = chrono_req2,
	points = 5,
	mode = "passive",
	getSplit = function(self, t) return self:combatTalentLimit(t, 80, 20, 50)/100 end,
	getDuration = function(self, t) return getExtensionModifier(self, t, 2) end,
	getLifeTrigger = function(self, t) return self:combatTalentLimit(t, 10, 30, 15)	end,
	remove_on_clone = true,
	callbackOnHit = function(self, t, cb, src)
		local split = cb.value * t.getSplit(self, t)

		-- If we already split this turn pass damage to our clone
		if self.turn_procs.unity_warden and self.turn_procs.unity_warden ~= self and game.level:hasEntity(self.turn_procs.unity_warden) then
			split = split/2
			-- split the damage
			game:delayedLogDamage(src, self.turn_procs.unity_warden, split, ("#STEEL_BLUE#(%d shared)#LAST#"):format(split), nil)
			cb.value = cb.value - split
			self.turn_procs.unity_warden:takeHit(split, src)
		end

		-- Do our split
		if self.max_life and cb.value >= self.max_life * (t.getLifeTrigger(self, t)/100) and not self.turn_procs.unity_warden then
			-- Look for space first
			local tx, ty = util.findFreeGrid(self.x, self.y, 5, true, {[Map.ACTOR]=true})
			if tx and ty then
				game.level.map:particleEmitter(tx, ty, 1, "temporal_teleport")

				-- clone our caster
				local m = makeParadoxClone(self, self, t.getDuration(self, t))

				-- add our clone
				game.zone:addEntity(game.level, m, "actor", tx, ty)
				m.ai_state = { talent_in=2, ally_compassion=10 }
				m.remove_from_party_on_death = true
				m:attr("archery_pass_friendly", 1)
				m.generic_damage_penalty = 50

				if game.party:hasMember(self) then
					game.party:addMember(m, {
						control="no",
						type="temporal-clone",
						title="Guardian",
						orders = {target=true},
					})
				end

				-- split the damage
				cb.value = cb.value - split
				self.turn_procs.unity_warden = m
				m:takeHit(split, src)
				m:setTarget(src or nil)
				game:delayedLogMessage(self, nil, "guardian_damage", "#STEEL_BLUE##Source# shares damage with %s guardian!", string.his_her(self))
				game:delayedLogDamage(src or self, self, 0, ("#STEEL_BLUE#(%d shared)#LAST#"):format(split), nil)

			else
				game.logPlayer(self, "Not enough space to summon warden!")
			end
		end

		return cb.value
	end,
	info = function(self, t)
		local trigger = t.getLifeTrigger(self, t)
		local split = t.getSplit(self, t) * 100
		local duration = t.getDuration(self, t)
		return ([[When a single hit deals more than %d%% of your maximum life another you appears and takes %d%% of the damage as well as %d%% of all other damage you take for the rest of the turn.
		The clone is out of phase with this reality and deals 50%% less damage but its arrows will pass through friendly targets.  After %d turns it returns to its own timeline.
		This effect can only occur once per turn.]]):format(trigger, split, split/2, duration)
	end,
}

newTalent{
	name = "Warden's Focus", short_name=WARDEN_S_FOCUS,
	type = {"chronomancy/guardian", 3},
	require = chrono_req3,
	points = 5,
	cooldown = 6,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	tactical = { BUFF = 2 },
	direct_hit = true,
	requires_target = true,
	range = 10,
	no_energy = true,
	target = function (self, t)
		return {type="hit", range=self:getTalentRange(t), talent=t}
	end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 8, 16))) end,
	getAttack = function(self, t) return self:combatTalentSpellDamage(t, 10, 100, getParadoxSpellpower(self, t)) end,
	getCrit = function(self, t) return self:combatTalentSpellDamage(t, 5, 50, getParadoxSpellpower(self, t)) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local tx, ty = self:getTarget(tg)
		if not tx or not ty then return nil end
		local _ _, tx, ty = self:canProject(tg, tx, ty)
		local target = game.level.map(tx, ty, Map.ACTOR)
		if not target then return end
		
		self:setEffect(self.EFF_WARDEN_S_FOCUS, t.getDuration(self, t), {target=target, atk=t.getAttack(self, t), crit=t.getCrit(self, t)})
		
		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local atk = t.getAttack(self, t)
		local crit = t.getCrit(self, t)
		return ([[Activate to focus fire on the target.  For the next %d turns most of your ranged weapon attacks will automatically aim at this target, as well as Temporal Assault teleports and Blended Threads clones.
		Additionally you gain +%d accuracy and +%d%% critical hit rate when attacking this target.
		The accuracy and critical hit rate bonuses will scale with your Spellpower.]])
		:format(duration, atk, crit)
	end
}

newTalent{
	name = "Vigilance",
	type = {"chronomancy/guardian", 4},
	require = chrono_req4,
	points = 5,
	mode = "passive",
	getEnergy = function(self, t) return self:combatTalentLimit(t, 300, 50, 200) end,
	gainEnergy = function(self, t)
		if not self.turn_procs.vigilance then
			self.turn_procs.vigilance = true
			self.energy.value = self.energy.value + t.getEnergy(self, t)
		end
	end,
	callbackOnArcheryMiss = function(self, t)
		self:callTalent(self.T_VIGILANCE, "gainEnergy")
	end,
	callbackOnMeleeMiss = function(self, t)
		self:callTalent(self.T_VIGILANCE, "gainEnergy")
	end,
	info = function(self, t)
		local energy = t.getEnergy(self, t)/10
		return ([[When a melee or ranged attack misses you or you shrug off a critical hit you gain %d%% of a turn.
		This effect can only occur once per turn.]]):format(energy)
	end,
}