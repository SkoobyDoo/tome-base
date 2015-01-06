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
		You now also use your Magic in place of Strength when equipping weapons, calculating weapon damage, and physical power.
		These bonuses override rather than stack with weapon mastery, knife mastery, and bow mastery.]]):
		format(damage, 100*inc)
	end,
}


newTalent{
	name = "Guardian Unity",
	type = {"chronomancy/guardian", 3},
	require = chrono_req3,
	points = 5,
	mode = "passive",
	getSplit = function(self, t) return paradoxTalentScale(self, t, 20, 50, 80)/100 end,
	getDuration = function(self, t) return getExtensionModifier(self, t, 2) end,
	getLifeTrigger = function(self, t) return self:combatTalentLimit(t, 10, 40, 24)	end,
	remove_on_clone = true,
	callbackOnHit = function(self, t, cb, src)
		local split = cb.value * t.getSplit(self, t)

		-- If we already split this turn pass damage to our clone
		if self.turn_procs.double_edge and self.turn_procs.double_edge ~= self and game.level:hasEntity(self.turn_procs.double_edge) then
			split = split/2
			-- split the damage
			game:delayedLogDamage(src, self.turn_procs.double_edge, split, ("#STEEL_BLUE#(%d shared)#LAST#"):format(split), nil)
			cb.value = cb.value - split
			self.turn_procs.double_edge:takeHit(split, src)
		end

		-- Do our split
		if self.max_life and cb.value >= self.max_life * (t.getLifeTrigger(self, t)/100) and not self.turn_procs.double_edge then
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
				self.turn_procs.double_edge = m
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
		This effect can only occur once per turn and the amount of damage split scales with your Spellpower.]]):format(trigger, split, split/2, duration)
	end,
}


	range = function(self, t)
		if self:hasArcheryWeapon("bow") then return util.getval(archery_range, self, t) end
		return 1
	end,
	is_melee = function(self, t) return not self:hasArcheryWeapon("bow") end,

			if not target or not self:canProject(tg, x, y) then return nil end
