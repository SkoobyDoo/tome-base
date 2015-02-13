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
		You now also use your Magic in place of Strength when equipping weapons and ammo as well as when calculating weapon damage.
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
	cooldown = 6,
	getDamageSplit = function(self, t) return self:combatTalentLimit(t, 80, 20, 50)/100 end,
	getDuration = function(self, t) return getExtensionModifier(self, t, 2) end,
	getLifeTrigger = function(self, t) return self:combatTalentLimit(t, 10, 30, 15)	end,
	remove_on_clone = true,
	callbackOnHit = function(self, t, cb, src)
		local split = cb.value * t.getDamageSplit(self, t)

		-- If we already have a guardian, split the damage
		if self.unity_warden and game.level:hasEntity(self.unity_warden) then
		
			game:delayedLogDamage(src, self.unity_warden, split, ("#STEEL_BLUE#(%d shared)#LAST#"):format(split), nil)
			cb.value = cb.value - split
			self.unity_warden:takeHit(split, src)
		
		-- Otherwise, summon a new Guardian
		elseif not self:isTalentCoolingDown(t) and self.max_life and cb.value >= self.max_life * (t.getLifeTrigger(self, t)/100) then
		
			-- Look for space first
			local tx, ty = util.findFreeGrid(self.x, self.y, 5, true, {[Map.ACTOR]=true})
			if tx and ty then
				-- Put the talent on cooldown
				self:startTalentCooldown(t)
				
				-- clone our caster
				local m = makeParadoxClone(self, self, t.getDuration(self, t))
				-- alter some values
				m.ai_state = { talent_in=1, ally_compassion=10 }
				m.remove_from_party_on_death = true
				m:attr("archery_pass_friendly", 1)
				m.generic_damage_penalty = 50
				m.on_die = function(self)
					local summoner = self.summoner
					if summoner.unity_warden then summoner.unity_warden = nil end
				end

				-- add our clone
				game.zone:addEntity(game.level, m, "actor", tx, ty)
				game.level.map:particleEmitter(tx, ty, 1, "temporal_teleport")

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
				self.unity_warden = m
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
		local split = t.getDamageSplit(self, t) * 100
		local duration = t.getDuration(self, t)
		local cooldown = self:getTalentCooldown(t)
		return ([[When a single hit deals more than %d%% of your maximum life another you appears and takes %d%% of the damage as well as %d%% of all damage you take for the next %d turns.
		The clone is out of phase with this reality and deals 50%% less damage but its arrows will pass through friendly targets.
		This talent has a cooldown.]]):format(trigger, split, split, duration)
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
		target:setEffect(target.EFF_WARDEN_S_TARGET, 10, {src=self, atk=t.getAttack(self, t), crit=t.getCrit(self, t)})
		
		game:playSoundNear(self, "talents/dispel")
		
		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local atk = t.getAttack(self, t)
		local crit = t.getCrit(self, t)
		return ([[For the next %d turns random targeting, such as from Blink Blade and Warden's Call, will focus on this target.
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
	getSense = function(self, t) return self:combatTalentStatDamage(t, "mag", 5, 25) end,
	getPower = function(self, t) return self:combatTalentLimit(t, 40, 10, 30) end, -- Limit < 40%
	passives = function(self, t, p)
		self:talentTemporaryValue(p, "see_stealth", t.getSense(self, t))
		self:talentTemporaryValue(p, "see_invisible", t.getSense(self, t))
	end,
	callbackOnStatChange = function(self, t, stat, v)
		if stat == self.STAT_MAG then
			self:updateTalentPassives(t)
		end
	end,
	callbackOnActBase = function(self, t)
		if rng.percent(t.getPower(self, t)) then
			if self:removeEffectsFilter({status="detrimental", ignore_crosstier=true}, 1) > 0 then
				game.logSeen(self, "#ORCHID#%s has recovered!#LAST#", self.name:capitalize())
			end
		end
	end,
	callbackOnTakeDamage = function(self, t, src, x, y, type, dam, tmp)
		local eff = self:hasEffect(self.EFF_WARDEN_S_FOCUS)
		if eff and dam > 0 and eff.target ~= src and src ~= self and (src.rank and src.rank < 3) then
			-- Reduce damage
			local reduction = dam * self:callTalent(self.T_VIGILANCE, "getPower")/100
			dam = dam -  reduction
			game:delayedLogDamage(src, self, 0, ("%s(%d vigilance)#LAST#"):format(DamageType:get(type).text_color or "#aaaaaa#", reduction), false)
		end
		return {dam=dam}
	end,
	info = function(self, t)
		local sense = t.getSense(self, t)
		local power = t.getPower(self, t)
		return ([[Improves your capacity to see invisible foes by +%d and to see through stealth by +%d.  Additionally you have a %d%% chance to recover from a single negative status effect each turn.
		While Warden's Focus is active you also take %d%% less damage from vermin and normal rank enemies, if they're not also your focus target.
		Sense abilities will scale with your Magic stat.]]):
		format(sense, sense, power, power)
	end,
}