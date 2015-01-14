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

-- Paradox Functions

-- Paradox modifier.  This dictates paradox cost and spellpower scaling
-- Note that 300 is the optimal balance
-- Caps at -50% and +50%
getParadoxModifier = function (self)
	local paradox = self:getParadox()
	local pm = util.bound(math.sqrt(paradox / 300), 0.5, 1.5)
	return pm
end

-- Paradox cost (regulates the cost of paradox talents)
getParadoxCost = function (self, t, value)
	local pm = getParadoxModifier(self)
	return value * pm
end

-- Paradox Spellpower (regulates spellpower for chronomancy)
getParadoxSpellpower = function(self, t, mod, add)
	local pm = getParadoxModifier(self)
	local mod = mod or 1

	-- Empower?
	local p = self:isTalentActive(self.T_EMPOWER)
	if p and p.talent == t.id then
		pm = pm + self:callTalent(self.T_EMPOWER, "getPower")
	end

	local spellpower = self:combatSpellpower(mod * pm, add)
	return spellpower
end

-- Paradox Talent scaling based on Spellpower (thanks grayswandir)
paradoxTalentScale = function(self, t, low, high, limit)
        local low_power = 50
        local high_power = 150
        return self:combatLimit(
                self:combatTalentSpellDamage(t, low_power, high_power, getParadoxSpellpower(self, t)),
                limit,
                low, low_power,
                high, high_power)
end

-- Extension Spellbinding
getExtensionModifier = function(self, t, value)
	local mod = 1
	local p = self:isTalentActive(self.T_EXTENSION)
	if p and p.talent == t.id then
		mod = mod + self:callTalent(self.T_EXTENSION, "getPower")
	end
	value = math.ceil(value * mod)
	return value
end

--- Warden weapon functions
-- Checks for weapons in main and quickslot
doWardenPreUse = function(self, weapon, silent)
	if weapon == "bow" then
		if not self:hasArcheryWeapon("bow") and not self:hasArcheryWeaponQS("bow") then
			return false
		end
	end
	if weapon == "dual" then
		if not self:hasDualWeapon() and not self:hasDualWeaponQS() then
			return false
		end
	end
	return true
end

-- Swaps weapons if needed
doWardenWeaponSwap = function(self, t, dam, type)
	local swap = false
	local dam = dam or 0
	local warden_weapon

	if t.type[1]:find("^chronomancy/blade") or type == "blade" then
		local mainhand, offhand = self:hasDualWeapon()
		if not mainhand then
			swap = true
			warden_weapon = "blade"
		end
	end
	if t.type[1]:find("^chronomancy/bow") or type == "bow" then
		if not self:hasArcheryWeapon("bow") then
			swap = true
			warden_weapon = "bow"
		end
	end
	if swap == true then
		local old_inv_access = self.no_inventory_access				-- Make sure clones can swap
		self.no_inventory_access = nil
		self:quickSwitchWeapons(true, "warden")
		self.no_inventory_access = old_inv_access

		if self:knowTalent(self.T_BLENDED_THREADS) then
			if not self.turn_procs.blended_threads then
				self.turn_procs.blended_threads = warden_weapon
			end
			if self.turn_procs.blended_threads == warden_weapon then
				dam = dam * (1 + self:callTalent(self.T_BLENDED_THREADS, "getPercent"))
			end
		end
	end
	return dam, swap
end

-- Spell functions
makeParadoxClone = function(self, target, duration)
	local m = target:cloneFull{
		shader = "shadow_simulacrum",
		shader_args = { color = {0.6, 0.6, 0.2}, base = 0.8, time_factor = 1500 },
		no_drops = true,
		faction = target.faction,
		summoner = target, summoner_gain_exp=true,
		summon_time = duration,
		ai_target = {actor=nil},
		ai = "summoned", ai_real = "tactical",
		name = ""..target.name.."'s temporal clone",
		desc = [[A creature from another timeline.]],
	}
	m:removeAllMOs()
	m.make_escort = nil
	m.on_added_to_level = nil
	m.on_added = nil

	mod.class.NPC.castAs(m)
	engine.interface.ActorAI.init(m, m)

	m.exp_worth = 0
	m.energy.value = 0
	m.player = nil
	m.max_life = m.max_life
	m.life = util.bound(m.life, 0, m.max_life)
	m.forceLevelup = function() end
	m.on_die = nil
	m.die = nil
	m.puuid = nil
	m.on_acquire_target = nil
	m.no_inventory_access = true
	m.no_levelup_access = true
	m.on_takehit = nil
	m.seen_by = nil
	m.can_talk = nil
	m.clone_on_hit = nil
	m.self_resurrect = nil
	m.escort_quest = nil
	m.unused_talents = 0
	m.unused_generics = 0
	if m.talents.T_SUMMON then m.talents.T_SUMMON = nil end
	if m.talents.T_MULTIPLY then m.talents.T_MULTIPLY = nil end

	-- Clones never flee because they're awesome
	m.ai_tactic = m.ai_tactic or {}
	m.ai_tactic.escape = 0

	-- Remove some talents
	local tids = {}
	for tid, _ in pairs(m.talents) do
		local t = m:getTalentFromId(tid)
		if (t.no_npc_use and not t.allow_temporal_clones) or t.remove_on_clone then tids[#tids+1] = t end
	end
	for i, t in ipairs(tids) do
		if t.mode == "sustained" and m:isTalentActive(t.id) then m:forceUseTalent(t.id, {ignore_energy=true, silent=true}) end
		m:unlearnTalentFull(t.id)
	end

	-- remove timed effects
	local effs = {}
	for eff_id, p in pairs(m.tmp) do
		local e = m.tempeffect_def[eff_id]
		effs[#effs+1] = {"effect", eff_id}
	end

	while #effs > 0 do
		local eff = rng.tableRemove(effs)
		if eff[1] == "effect" then
			m:removeEffect(eff[2])
		end
	end
	return m
end

-- Make sure we don't run concurrent chronoworlds; to prevent lag and possible game breaking bugs or exploits
checkTimeline = function(self)
	if game._chronoworlds  == nil then
		return false
	else
		return true
	end
end

-- Misc. Paradox Talents
newTalent{
	name = "Spacetime Tuning",
	type = {"chronomancy/other", 1},
	points = 1,
	tactical = { PARADOX = 2 },
	no_npc_use = true,
	no_unlearn_last = true,
	on_learn = function(self, t)
		if not self.preferred_paradox then self.preferred_paradox = 300 end
	end,
	on_unlearn = function(self, t)
		if self.preferred_paradox then self.preferred_paradox = nil end
	end,
	getDuration = function(self, t)
		local power = math.floor(self:combatSpellpower()/10)
		return math.max(20 - power, 10)
	end,
	action = function(self, t)
		local function getQuantity(title, prompt, default, min, max)
			local result
			local co = coroutine.running()

			local dialog = engine.dialogs.GetQuantity.new(
				title,
				prompt,
				default,
				max,
				function(qty)
					result = qty
					coroutine.resume(co)
				end,
				min)
			dialog.unload = function(dialog)
				if not dialog.qty then coroutine.resume(co) end
			end

			game:registerDialog(dialog)
			coroutine.yield()
			return result
		end

		local paradox = getQuantity(
			"Spacetime Tuning",
			"What's your preferred paradox level?",
			math.floor(self.paradox))
		if not paradox then return end
		if paradox > 1000 then paradox = 1000 end
		self.preferred_paradox = paradox
		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local preference = self.preferred_paradox
		local spellpower = getParadoxSpellpower(self, t)
		local after_will, will_modifier, sustain_modifier = self:getModifiedParadox()
		local anomaly = self:paradoxFailChance()
		return ([[Use to set your preferred Paradox.  While resting or waiting you'll adjust your Paradox towards this number over %d turns.
		The time it takes you to adjust your Paradox scales down with your Spellpower to a minimum of 10 turns.

		Preferred Paradox          :  %d
		Spellpower for Chronomancy :  %d
		Willpower Paradox Modifier : -%d
		Paradox Sustain Modifier   : +%d
		Total Modifed Paradox      :  %d
		Current Anomaly Chance     :  %d%%]]):format(duration, preference, spellpower, will_modifier, sustain_modifier, after_will, anomaly)
	end,
}

-- Talents from older versions to keep save files compatable
newTalent{
	name = "Stop",
	type = {"chronomancy/other",1},
	require = chrono_req1,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 20) end,
	cooldown = 12,
	tactical = { ATTACKAREA = 1, DISABLE = 3 },
	range = 6,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 1.3, 2.7)) end,
	direct_hit = true,
	requires_target = true,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), selffire=self:spellFriendlyFire(), talent=t}
	end,
	getDuration = function(self, t) return math.ceil(self:combatTalentScale(self:getTalentLevel(t), 2.3, 4.3)) end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 170, getParadoxSpellpower(self, t)) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, _, _, x, y = self:canProject(tg, x, y)
		local grids = self:project(tg, x, y, DamageType.STOP, t.getDuration(self, t))
		self:project(tg, x, y, DamageType.TEMPORAL, self:spellCrit(t.getDamage(self, t)))

		game.level.map:particleEmitter(x, y, tg.radius, "temporal_flash", {radius=tg.radius, tx=x, ty=y})
		game:playSoundNear(self, "talents/tidalwave")
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local radius = self:getTalentRadius(t)
		local duration = t.getDuration(self, t)
		return ([[Inflicts %0.2f temporal damage, and attempts to stun all creatures in a radius %d ball for %d turns.
		The damage will scale with your Spellpower.]]):
		format(damage, radius, duration)
	end,
}

newTalent{
	name = "Slow",
	type = {"chronomancy/other", 1},
	require = chrono_req1,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 30) end,
	cooldown = 24,
	tactical = { ATTACKAREA = {TEMPORAL = 2}, DISABLE = 2 },
	range = 6,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 2.25, 3.25))	end,
	direct_hit = true,
	requires_target = true,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t)}
	end,
	getSlow = function(self, t) return math.min(10 + self:combatTalentSpellDamage(t, 10, 50, getParadoxSpellpower(self, t))/ 100 , 0.6) end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 60, getParadoxSpellpower(self, t)) end,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(t, 6, 10)) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, _, _, x, y = self:canProject(tg, x, y)
		-- Add a lasting map effect
		game.level.map:addEffect(self,
			x, y, t.getDuration(self, t),
			DamageType.CHRONOSLOW, {dam=t.getDamage(self, t), slow=t.getSlow(self, t)},
			self:getTalentRadius(t),
			5, nil,
			{type="temporal_cloud"},
			nil, self:spellFriendlyFire()
		)
		game:playSoundNear(self, "talents/teleport")
		return true
	end,
	info = function(self, t)
		local slow = t.getSlow(self, t)
		local damage = t.getDamage(self, t)
		local radius = self:getTalentRadius(t)
		local duration = t.getDuration(self, t)
		return ([[Creates a time distortion in a radius of %d that lasts for %d turns, decreasing global speed by %d%% for 3 turns and inflicting %0.2f temporal damage each turn to all targets within the area.
		The slow effect and damage dealt will scale with your Spellpower.]]):
		format(radius, duration, 100 * slow, damDesc(self, DamageType.TEMPORAL, damage))
	end,
}

newTalent{
	name = "Spacetime Mastery",
	type = {"chronomancy/other", 1},
	mode = "passive",
	require = chrono_req1,
	points = 5,
	getPower = function(self, t) return math.max(0, self:combatTalentLimit(t, 1, 0.15, 0.5)) end, -- Limit < 100%
	cdred = function(self, t, scale) return math.floor(scale*self:combatTalentLimit(t, 0.8, 0.1, 0.5)) end, -- Limit < 80% of cooldown
	passives = function(self, t, p)
		self:talentTemporaryValue(p, "talent_cd_reduction", {[self.T_BANISH] = t.cdred(self, t, 10)})
		self:talentTemporaryValue(p, "talent_cd_reduction", {[self.T_DIMENSIONAL_STEP] = t.cdred(self, t, 10)})
		self:talentTemporaryValue(p, "talent_cd_reduction", {[self.T_SWAP] = t.cdred(self, t, 10)})
		self:talentTemporaryValue(p, "talent_cd_reduction", {[self.T_TEMPORAL_WAKE] = t.cdred(self, t, 10)})
		self:talentTemporaryValue(p, "talent_cd_reduction", {[self.T_WORMHOLE] = t.cdred(self, t, 20)})
	end,
	info = function(self, t)
		local cooldown = t.cdred(self, t, 10)
		local wormhole = t.cdred(self, t, 20)
		return ([[Your mastery of spacetime reduces the cooldown of Banish, Dimensional Step, Swap, and Temporal Wake by %d, and the cooldown of Wormhole by %d.  Also improves your Spellpower for purposes of hitting targets with chronomancy effects that may cause continuum destabilization (Banish, Time Skip, etc.), as well as your chance of overcoming continuum destabilization, by %d%%.]]):
		format(cooldown, wormhole, t.getPower(self, t)*100)

	end,
}

newTalent{
	name = "Static History",
	type = {"chronomancy/other", 1},
	require = chrono_req1,
	points = 5,
	message = "@Source@ rearranges history.",
	cooldown = 24,
	tactical = { PARADOX = 2 },
	getDuration = function(self, t)
		local duration = math.floor(self:combatTalentScale(t, 1.5, 3.5))
		if self:knowTalent(self.T_PARADOX_MASTERY) then
			duration = duration + self:callTalent(self.T_PARADOX_MASTERY, "stabilityDuration")
		end
		return duration
	end,
	getReduction = function(self, t) return self:combatTalentSpellDamage(t, 20, 200) end,
	action = function(self, t)
		self:incParadox (- t.getReduction(self, t))
		game:playSoundNear(self, "talents/spell_generic")
		self:setEffect(self.EFF_SPACETIME_STABILITY, t.getDuration(self, t), {})
		return true
	end,
	info = function(self, t)
		local reduction = t.getReduction(self, t)
		local duration = t.getDuration(self, t)
		return ([[By slightly reorganizing history, you reduce your Paradox by %d and temporarily stabilize the timeline; this allows chronomancy to be used without chance of failure for %d turns (backfires and anomalies may still occur).
		The paradox reduction will increase with your Spellpower.]]):
		format(reduction, duration)
	end,
}

newTalent{
	name = "Quantum Feed",
	type = {"chronomancy/other", 1},
	require = chrono_req1,
	mode = "sustained",
	points = 5,
	sustain_paradox = 20,
	cooldown = 18,
	tactical = { BUFF = 2 },
	getPower = function(self, t) return self:combatTalentScale(t, 1.5, 7.5, 0.75) + self:combatTalentStatDamage(t, "wil", 5, 20) end,
	activate = function(self, t)
		game:playSoundNear(self, "talents/arcane")
		return {
			stats = self:addTemporaryValue("inc_stats", {[self.STAT_MAG] = t.getPower(self, t)}),
			spell = self:addTemporaryValue("combat_spellresist", t.getPower(self, t)),
			particle = self:addParticles(Particles.new("arcane_power", 1)),
		}
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("inc_stats", p.stats)
		self:removeTemporaryValue("combat_spellresist", p.spell)
		self:removeParticles(p.particle)
		return true
	end,
	info = function(self, t)
		local power = t.getPower(self, t)
		return ([[You've learned to boost your magic through your control over the spacetime continuum.  Increases your Magic and your Spell Save by %d.
		The effect will scale with your Willpower.]]):format(power)
	end
}

newTalent{
	name = "Moment of Prescience",
	type = {"chronomancy/other", 1},
	require = chrono_req1,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 20) end,
	cooldown = 18,
	getDuration = function(self, t) return math.floor(self:combatTalentLimit(t, 18, 3, 10.5)) end, -- Limit < 18
	getPower = function(self, t) return self:combatTalentScale(t, 4, 15) end, -- Might need a buff
	tactical = { BUFF = 4 },
	no_energy = true,
	no_npc_use = true,
	action = function(self, t)
		local power = t.getPower(self, t)
		-- check for Spin Fate
		local eff = self:hasEffect(self.EFF_SPIN_FATE)
		if eff then
			local bonus = math.max(0, (eff.cur_save_bonus or eff.save_bonus) / 2)
			power = power + bonus
		end

		self:setEffect(self.EFF_PRESCIENCE, t.getDuration(self, t), {power=power})
		return true
	end,
	info = function(self, t)
		local power = t.getPower(self, t)
		local duration = t.getDuration(self, t)
		return ([[You pull your awareness fully into the moment, increasing your stealth detection, see invisibility, defense, and accuracy by %d for %d turns.
		If you have Spin Fate active when you cast this spell, you'll gain a bonus to these values equal to 50%% of your spin.
		This spell takes no time to cast.]]):
		format(power, duration)
	end,
}

newTalent{
	name = "Gather the Threads",
	type = {"chronomancy/other", 1},
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 12,
	tactical = { BUFF = 2 },
	getThread = function(self, t) return self:combatTalentScale(t, 7, 30, 0.75) end,
	getReduction = function(self, t) return self:combatTalentScale(t, 3.6, 15, 0.75) end,
	action = function(self, t)
		self:setEffect(self.EFF_GATHER_THE_THREADS, 5, {power=t.getThread(self, t), reduction=t.getReduction(self, t)})
		game:playSoundNear(self, "talents/spell_generic2")
		return true
	end,
	info = function(self, t)
		local primary = t.getThread(self, t)
		local reduction = t.getReduction(self, t)
		return ([[You begin to gather energy from other timelines. Your Spellpower will increase by %0.2f on the first turn and %0.2f more each additional turn.
		The effect ends either when you cast a spell, or after five turns.
		Eacn turn the effect is active, your Paradox will be reduced by %d.
		This spell will not break Spacetime Tuning, nor will it be broken by activating Spacetime Tuning.]]):format(primary + (primary/5), primary/5, reduction)
	end,
}

newTalent{
	name = "Entropic Field",
	type = {"chronomancy/other",1},
	mode = "sustained",
	points = 5,
	sustain_paradox = 20,
	cooldown = 10,
	tactical = { BUFF = 2 },
	getPower = function(self, t) return math.min(90, 10 +  self:combatTalentSpellDamage(t, 10, 50, getParadoxSpellpower(self, t))) end,
	activate = function(self, t)
		game:playSoundNear(self, "talents/heal")
		return {
			particle = self:addParticles(Particles.new("time_shield", 1)),
			phys = self:addTemporaryValue("resists", {[DamageType.PHYSICAL]=t.getPower(self, t)/2}),
			proj = self:addTemporaryValue("slow_projectiles", t.getPower(self, t)),
		}
	end,
	deactivate = function(self, t, p)
		self:removeParticles(p.particle)
		self:removeTemporaryValue("resists", p.phys)
		self:removeTemporaryValue("slow_projectiles", p.proj)
		return true
	end,
	info = function(self, t)
		local power = t.getPower(self, t)
		return ([[You encase yourself in a field that slows incoming projectiles by %d%%, and increases your physical resistance by %d%%.
		The effect will scale with your Spellpower.]]):format(power, power / 2)
	end,
}

newTalent{
	name = "Fade From Time",
	type = {"chronomancy/other", 1},
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 20) end,
	cooldown = 24,
	tactical = { DEFEND = 2, CURE = 2 },
	getResist = function(self, t) return self:combatTalentSpellDamage(t, 10, 50, getParadoxSpellpower(self, t)) end,
	getdurred = function(self, t) return self:combatLimit(self:combatTalentSpellDamage(t, 10, 50, getParadoxSpellpower(self, t)), 100, 0, 0, 32.9, 32.9) end, -- Limit < 100%
	action = function(self, t)
		-- fading managed by FADE_FROM_TIME effect in mod.data.timed_effects.other.lua
		self:setEffect(self.EFF_FADE_FROM_TIME, 10, {power=t.getResist(self, t), durred=t.getdurred(self,t)})
		game:playSoundNear(self, "talents/heal")
		return true
	end,
	info = function(self, t)
		local resist = t.getResist(self, t)
		local dur = t.getdurred(self,t)
		return ([[You partially remove yourself from the timeline for 10 turns.
		This increases your resistance to all damage by %d%%, reduces the duration of all detrimental effects on you by %d%%, and reduces all damage you deal by 20%%.
		The resistance bonus, effect reduction, and damage penalty will gradually lose power over the duration of the spell.
		The effects scale with your Spellpower.]]):
		format(resist, dur)
	end,
}

newTalent{
	name = "Paradox Clone",
	type = {"chronomancy/other", 1},
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 50) end,
	cooldown = 50,
	tactical = { ATTACK = 1, DISABLE = 2 },
	range = 2,
	requires_target = true,
	no_npc_use = true,
	getDuration = function(self, t)	return math.floor(self:combatTalentLimit(self:getTalentLevel(t), 50, 4, 8)) end, -- Limit <50
	getModifier = function(self, t) return rng.range(t.getDuration(self,t)*2, t.getDuration(self, t)*4) end,
	action = function (self, t)
		if checkTimeline(self) == true then
			return
		end

		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, talent=t}
		local tx, ty = self:getTarget(tg)
		if not tx or not ty then return nil end
		local _ _, tx, ty = self:canProject(tg, tx, ty)
		if not tx or not ty then return nil end

		local x, y = util.findFreeGrid(tx, ty, 2, true, {[Map.ACTOR]=true})
		if not x then
			game.logPlayer(self, "Not enough space to summon!")
			return
		end

		local sex = game.player.female and "she" or "he"
		local m = require("mod.class.NPC").new(self:cloneFull{
			no_drops = true,
			faction = self.faction,
			summoner = self, summoner_gain_exp=true,
			exp_worth = 0,
			summon_time = t.getDuration(self, t),
			ai_target = {actor=nil},
			ai = "summoned", ai_real = "tactical",
			ai_tactic = resolvers.tactic("ranged"), ai_state = { talent_in=1, ally_compassion=10},
			desc = [[The real you... or so ]]..sex..[[ says.]]
		})
		m:removeAllMOs()
		m.make_escort = nil
		m.on_added_to_level = nil

		m.energy.value = 0
		m.player = nil
		m.puuid = nil
		m.max_life = m.max_life
		m.life = util.bound(m.life, 0, m.max_life)
		m.forceLevelup = function() end
		m.die = nil
		m.on_die = nil
		m.on_acquire_target = nil
		m.seen_by = nil
		m.can_talk = nil
		m.on_takehit = nil
		m.no_inventory_access = true
		m.clone_on_hit = nil
		m.remove_from_party_on_death = true

		-- Remove some talents
		local tids = {}
		for tid, _ in pairs(m.talents) do
			local t = m:getTalentFromId(tid)
			if t.no_npc_use then tids[#tids+1] = t end
		end
		for i, t in ipairs(tids) do
			m.talents[t.id] = nil
		end

		game.zone:addEntity(game.level, m, "actor", x, y)
		game.level.map:particleEmitter(x, y, 1, "temporal_teleport")
		game:playSoundNear(self, "talents/teleport")

		if game.party:hasMember(self) then
			game.party:addMember(m, {
				control="no",
				type="minion",
				title="Paradox Clone",
				orders = {target=true},
			})
		end

		self:setEffect(self.EFF_IMMINENT_PARADOX_CLONE, t.getDuration(self, t) + t.getModifier(self, t), {})
		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		return ([[You summon your future self to fight alongside you for %d turns.  At some point in the future, you'll be pulled into the past to fight alongside your past self after the initial effect ends.
		This spell splits the timeline.  Attempting to use another spell that also splits the timeline while this effect is active will be unsuccessful.]]):format(duration)
	end,
}

newTalent{
	name = "Displace Damage",
	type = {"chronomancy/other", 1},
	mode = "sustained",
	require = chrono_req1,
	sustain_paradox = 48,
	cooldown = 10,
	tactical = { BUFF = 2 },
	points = 5,
	-- called by _M:onTakeHit function in mod\class\Actor.lua to perform the damage displacment
	getDisplaceDamage = function(self, t) return self:combatTalentLimit(t, 25, 5, 15)/100 end, -- Limit < 25%
	range = 10,
	callbackOnTakeDamage = function(self, t, src, x, y, type, dam, tmp)
		if dam > 0 and src ~= self then
			-- find available targets
			local tgts = {}
			local grids = core.fov.circle_grids(self.x, self.y, self:getTalentRange(t), true)
			for x, yy in pairs(grids) do for y, _ in pairs(grids[x]) do
				local a = game.level.map(x, y, Map.ACTOR)
				if a and self:reactionToward(a) < 0 then
					tgts[#tgts+1] = a
				end
			end end

			-- Displace the damage
			local a = rng.table(tgts)
			if a then
				local displace = dam * t.getDisplaceDamage(self, t)
				game:delayedLogMessage(self, a, "displace_damage"..(a.uid or ""), "#PINK##Source# displaces some damage onto #Target#!")
				DamageType.defaultProjector(self, a.x, a.y, type, displace, tmp, true)
				dam = dam - displace
			end
		end

		return {dam=dam}
	end,
	activate = function(self, t)
		return {}
	end,
	deactivate = function(self, t, p)
		return true
	end,
	info = function(self, t)
		local displace = t.getDisplaceDamage(self, t) * 100
		return ([[You bend space around you, displacing %d%% of any damage you receive onto a random enemy within range.
		]]):format(displace)
	end,
}

newTalent{
	name = "Repulsion Field",
	type = {"chronomancy/other",1},
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 30) end,
	cooldown = 14,
	tactical = { ATTACKAREA = {PHYSICAL = 2}, ESCAPE = 2 },
	range = 0,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 1.5, 3.5)) end,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), selffire=false}
	end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 8, 80, getParadoxSpellpower(self, t)) end,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(t, 4, 8)) end,
	direct_hit = true,
	requires_target = true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		game.level.map:addEffect(self,
			self.x, self.y, t.getDuration(self, t),
			DamageType.REPULSION, t.getDamage(self, t),
			tg.radius,
			5, nil,
			engine.MapEffect.new{color_br=200, color_bg=120, color_bb=0, effect_shader="shader_images/paradox_effect.png"},
			function(e)
				e.x = e.src.x
				e.y = e.src.y
				return true
			end,
			tg.selffire
		)
		game:playSoundNear(self, "talents/cloud")
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local duration = t.getDuration(self, t)
		local radius = self:getTalentRadius(t)
		return ([[You surround yourself with a radius %d distortion of gravity, knocking back and dealing %0.2f physical damage to all creatures inside it.  The effect lasts %d turns.  Deals 50%% extra damage to pinned targets, in addition to the knockback.
		The blast wave may hit targets more then once, depending on the radius and the knockback effect.
		The damage will scale with your Spellpower.]]):format(radius, damDesc(self, DamageType.PHYSICAL, damage), duration)
	end,
}

newTalent{
	name = "Temporal Clone",
	type = {"chronomancy/other", 1},
	points = 5,
	cooldown = 12,
	paradox = function (self, t) return getParadoxCost(self, t, 15) end,
	tactical = { ATTACK = 2, DISABLE = 2 },
	requires_target = true,
	range = 10,
	remove_on_clone = true,
	target = function (self, t)
		return {type="hit", range=self:getTalentRange(t), talent=t, nowarning=true}
	end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 6, 12))) end,
	getDamagePenalty = function(self, t) return 60 - math.min(self:combatTalentSpellDamage(t, 0, 20, getParadoxSpellpower(self, t)), 30) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, _, _, x, y = self:canProject(tg, x, y)
		if not x or not y then return nil end
		local target = game.level.map(x, y, Map.ACTOR)
		if not target then return end

		-- Find space
		local tx, ty = util.findFreeGrid(x, y, 5, true, {[Map.ACTOR]=true})
		if not tx then
			game.logPlayer(self, "Not enough space to summon!")
			return
		end

		-- Rank Penalty
		local duration = t.getDuration(self, t)
		if target.rank > 1 then duration = math.ceil(t.getDuration(self, t)/(target.rank/2)) end

		 -- Clone the target
		local m = makeParadoxClone(self, target, duration)
		-- Add and change some values
		m.faction = self.faction
		m.summoner = self
		m.generic_damage_penalty = t.getDamagePenalty(self, t)
		m.max_life = m.max_life * (100 - t.getDamagePenalty(self, t))/100
		m.life = m.max_life
		m.remove_from_party_on_death = true

		-- Handle some AI stuff
		m.ai_state = { talent_in=2, ally_compassion=10 }

		game.zone:addEntity(game.level, m, "actor", tx, ty)

		-- Set our target
		if self:reactionToward(target) < 0 then
			m:setTarget(target)
		end

		if game.party:hasMember(self) then
			game.party:addMember(m, {
				control="no",
				type="temporal-clone",
				title="Temporal Clone",
				orders = {target=true},
			})
		end

		game.level.map:particleEmitter(tx, ty, 1, "temporal_teleport")
		game:playSoundNear(self, "talents/spell_generic")

		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local damage_penalty = t.getDamagePenalty(self, t)
		return ([[Clones the target creature for up to %d turns.  The duration of the effect will be divided by half the target's rank, and the target will have have %d%% of its normal life and deal %d%% less damage.
		If you clone a hostile creature the clone will target the creature it was cloned from.
		The life and damage penalties will be lessened by your Spellpower.]]):
		format(duration, 100 - damage_penalty, damage_penalty)
	end,
}

newTalent{
	name = "Paradox Mastery",
	type = {"chronomancy/other", 1},
	mode = "passive",
	points = 5,
	-- Static history bonus handled in timetravel.lua, backfire calcs performed by _M:getModifiedParadox function in mod\class\Actor.lua
	WilMult = function(self, t) return self:combatTalentScale(t, 0.15, 0.5) end,
	stabilityDuration = function(self, t) return math.floor(self:combatTalentScale(t, 0.4, 2.7, "log")) end,  --This is still used by an older talent, leave it here for backwards compatability
	passives = function(self, t, p)
		self:talentTemporaryValue(p, "paradox_will_mutli", t.WilMult(self, t))
	end,
	info = function(self, t)
		return ([[You've learned to focus your control over the spacetime continuum, and quell anomalous effects.  Increases your effective Willpower for anomaly calculations by %d%%.]]):
		format(t.WilMult(self, t) * 100)
	end,
}

newTalent{
	name = "Damage Smearing",
	type = {"chronomancy/other", 1},
	mode = "sustained",
	sustain_paradox = 48,
	cooldown = 24,
	tactical = { DEFEND = 2 },
	points = 5,
	getPercent = function(self, t) return self:combatTalentLimit(t, 50, 10, 30)/100 end, -- Limit < 50%
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 3, 6))) end,
	callbackOnTakeDamage = function(self, t, src, x, y, type, dam, tmp)
		if dam > 0 and type ~= DamageType.TEMPORAL then
			local smear = dam * t.getPercent(self, t)
			self:setEffect(self.EFF_DAMAGE_SMEARING, t.getDuration(self, t), {dam=smear/t.getDuration(self, t), no_ct_effect=true})
			game:delayedLogDamage(src, self, 0, ("%s(%d smeared)#LAST#"):format(DamageType:get(type).text_color or "#aaaaaa#", smear), false)
			dam = dam - smear
		end

		return {dam=dam}
	end,
	activate = function(self, t)
		game:playSoundNear(self, "talents/spell_generic")
		return {}
	end,
	deactivate = function(self, t, p)
		return true
	end,
	info = function(self, t)
		local percent = t.getPercent(self, t) * 100
		local duration = t.getDuration(self, t)
		return ([[You convert %d%% of all non-temporal damage you receive into temporal damage spread out over %d turns.
		This damage will bypass resistance and affinity.]]):format(percent, duration)
	end,
}

newTalent{
	name = "Banish",
	type = {"chronomancy/other", 1},
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

newTalent{
	name = "Swap",
	type = {"chronomancy/other", 1},
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 10,
	tactical = { DISABLE = 1 },
	requires_target = true,
	direct_hit = true,
	range = function(self, t) return math.floor(self:combatTalentScale(t, 5, 9, 0.5, 0, 1)) end,
	getConfuseDuration = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(t), 3, 7)) end,
	getConfuseEfficency = function(self, t) return math.min(50, self:getTalentLevelRaw(t) * 10) end,
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local tx, ty, target = self:getTarget(tg)
		if not tx or not ty then return nil end
		if tx then
			local _ _, tx, ty = self:canProject(tg, tx, ty)
			if tx then
				target = game.level.map(tx, ty, Map.ACTOR)
				if not target then return nil end
			end
		end

		-- Check hit
		if target:canBe("teleport") and self:checkHit(getParadoxSpellpower(self, t), target:combatSpellResist() + (target:attr("continuum_destabilization") or 0)) then
			-- Grab the caster's location
			local px, py = self.x, self.y

			-- Remove the target so the destination tile is empty
			game.level.map:remove(target.x, target.y, Map.ACTOR)

			-- Try to teleport to the target's old location
			if self:teleportRandom(tx, ty, 0) then
				-- Put the target back in the caster's old location
				game.level.map(px, py, Map.ACTOR, target)
				target.x, target.y = px, py

				-- confuse them
				self:project(tg, target.x, target.y, DamageType.CONFUSION, { dur = t.getConfuseDuration(self, t), dam = t.getConfuseEfficency(self, t), apply_power=getParadoxSpellpower(self, t)})
				target:setEffect(target.EFF_CONTINUUM_DESTABILIZATION, 100, {power=getParadoxSpellpower(self, t, 0.3)})

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

		game:playSoundNear(self, "talents/teleport")
		return true
	end,
	info = function(self, t)
		local range = self:getTalentRange(t)
		local duration = t.getConfuseDuration(self, t)
		local power = t.getConfuseEfficency(self, t)
		return ([[You manipulate the spacetime continuum in such a way that you switch places with another creature with in a range of %d.  The targeted creature will be confused (power %d%%) for %d turns.
		The spell's hit chance will increase with your Spellpower.]]):format (range, power, duration)
	end,
}

newTalent{
	name = "Temporal Wake",
	type = {"chronomancy/other", 1},
	points = 5,
	random_ego = "attack",
	paradox = function (self, t) return getParadoxCost(self, t, 20) end,
	cooldown = 10,
	tactical = { ATTACK = {TEMPORAL = 1, PHYSICAL = 1}, CLOSEIN = 2, DISABLE = { stun = 2 } },
	direct_hit = true,
	requires_target = true,
	is_teleport = true,
	target = function(self, t)
		return {type="beam", start_x=x, start_y=y, range=self:getTalentRange(t), selffire=false, talent=t}
	end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 230, getParadoxSpellpower(self, t)) end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 3, 7))) end,
	range = function(self, t) return math.floor(self:combatTalentScale(t, 5, 9, 0.5, 0, 1)) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		if not self:hasLOS(x, y) or game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move") then
			game.logSeen(self, "You do not have line of sight.")
			return nil
		end
		local _ _, x, y = self:canProject(tg, x, y)
		local ox, oy = self.x, self.y

		-- If we target an actor directly project onto the other side of it (quality of life)
		if target then
			local dir = util.getDir(x, y, self.x, self.y)
			x, y = util.coordAddDir(x, y, dir)
		end

		-- since we're using a precise teleport we'll look for a free grid first
		local tx, ty = util.findFreeGrid(x, y, 5, true, {[Map.ACTOR]=true})
		if tx and ty then
			if not self:teleportRandom(tx, ty, 0) then
				game.logSeen(self, "The teleport fizzles!")
			else
				local dam = self:spellCrit(t.getDamage(self, t))
				local x, y = ox, oy
				self:project(tg, x, y, function(px, py)
					local target = game.level.map(px, py, Map.ACTOR)
					if target then
						-- Deal warp damage first so we don't overwrite a big stun with a little one
						DamageType:get(DamageType.WARP).projector(self, px, py, DamageType.WARP, dam)

						-- Try to stun
						if target:canBe("stun") then
							target:setEffect(target.EFF_STUNNED, t.getDuration(self, t), {apply_power=getParadoxSpellpower(self, t)})
						else
							game.logSeen(target, "%s resists the stun!", target.name:capitalize())
						end
					end
				end)
				game.level.map:particleEmitter(self.x, self.y, math.max(math.abs(x-self.x), math.abs(y-self.y)), "temporal_lightning", {tx=x-self.x, ty=y-self.y})
				game:playSoundNear(self, "talents/lightning")
			end
		end

		return true
	end,
	info = function(self, t)
		local stun = t.getDuration(self, t)
		local damage = t.getDamage(self, t)
		return ([[Violently fold the space between yourself and another point within range.
		You teleport to the target location, and leave a temporal wake behind that stuns for %d turns and deals %0.2f temporal and %0.2f physical warp damage to targets in the path.
		The damage will scale with your Spellpower.]]):
		format(stun, damDesc(self, DamageType.TEMPORAL, damage/2), damDesc(self, DamageType.PHYSICAL, damage/2))
	end,
}
