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

-- some helpers

newTalent{
	name = "Fold Fate",
	type = {"chronomancy/other", 1},
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 30,
	tactical = { BUFF = 2, DEBUFF = 2 },
	points = 5,
	no_energy = true,
	on_pre_use = function(self, t, silent)
		for eff_id, p in pairs(self.tmp) do
			local e = self.tempeffect_def[eff_id]
			if true == e.subtype.weapon_manifold then
				if not silent then
					game.logPlayer(self, "You may only have one Weapon Manifold active at a time.")
				end
				return false
			end
		end
		return true
	end,
	getChance = function(self, t) return 50	end,
	action = function(self, t)
		local duration = self:callTalent(self.T_WEAPON_MANIFOLD, "getDuration")
		local dam = t.getChance(self, t)
		local dox = self:callTalent(self.T_WEAPON_MANIFOLD, "getParadoxRegen")

		self:setEffect(self.EFF_FOLD_FATE, duration, {dam = dam, src = self, paradox = dox})

		return true
	end,
	info = function(self, t)
		local duration = self:callTalent(self.T_WEAPON_MANIFOLD, "getDuration")
		local dam = t.getChance(self, t)
		local dox = self:callTalent(self.T_WEAPON_MANIFOLD, "getParadoxRegen")
		return (
		[[Fold a thread of fate into your weapons for %d turns, causing confusing dissonance when it strikes your targets as you damage their fates to repair the timeline.
		Your melee and archery attacks have a %d%% chance to confuse any target you strike, and each hit brings your Paradox up to %0.1f closer to your chosen baseline.
		The damage and Paradox regeneration will improve with your Paradox.]]
		):format( duration, dam, dox )
	end,
}

newTalent{
	name = "Fold Gravity",
	type = {"chronomancy/other", 1},
	paradox = function (self, t) return getParadoxCost(self, t, 30) end,
	cooldown = 30,
	tactical = { BUFF = 2, DEBUFF = 2 },
	points = 1,
	no_energy = true,
	on_pre_use = function(self, t, silent)
		for eff_id, p in pairs(self.tmp) do
			local e = self.tempeffect_def[eff_id]
			if true == e.subtype.weapon_manifold then
				if not silent then
					game.logPlayer(self, "You may only have one Weapon Manifold active at a time.")
				end
				return false
			end
		end
		return true
	end,
	getChance = function(self, t) return 25	end,
	getEffDur = function(self, t) return 4 end,
	action = function(self, t)
		local duration = self:callTalent(self.T_WEAPON_MANIFOLD, "getDuration")
		local damage = self:callTalent(self.T_WEAPON_FOLDING, "getDamage")
		local chance = t.getChance(self, t)
		local eff_dur = t.getEffDur(self, t)

		self:setEffect(self.EFF_FOLD_GRAVITY, duration, {dam = damage, src = self, chance = chance})

		return true
	end,
	info = function(self, t)
		local duration = self:callTalent(self.T_WEAPON_MANIFOLD, "getDuration")
		local damage = self:callTalent(self.T_WEAPON_FOLDING, "getDamage")
		local chance = t.getChance(self, t)
		local eff_dur = t.getEffDur(self, t)
		return (
		[[Fold a thread of gravity into your weapons for %d turns.
		Your melee and archery attacks deal +%0.1f Physical damage, and each attack has a %d%% chance to Pin your target for %d turns.
		The damage will improve with your Paradox, and the Pin will be applied with your Spellpower.]]
		):format( duration, damDesc(self, DamageType.PHYSICAL, damage), chance, eff_dur )
	end,
}

newTalent{
	name = "Fold Void",
	type = {"chronomancy/other", 1},
	paradox = function (self, t) return getParadoxCost(self, t, 30) end,
	cooldown = 30,
	tactical = { BUFF = 2, DEBUFF = 2 },
	points = 1,
	no_energy = true,
	on_pre_use = function(self, t, silent)
		for eff_id, p in pairs(self.tmp) do
		local e = self.tempeffect_def[eff_id]
			if true == e.subtype.weapon_manifold then
				if not silent then
					game.logPlayer(self, "You may only have one Weapon Manifold active at a time.")
				end
				return false
			end
		end
		return true
	end,
	getChance = function(self, t) return 25	end,
	getEffDur = function(self, t) return 4 end,
	action = function(self, t)
		local duration = self:callTalent(self.T_WEAPON_MANIFOLD, "getDuration")
		local damage = self:callTalent(self.T_WEAPON_FOLDING, "getDamage")
		local chance = t.getChance(self, t)
		local eff_dur = t.getEffDur(self, t)

		self:setEffect(self.EFF_FOLD_VOID, duration, {dam = damage, src = self, chance = chance})

		return true
	end,
	info = function(self, t)
		local duration = self:callTalent(self.T_WEAPON_MANIFOLD, "getDuration")
		local damage = self:callTalent(self.T_WEAPON_FOLDING, "getDamage")
		local chance = t.getChance(self, t)
		local eff_dur = t.getEffDur(self, t)
		return (
		[[Fold a thread of the void into your weapons for %d turns.
		Your melee and archery attacks deal +%0.1f Darkness damage, and each attack has a %d%% chance to Blind your target for %d turns.
		The damage will improve with your Paradox, and the Blindness will be applied with your Spellpower.]]
		):format( duration, damDesc(self, DamageType.DARKNESS, damage), chance, eff_dur )
	end,
}

-- Temporal Combat proper
newTalent{
	name = "Weapon Folding",
	type = {"chronomancy/temporal-combat", 1},
	mode = "sustained",
	require = chrono_req1,
	sustain_paradox = 12,
	cooldown = 10,
	tactical = { BUFF = 2 },
	points = 5,
	activate = function(self, t)
		return {}
	end,
	deactivate = function(self, t, p)
		return true
	end,
	getDamage = function(self, t) return 7 + self:combatSpellpower(0.092) * self:combatTalentScale(t, 1, 7) end,
	callbackOnArcheryAttack = function(self, t, target, hitted, crit, weapon, ammo, damtype, mult, dam)
		if not hitted then return end
		if not target then return end
		t.doWeaponFolding(self, t, target)
	end,
	callbackOnMeleeAttack = function(self, t, target, hitted, crit, weapon, damtype, mult, dam)
		if not hitted then return end
		if not target then return end
		t.doWeaponFolding(self, t, target)
	end,
	doWeaponFolding = function(self, t, target)
		local dam = t.getDamage(self,t)
		if self:knowTalent(self.T_FRAYED_THREADS) then
			self:callTalent(self.T_FRAYED_THREADS, "doExplosion", target, DamageType.TEMPORAL, dam)
		end
		if not target.dead then
			DamageType:get(DamageType.TEMPORAL).projector(self, target.x, target.y, DamageType.TEMPORAL, dam)
		end
		
		self:fireTalentCheck("callbackOnChronoWeaponFoldingHit", target, dam)
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		return ([[Folds a single dimension of your weapons (or ammo) upon itself, adding %0.2f temporal damage to your strikes and increasing your armor penetration by %d.
		The armor penetration and damage will increase with your Spellpower.]]):format(damDesc(self, DamageType.TEMPORAL, damage), damage/2)
	end,
}


newTalent{
	name = "Weapon Manifold",
	type = {"chronomancy/temporal-combat", 2},
	require = chrono_req2,
	mode = "passive",
	points = 5,
	on_learn = function(self, t)
		self:learnTalent(Talents.T_FOLD_FATE, true)
		self:learnTalent(Talents.T_FOLD_GRAVITY, true)
		self:learnTalent(Talents.T_FOLD_VOID, true)
	end,
	on_unlearn = function(self, t)
		self:unlearnTalent(Talents.T_FOLD_FATE)
		self:unlearnTalent(Talents.T_FOLD_GRAVITY)
		self:unlearnTalent(Talents.T_FOLD_VOID)
	end,
	getDuration = function(self, t) return 5 + paradoxTalentScale(self, t, 5, 15, 25) end,
	getParadoxRegen = function(self, t) return 5 + paradoxTalentScale(self, t, 4, 25, 45) end,
	info = function(self, t)
		local damage = self:callTalent(self.T_WEAPON_FOLDING, "getDamage")
		local dur    = t.getDuration(self, t)
		local dox    = t.getParadoxRegen(self, t)
		return ([[Advanced weapon folding. For %d turns, enhance your melee and archery attacks with the power of fate, gravity or the void.
		Fold Fate: 50%% chance to Confuse your target for 4 turns, and you regain %0.1f Paradox.
		Fold Gravity: %0.1f Physical damage, and you have a 25%% chance to Pin your target for 4 turns.
		Fold Void: %0.1f Darkness damage, and you have a 25%% chance to Blind your target for 4 turns.
		The Physical and Temporal damage and duration will increase with your Paradox and with investment in Weapon Folding. The Paradox recovery will increase with your Paradox. The status effects will become harder to resist as you gain Spellpower.]]
		):format( dur, dox, damDesc(self, DamageType.PHYSICAL, damage), damDesc(self, DamageType.DARKNESS, damage) )
	end,
}

newTalent{
	name = "Invigorate",
	type = {"chronomancy/temporal-combat", 3},
	require = chrono_req3,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 20) end,
	cooldown = 24,
	fixed_cooldown = true,
	tactical = { HEAL = 1 },
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentLimit(self:getTalentLevel(t), 14, 4, 8))) end, -- Limit < 14
	getPower = function(self, t) return self:combatTalentSpellDamage(t, 10, 50, getParadoxSpellpower(self, t)) end,
	action = function(self, t)
		self:setEffect(self.EFF_INVIGORATE, t.getDuration(self,t), {power=t.getPower(self, t)})
		return true
	end,
	info = function(self, t)
		local power = t.getPower(self, t)
		local duration = t.getDuration(self, t)
		return ([[For the next %d turns, you recover %0.1f life and %0.1f stamina per turn, and most other talents on cooldown will refresh twice as fast as usual.
		The life and stamina regeneration will increase with your Spellpower.]]):format(duration, power, power/2)
	end,
}

newTalent{
	name = "Breach",
	type = {"chronomancy/temporal-combat", 4},
	require = chrono_req4,
	points = 5,
	cooldown = 8,
	paradox = function (self, t) return getParadoxCost(self, t, 15) end,
	tactical = { ATTACK = {weapon = 2}, DISABLE = 3 },
	requires_target = true,
	range = archery_range,
	speed = function(self, t) return self:hasArcheryWeapon("bow") and "archery" or "weapon" end,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 1, 1.5) end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 3, 7))) end,
	on_pre_use = function(self, t, silent) if self:attr("disarmed") then if not silent then game.logPlayer(self, "You require a weapon to use this talent.") end return false end return true end,
	archery_onhit = function(self, t, target, x, y)
		target:setEffect(target.EFF_BREACH, t.getDuration(self, t), {})
	end,
	action = function(self, t)
		local mainhand, offhand = self:hasDualWeapon()

		if self:hasArcheryWeapon("bow") then
			-- Ranged attack
			local targets = self:archeryAcquireTargets({type="bolt"}, {one_shot=true, no_energy = true})
			if not targets then return end
			self:archeryShoot(targets, t, {type="bolt"}, {mult=t.getDamage(self, t)})
		elseif mainhand then
			-- Melee attack
			local tg = {type="hit", range=self:getTalentRange(t), talent=t}
			local x, y, target = self:getTarget(tg)
			if not x or not y or not target then return nil end
			if core.fov.distance(self.x, self.y, x, y) > 1 then return nil end
			local hitted = self:attackTarget(target, nil, t.getDamage(self, t), true)

			if hitted then
			target:setEffect(target.EFF_BREACH, t.getDuration(self, t), {apply_power=getParadoxSpellpower(self, t)})
			end
		else
			game.logPlayer(self, "You cannot use Breach without an appropriate weapon!")
			return nil
		end

		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local damage = t.getDamage(self, t) * 100
		return ([[Attack the target with either your bow or melee weapons for %d%% damage.
		If the attack hits you'll breach the target's immunities, reducing armor hardiness, stun, pin, blindness, and confusion immunity by 50%% for %d turns.
		Breach chance scales with your Spellpower.]])
		:format(damage, duration)
	end
}
