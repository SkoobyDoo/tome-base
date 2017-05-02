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

newTalent{
	name = "Hymn of Shadows",
	type = {"celestial/hymns-hymns", 1},
	mode = "sustained",
	hide = true,
	require = divi_req1,
	points = 5,
	cooldown = 12,
	sustain_negative = 20,
	no_energy = true,
	dont_provide_pool = true,
	tactical = { BUFF = 2 },
	range = 0,
	moveSpeed = function(self, t) return self:combatTalentSpellDamage(t, 10, 40) end,
	castSpeed = function(self, t) return self:combatTalentSpellDamage(t, 5, 20) end,
	evade = function(self, t) return self:combatStatLimit(self:combatTalentSpellDamage(t, 10, 100), 50, 5, 25) end,
	callbackOnActBase = function(self, t)
		if self:isTalentActive(self.T_HYMN_NOCTURNALIST) then
			local t2 = self:getTalentFromId(self.T_HYMN_NOCTURNALIST)
			t2.do_beams(self, t2)
		end
	end,
	sustain_slots = 'celestial_hymn',
	activate = function(self, t)
		game:playSoundNear(self, "talents/spell_generic2")
		local ret = {}
		self:talentTemporaryValue(ret, "movement_speed", t.moveSpeed(self, t)/100)
		self:talentTemporaryValue(ret, "combat_spellspeed", t.castSpeed(self, t)/100)
		self:talentTemporaryValue(ret, "evasion", t.evade(self, t))
		ret.particle = self:addParticles(Particles.new("darkness_shield", 1))
		
		if self:knowTalent(self.T_HYMN_INCANTOR) then
			local t2 = self:getTalentFromId(self.T_HYMN_INCANTOR)
			self:talentTemporaryValue(ret, "on_melee_hit", {[DamageType.DARKNESS]=t2.getDamageOnMeleeHit(self, t2)})
			self:talentTemporaryValue(ret, "inc_damage", {[DamageType.DARKNESS] = t2.getDarkDamageIncrease(self, t2)})
		end
		
		if self:knowTalent(self.T_HYMN_ADEPT) then
			local t2 = self:getTalentFromId(self.T_HYMN_ADEPT)
			self:talentTemporaryValue(ret, "infravision", t2.getBonusInfravision(self, t2))
		end
		
		if self:isTalentActive(self.T_HYMN_NOCTURNALIST) then
			local t2 = self:getTalentFromId(self.T_HYMN_NOCTURNALIST)
			self:talentTemporaryValue(ret, "negative_regen", t2.getBonusRegen(self, t2))
			self:talentTemporaryValue(ret, "negative_regen_ref_mod", t2.getBonusRegen(self, t2))
		end
		
		return ret
	end,
	deactivate = function(self, t, p)
		self:removeParticles(p.particle)
		if self.turn_procs.resetting_talents then return true end
		
		if self:knowTalent(self.T_HYMN_ADEPT) then
			local t2 = self:getTalentFromId(self.T_HYMN_ADEPT)
			game:onTickEnd(function() self:setEffect(self.EFF_WILD_SPEED, 1, {power=t2.getSpeed(self, t2)}) end)
		end
		
		return true
	end,
	info = function(self, t)
		return ([[Chant the glory of the Moons, gaining the agility of shadows.
		This increases your movement speed by %d%%, your spell speed by %d%% and grant %d%% evasion.
		You may only have one Hymn active at once.
		The effects will increase with your Spellpower.]]):
		format(t.moveSpeed(self, t), t.castSpeed(self, t), t.evade(self, t))
	end,
}

newTalent{
	name = "Hymn of Detection",
	type = {"celestial/hymns-hymns", 1},
	mode = "sustained",
	hide = true,
	require = divi_req1,
	points = 5,
	cooldown = 12,
	sustain_negative = 20,
	no_energy = true,
	dont_provide_pool = true,
	tactical = { BUFF = 2 },
	range = 0,
	sustain_slots = 'celestial_hymn',
	getSeeInvisible = function(self, t) return self:combatTalentSpellDamage(t, 2, 25) end,
	getSeeStealth = function(self, t) return self:combatTalentSpellDamage(t, 2, 25) end,
	critPower = function(self, t) return self:combatTalentSpellDamage(t, 10, 50) end,
	callbackOnActBase = function(self, t)
		if self:isTalentActive(self.T_HYMN_NOCTURNALIST) then
			local t2 = self:getTalentFromId(self.T_HYMN_NOCTURNALIST)
			t2.do_beams(self, t2)
		end
	end,
	activate = function(self, t)
		game:playSoundNear(self, "talents/spell_generic2")
		local ret = {}
		self:talentTemporaryValue(ret, "see_invisible", t.getSeeInvisible(self, t))
		self:talentTemporaryValue(ret, "see_stealth", t.getSeeStealth(self, t))
		self:talentTemporaryValue(ret, "blindfight", 1)
		self:talentTemporaryValue(ret, "combat_critical_power", t.critPower(self, t))
		ret.particle = self:addParticles(Particles.new("darkness_shield", 1))
		
		if self:knowTalent(self.T_HYMN_INCANTOR) then
			local t2 = self:getTalentFromId(self.T_HYMN_INCANTOR)
			self:talentTemporaryValue(ret, "on_melee_hit", {[DamageType.DARKNESS]=t2.getDamageOnMeleeHit(self, t2)})
			self:talentTemporaryValue(ret, "inc_damage", {[DamageType.DARKNESS] = t2.getDarkDamageIncrease(self, t2)})
		end
		
		if self:knowTalent(self.T_HYMN_ADEPT) then
			local t2 = self:getTalentFromId(self.T_HYMN_ADEPT)
			self:talentTemporaryValue(ret, "infravision", t2.getBonusInfravision(self, t2))
		end
		
		if self:isTalentActive(self.T_HYMN_NOCTURNALIST) then
			local t2 = self:getTalentFromId(self.T_HYMN_NOCTURNALIST)
			self:talentTemporaryValue(ret, "negative_regen", t2.getBonusRegen(self, t2))
			self:talentTemporaryValue(ret, "negative_regen_ref_mod", t2.getBonusRegen(self, t2))
		end
		
		return ret
	end,
	deactivate = function(self, t, p)
		self:removeParticles(p.particle)
		if self.turn_procs.resetting_talents then return true end
		
		if self:knowTalent(self.T_HYMN_ADEPT) then
			local t2 = self:getTalentFromId(self.T_HYMN_ADEPT)
			self:setEffect(self.EFF_INVISIBILITY, t2.invisDur(self, t2), {power=t2.invisPower(self, t2), penalty=0.4})
		end
		
		return true
	end,
	info = function(self, t)
		local invis = t.getSeeInvisible(self, t)
		local stealth = t.getSeeStealth(self, t)
		return ([[Chant the glory of the Moons, granting you stealth detection (+%d power), and invisibility detection (+%d power). 
		You may also attack creatures you cannot see without penalty and your critical hits do %d%% more damage.
		You may only have one Hymn active at once.
		The stealth and invisibility detection will increase with your Spellpower.]]):
		format(stealth, invis, t.critPower(self, t))
	end,
}

newTalent{
	name = "Hymn of Perseverance",
	type = {"celestial/hymns-hymns",1},
	mode = "sustained",
	hide = true,
	require = divi_req1,
	points = 5,
	cooldown = 12,
	sustain_negative = 20,
	no_energy = true,
	dont_provide_pool = true,
	tactical = { BUFF = 2 },
	range = 10,
	getImmunities = function(self, t) return self:combatTalentLimit(t, 1, 0.16, 0.4) end, -- Limit < 100%
	callbackOnActBase = function(self, t)
		if self:isTalentActive(self.T_HYMN_NOCTURNALIST) then
			local t2 = self:getTalentFromId(self.T_HYMN_NOCTURNALIST)
			t2.do_beams(self, t2)
		end
	end,
	sustain_slots = 'celestial_hymn',
	activate = function(self, t)
		game:playSoundNear(self, "talents/spell_generic2")
		local ret = {}
		self:talentTemporaryValue(ret, "stun_immune", t.getImmunities(self, t))
		self:talentTemporaryValue(ret, "confusion_immune", t.getImmunities(self, t))
		self:talentTemporaryValue(ret, "blind_immune", t.getImmunities(self, t))
		ret.particle = self:addParticles(Particles.new("darkness_shield", 1))
		
		if self:knowTalent(self.T_HYMN_INCANTOR) then
			local t2 = self:getTalentFromId(self.T_HYMN_INCANTOR)
			self:talentTemporaryValue(ret, "on_melee_hit", {[DamageType.DARKNESS]=t2.getDamageOnMeleeHit(self, t2)})
			self:talentTemporaryValue(ret, "inc_damage", {[DamageType.DARKNESS] = t2.getDarkDamageIncrease(self, t2)})
		end
		
		if self:knowTalent(self.T_HYMN_ADEPT) then
			local t2 = self:getTalentFromId(self.T_HYMN_ADEPT)
			self:talentTemporaryValue(ret, "infravision", t2.getBonusInfravision(self, t2))
		end
		
		if self:isTalentActive(self.T_HYMN_NOCTURNALIST) then
			local t2 = self:getTalentFromId(self.T_HYMN_NOCTURNALIST)
			self:talentTemporaryValue(ret, "negative_regen", t2.getBonusRegen(self, t2))
			self:talentTemporaryValue(ret, "negative_regen_ref_mod", t2.getBonusRegen(self, t2))
		end
		
		return ret
	end,
	deactivate = function(self, t, p)
		self:removeParticles(p.particle)
		if self.turn_procs.resetting_talents then return true end

		if self:knowTalent(self.T_HYMN_ADEPT) then
			local t2 = self:getTalentFromId(self.T_HYMN_ADEPT)
			self:setEffect(self.EFF_DAMAGE_SHIELD, t2.shieldDur(self, t2), {power=t2.shieldPower(self, t2)})
		end
		
		return true
	end,
	info = function(self, t)
		local immunities = t.getImmunities(self, t)
		return ([[Chant the glory of the Moons, granting you %d%% stun, blindness and confusion resistance.
		You may only have one Hymn active at once.]]):
		format(100 * (immunities))
	end,
}

-- Depreciated, but retained for compatability.
newTalent{
	name = "Hymn of Moonlight",
	type = {"celestial/hymns-hymns",1},
	mode = "sustained",
	require = divi_req4,
	points = 5,
	cooldown = 12,
	sustain_negative = 20,
	no_energy = true,
	dont_provide_pool = true,
	tactical = { BUFF = 2 },
	range = 5,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 7, 80) end,
	getTargetCount = function(self, t) return math.floor(self:combatTalentScale(t, 1, 5)) end,
	getNegativeDrain = function(self, t) return self:combatTalentLimit(t, 0, 8, 3) end, -- Limit > 0, no regen at high levels
	callbackOnActBase = function(self, t)
		if self:getNegative() < t.getNegativeDrain(self, t) then return end

		local tgts = {}
		local grids = core.fov.circle_grids(self.x, self.y, 5, true)
		for x, yy in pairs(grids) do for y, _ in pairs(grids[x]) do
			local a = game.level.map(x, y, Map.ACTOR)
			if a and self:reactionToward(a) < 0 then
				tgts[#tgts+1] = a
			end
		end end

		local drain = t.getNegativeDrain(self, t)

		-- Randomly take targets
		local tg = {type="hit", range=self:getTalentRange(t), talent=t}
		for i = 1, t.getTargetCount(self, t) do
			if #tgts <= 0 then break end
			if self:getNegative() - 1 < drain then break end
			local a, id = rng.table(tgts)
			table.remove(tgts, id)

			self:project(tg, a.x, a.y, DamageType.DARKNESS, rng.avg(1, self:spellCrit(t.getDamage(self, t)), 3))
			game.level.map:particleEmitter(self.x, self.y, math.max(math.abs(a.x-self.x), math.abs(a.y-self.y)), "shadow_beam", {tx=a.x-self.x, ty=a.y-self.y})
			game:playSoundNear(self, "talents/spell_generic")
			self:incNegative(-drain)
		end
	end,
	sustain_slots = 'celestial_hymn',
	activate = function(self, t)
		game:playSoundNear(self, "talents/spell_generic")
		game.logSeen(self, "#DARK_GREY#A shroud of shadow dances around %s!", self.name)
		return {
		}
	end,
	deactivate = function(self, t, p)
		game.logSeen(self, "#DARK_GREY#The shroud of shadows around %s disappears.", self.name)
		return true
	end,
	info = function(self, t)
		local targetcount = t.getTargetCount(self, t)
		local damage = t.getDamage(self, t)
		local drain = t.getNegativeDrain(self, t)
		return ([[Chant the glory of the Moons, conjuring a shroud of dancing shadows that follows you as long as this spell is active.
		Each turn, a shadowy beam will hit up to %d of your foes within radius 5 for 1 to %0.2f damage.
		This powerful spell will drain %0.1f negative energy for each beam; no beam will fire if your negative energy is too low.
		You may only have one Hymn active at once.
		The damage will increase with your Spellpower.]]):
		format(targetcount, damDesc(self, DamageType.DARKNESS, damage), drain)
	end,
}

newTalent{
	name = "Hymn Acolyte",
	type = {"celestial/hymns", 1},
	require = divi_req1,
	points = 5,
	mode = "passive",
	passives = function(self, t)
		self:setTalentTypeMastery("celestial/hymns-hymns", self:getTalentMastery(t))
	end,
	on_learn = function(self, t)
		self:learnTalent(self.T_HYMN_OF_SHADOWS, true, nil, {no_unlearn=true})
		self:learnTalent(self.T_HYMN_OF_DETECTION, true, nil, {no_unlearn=true})
		self:learnTalent(self.T_HYMN_OF_PERSEVERANCE, true, nil, {no_unlearn=true})
	end,
	on_unlearn = function(self, t)
		self:unlearnTalent(self.T_HYMN_OF_SHADOWS)
		self:unlearnTalent(self.T_HYMN_OF_DETECTION)
		self:unlearnTalent(self.T_HYMN_OF_PERSEVERANCE)
	end,
	info = function(self, t)
		local ret = ""
		local old1 = self.talents[self.T_HYMN_OF_SHADOWS]
		local old2 = self.talents[self.T_HYMN_OF_DETECTION]
		local old3 = self.talents[self.T_HYMN_OF_PERSEVERANCE]
		self.talents[self.T_HYMN_OF_SHADOWS] = (self.talents[t.id] or 0)
		self.talents[self.T_HYMN_OF_DETECTION] = (self.talents[t.id] or 0)
		self.talents[self.T_HYMN_OF_PERSEVERANCE] = (self.talents[t.id] or 0)
		pcall(function() -- Be very paranoid, even if some addon or whatever manage to make that crash, we still restore values
			local t1 = self:getTalentFromId(self.T_HYMN_OF_SHADOWS)
			local t2 = self:getTalentFromId(self.T_HYMN_OF_DETECTION)
			local t3 = self:getTalentFromId(self.T_HYMN_OF_PERSEVERANCE)
			ret = ([[You have learned to sing the praises of the Moons, in the form of three defensive Hymns.
			Hymn of Shadows: Increases your movement speed by %d%%, your spell casting speed by %d%% and grants %d%% evasion.
			Hymn of Detection: Increases your ability to see stealthy creatures by %d and invisible creatures by %d, and increases your critical power by %d%%.
			Hymn of Perseverance: Increases your resistance to stun, confusion and blinding by %d%%.
			You may only have one Hymn active at a time.]]):
			format(t1.moveSpeed(self, t1), t1.castSpeed(self, t1), t1.evade(self, t1), t2.getSeeStealth(self, t2), t2.getSeeInvisible(self, t2), t2.critPower(self, t2), t3.getImmunities(self, t3)*100)
		end)
		self.talents[self.T_HYMN_OF_SHADOWS] = old1
		self.talents[self.T_HYMN_OF_DETECTION] = old2
		self.talents[self.T_HYMN_OF_PERSEVERANCE] = old3
		return ret
	end,
}

newTalent{
	name = "Hymn Incantor",
	type = {"celestial/hymns", 2},
	require = divi_req2,
	points = 5,
	mode = "passive",
	getDamageOnMeleeHit = function(self, t) return self:combatTalentSpellDamage(t, 5, 50) end,
	getDarkDamageIncrease = function(self, t) return self:combatTalentSpellDamage(t, 10, 30) end,
	info = function(self, t)
		return ([[Your Hymns now focus darkness near you, which increases your darkness damage by %d%% and does %0.2f darkness damage to anyone who hits you in melee.
		These values scale with your Spellpower.]]):format(t.getDarkDamageIncrease(self, t), damDesc(self, DamageType.DARKNESS, t.getDamageOnMeleeHit(self, t)))
	end,
}

-- Remember that Hymns can be swapped instantly.
newTalent{
	name = "Hymn Adept",
	type = {"celestial/hymns", 3},
	require = divi_req3,
	points = 5,
	mode = "passive",
	getBonusInfravision = function(self, t) return math.floor(self:combatTalentScale(t, 0.75, 3.5, 0.75)) end,
	getSpeed = function(self, t) return self:combatTalentSpellDamage(t, 300, 600) end,
	shieldDur = function(self, t) return self:combatTalentSpellDamage(t, 5, 10) end,
	shieldPower = function(self, t) return self:combatTalentSpellDamage(t, 50, 500) end,
	invisDur = function(self, t) return self:combatTalentSpellDamage(t, 5, 10) end,
	invisPower = function(self, t) return self:combatTalentSpellDamage(t, 20, 30) end,
	info = function(self, t)
		return ([[Your skill in Hymns now improves your sight in darkness, increasing your infravision radius by %d.
		Also, when you end a Hymn, you will gain a buff of a type based on which Hymn you ended.
		Hymn of Shadows increases your movement speed by %d%% for one turn.
		Hymn of Detection makes you invisible (power %d) for %d turns.
		Hymn of Perseverance grants a damage shield (power %d) for %d turns.]]):format(t.getBonusInfravision(self, t), t.getSpeed(self, t), 
			t.invisPower(self, t), t.invisDur(self, t), t.shieldPower(self, t), t.shieldDur(self, t))
	end,
}

newTalent{
	name = "Hymn Nocturnalist",
	type = {"celestial/hymns", 4},
	require = divi_req4,
	points = 5,
	mode = "sustained",
	cooldown = 10,
	sustain_negative = 5,
	range = 5,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 7, 80) end,
	getTargetCount = function(self, t) return math.floor(self:combatTalentScale(t, 1, 5)) end,
	getNegativeDrain = function(self, t) return self:combatTalentLimit(t, 0, 5, 3) end,
	getBonusRegen = function(self, t) return self:combatTalentScale(t, 0.7, 4.0, 0.75) / 10 end,
	callbackOnRest = function(self, t)
		if not self:knowTalent(self.T_NEGATIVE_POOL) then return false end
		if self.negative_regen > 0.1 and self.negative < self.max_negative then return true end
		return false
	end,
	do_beams = function(self, t)
		if self:getNegative() < t.getNegativeDrain(self, t) then return end

		local tgts = {}
		local grids = core.fov.circle_grids(self.x, self.y, 5, true)
		for x, yy in pairs(grids) do for y, _ in pairs(grids[x]) do
			local a = game.level.map(x, y, Map.ACTOR)
			if a and self:reactionToward(a) < 0 then
				tgts[#tgts+1] = a
			end
		end end

		if #tgts <= 0 then return end
		
		local drain = t.getNegativeDrain(self, t)
		local dam = rng.avg(1, self:spellCrit(t.getDamage(self, t)), 3)

		-- Randomly take targets
		local tg = {type="hit", range=self:getTalentRange(t), talent=t}
		for i = 1, t.getTargetCount(self, t) do
			if #tgts <= 0 then break end
			if self:getNegative() - 1 < drain then break end
			local a, id = rng.table(tgts)
			table.remove(tgts, id)

			self:project(tg, a.x, a.y, DamageType.DARKNESS_BLIND, dam)
			game.level.map:particleEmitter(self.x, self.y, math.max(math.abs(a.x-self.x), math.abs(a.y-self.y)), "shadow_beam", {tx=a.x-self.x, ty=a.y-self.y})
			game:playSoundNear(self, "talents/spell_generic")
			self:incNegative(-drain)
		end
	end,
	activate = function(self, t)
		game:onTickEnd(function()
			self.turn_procs.resetting_talents = true
			if self:isTalentActive(self.T_HYMN_OF_SHADOWS) then self:forceUseTalent(self.T_HYMN_OF_SHADOWS, {ignore_cooldown=true, ignore_energy=true}) self:forceUseTalent(self.T_HYMN_OF_SHADOWS, {ignore_energy=true, ignore_cd=true, no_talent_fail=true}) end
			if self:isTalentActive(self.T_HYMN_OF_PERSEVERANCE) then self:forceUseTalent(self.T_HYMN_OF_PERSEVERANCE, {ignore_cooldown=true, ignore_energy=true}) self:forceUseTalent(self.T_HYMN_OF_PERSEVERANCE, {ignore_energy=true, ignore_cd=true, no_talent_fail=true}) end
			if self:isTalentActive(self.T_HYMN_OF_DETECTION) then self:forceUseTalent(self.T_HYMN_OF_DETECTION, {ignore_cooldown=true, ignore_energy=true}) self:forceUseTalent(self.T_HYMN_OF_DETECTION, {ignore_energy=true, ignore_cd=true, no_talent_fail=true}) end
			self.turn_procs.resetting_talents = nil
		end)
		return {}
	end,
	deactivate = function(self, t, p)
		game:onTickEnd(function()
			self.turn_procs.resetting_talents = true
			if self:isTalentActive(self.T_HYMN_OF_SHADOWS) then self:forceUseTalent(self.T_HYMN_OF_SHADOWS, {ignore_cooldown=true, ignore_energy=true}) self:forceUseTalent(self.T_HYMN_OF_SHADOWS, {ignore_energy=true, ignore_cd=true, no_talent_fail=true}) end
			if self:isTalentActive(self.T_HYMN_OF_PERSEVERANCE) then self:forceUseTalent(self.T_HYMN_OF_PERSEVERANCE, {ignore_cooldown=true, ignore_energy=true}) self:forceUseTalent(self.T_HYMN_OF_PERSEVERANCE, {ignore_energy=true, ignore_cd=true, no_talent_fail=true}) end
			if self:isTalentActive(self.T_HYMN_OF_DETECTION) then self:forceUseTalent(self.T_HYMN_OF_DETECTION, {ignore_cooldown=true, ignore_energy=true}) self:forceUseTalent(self.T_HYMN_OF_DETECTION, {ignore_energy=true, ignore_cd=true, no_talent_fail=true}) end
			self.turn_procs.resetting_talents = nil
		end)
		return true
	end,
	info = function(self, t)
		return ([[Your passion for singing the praises of the Moons reaches its zenith, increasing your negative energy regeneration by %0.2f per turn.
		Your Hymns now fires shadowy beams that will hit up to %d of your foes within radius 5 for 1 to %0.2f damage, with a 20%% chance of blinding.
		This powerful effect will drain %0.1f negative energy for each beam; no beam will fire if your negative energy is too low.
		These values scale with your Spellpower.]]):format(t.getBonusRegen(self, t), t.getTargetCount(self, t), damDesc(self, DamageType.DARKNESS, t.getDamage(self, t)), t.getNegativeDrain(self, t))
	end,
}
