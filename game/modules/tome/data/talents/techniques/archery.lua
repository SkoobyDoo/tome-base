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

-- Default archery attack

local weaponCheck = function(self, weapon, ammo, silent, weapon_type)
	if not weapon then
		if not silent then
			-- ammo contains error message
			game.logPlayer(self, ({
				["disarmed"] = "You are currently disarmed and cannot use this talent.",
				["no shooter"] = ("You require a %s to use this talent."):format(weapon_type or "missile launcher"),
				["no ammo"] = "You require ammo to use this talent.",
				["bad ammo"] = "Your ammo cannot be used.",
				["incompatible ammo"] = "Your ammo is incompatible with your missile launcher.",
				["incompatible missile launcher"] = ("You require a %s to use this talent."):format(weapon_type or "bow"),
			})[ammo] or "You require a missile launcher and ammo for this talent.")
		end
		return false
	else
		local infinite = ammo and ammo.infinite or self:attr("infinite_ammo")
		if not ammo or (ammo.combat.shots_left <= 0 and not infinite) then
			if not silent then game.logPlayer(self, "You do not have enough ammo left!") end
			return false
		end
	end
	return true
end

local archerPreUse = function(self, t, silent, weapon_type)
	local weapon, ammo, offweapon, pf_weapon = self:hasArcheryWeapon(weapon_type)
	weapon = weapon or pf_weapon
	return weaponCheck(self, weapon, ammo, silent, weapon_type)
end

local wardenPreUse = function(self, t, silent, weapon_type)
	local weapon, ammo, offweapon, pf_weapon = self:hasArcheryWeapon(weapon_type)
	weapon = weapon or pf_weapon
	if self:attr("warden_swap") and not weapon and weapon_type == nil or weapon_type == "bow" then
		weapon, ammo = doWardenPreUse(self, "bow")
	end
	return weaponCheck(self, weapon, ammo, silent, weapon_type)
end

Talents.archerPreUse = archerPreUse
Talents.wardenPreUse = wardenPreUse

newTalent{
	name = "Shoot",
	type = {"technique/archery-base", 1},
	no_energy = "fake",
	speed = 'archery',
	hide = true,
	innate = true,
	points = 1,
	cooldown = 0,
	stamina = function(self, t)
		if not self:isTalentActive("T_SKIRMISHER_BOMBARDMENT") or not wardenPreUse(self, t, false, "sling") then return nil end

		local b = self:getTalentFromId("T_SKIRMISHER_BOMBARDMENT")
		return b.shot_stamina(self, b)
	end,
	range = archery_range,
	message = "@Source@ shoots!",
	requires_target = true,
	tactical = { ATTACK = { weapon = 1 } },
	on_pre_use = function(self, t, silent) return wardenPreUse(self, t, silent) end,
	no_unlearn_last = true,
	action = function(self, t)
		local swap = not self:attr("disarmed") and (self:attr("warden_swap") and doWardenWeaponSwap(self, t, "bow"))
	
		-- Most of the time use the normal shoot.
		if not wardenPreUse(self, t, true, "sling") or not self:isTalentActive("T_SKIRMISHER_BOMBARDMENT") then
			local targets = self:archeryAcquireTargets(nil, {one_shot=true})
			if not targets then if swap then doWardenWeaponSwap(self, t, "blade") end return end
			self:archeryShoot(targets, t, nil) -- use_psi_archery set by Archery:archeryShoot
			return true
		end
		
		-- perform Bombardment if possible
		local weapon, ammo, offweapon, pf_weapon = self:hasArcheryWeapon("sling")
		if not weapon and not pf_weapon then return nil end

		local bombardment = self:getTalentFromId("T_SKIRMISHER_BOMBARDMENT")
		local shots = bombardment.bullet_count(self, bombardment)
		local mult = bombardment.damage_multiplier(self, bombardment)

		-- Do targeting.
		local old_target_forced = game.target.forced
		local tg = {type = "bolt", range = archery_range(self),	talent = t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return end
		game.target.forced = {x, y, target}

		-- Fire all shots, limited by stamina
		local count = 0
		local stam = t.stamina(self, t)*self.resources_def[self.RS_STAMINA].cost_factor(self, t)
		for i = 1, shots do
			local targets = self:archeryAcquireTargets(nil, {no_energy=true, one_shot=true, type="sling"})
			if not targets then break end
			
			if count > 0 then 
				if self:getStamina() < stam*2 then break end
				
				self:incStamina(-stam)
			end
			count = i
			self:archeryShoot(targets, t, nil, {mult=mult, type="sling"})
		end
		if count > 0 then
			local speed = self:combatSpeed(weapon or pf_weapon)
			self:useEnergy(game.energy_to_act * (speed or 1))
		end
		game.target.forced = old_target_forced

		return count > 0
	end,
	info = function(self, t)
		return ([[Shoot your bow, sling or other missile launcher!]])
	end,
}

newTalent{
	name = "Steady Shot",
	type = {"technique/archery-training", 1},
	no_energy = "fake",
	points = 5,
	random_ego = "attack",
	cooldown = 3,
	stamina = 8,
	require = techs_dex_req1,
	range = archery_range,
	requires_target = true,
	tactical = { ATTACK = { weapon = 2 } },
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent) end,
	action = function(self, t)
		local targets = self:archeryAcquireTargets(nil, {one_shot=true})
		if not targets then return end
		self:archeryShoot(targets, t, nil, {mult=self:combatTalentWeaponDamage(t, 1.1, 2.2)})
		return true
	end,
	info = function(self, t)
		return ([[A steady shot, doing %d%% damage.]]):format(self:combatTalentWeaponDamage(t, 1.1, 2.2) * 100)
	end,
}

newTalent{
	name = "Aim",
	type = {"technique/archery-training", 2},
	mode = "sustained",
	points = 5,
	require = techs_dex_req2,
	cooldown = 8,
	sustain_stamina = 20,
	no_energy = true,
	tactical = { BUFF = 2 },
	no_npc_use = true,
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent) end,
	getCombatVals = function(self, t)
		local vals = {speed = -self:combatTalentLimit(t, 0.5, 0.05, 0.25), -- Limit < 50% speed loss
			crit =  self:combatScale(self:getTalentLevel(t) * self:getDex(10, true), 7, 0, 57, 50),
			atk = self:combatScale(self:getTalentLevel(t) * self:getDex(10, true), 4, 0, 54, 50),
			dam = self:combatScale(self:getTalentLevel(t) * self:getDex(10, true), 4, 0, 54, 50),
			apr = self:combatScale(self:getTalentLevel(t) * self:getDex(10, true), 3, 0, 53, 50)}
		return vals
	end,
	sustain_slots = 'archery_stance',
	activate = function(self, t)
		local weapon = self:hasArcheryWeapon()
		if not weapon then
			game.logPlayer(self, "You cannot use Aim without a bow or sling!")
			return nil
		end

		local vals = t.getCombatVals(self, t)
		return {
			speed = self:addTemporaryValue("combat_physspeed", vals.speed),
			crit = self:addTemporaryValue("combat_physcrit", vals.crit),
			atk = self:addTemporaryValue("combat_dam", vals.atk),
			dam = self:addTemporaryValue("combat_atk", vals.dam),
			apr = self:addTemporaryValue("combat_apr", vals.apr),
		}
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("combat_physspeed", p.speed)
		self:removeTemporaryValue("combat_physcrit", p.crit)
		self:removeTemporaryValue("combat_apr", p.apr)
		self:removeTemporaryValue("combat_atk", p.atk)
		self:removeTemporaryValue("combat_dam", p.dam)
		return true
	end,
	info = function(self, t)
		local vals = t.getCombatVals(self, t)
		return ([[You enter a calm, focused stance, increasing your Physical Power (+%d), Accuracy (+%d), Armour penetration (+%d), and critical chance (+%d%%), but reducing your firing speed by %d%%.
		The effects will increase with your Dexterity.]]):
		format(vals.dam, vals.atk, vals.apr, vals.crit, -vals.speed * 100)
	end,
}

newTalent{
	name = "Rapid Shot",
	type = {"technique/archery-training", 3},
	mode = "sustained",
	points = 5,
	require = techs_dex_req3,
	cooldown = 8,
	sustain_stamina = 20,
	no_energy = true,
	tactical = { BUFF = 2 },
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent) end,
	getCombatVals = function(self, t)
		local vals = {speed = self:combatTalentScale(t, 0.1, 0.5, 0.75),
			crit = -self:combatTalentScale(t, 10.4, 20),
			atk = -self:combatTalentScale(t, 10.4, 20, 0.75),
			dam = -self:combatTalentScale(t, 10.4, 20, 0.75)
			}
		return vals
	end,
	sustain_slots = 'archery_stance',
	activate = function(self, t)
		local weapon = self:hasArcheryWeapon()
		if not weapon then
			game.logPlayer(self, "You cannot use Rapid Shot without a bow or sling!")
			return nil
		end

		local vals = t.getCombatVals(self, t)
		return {
			speed = self:addTemporaryValue("combat_physspeed", vals.speed),
			atk = self:addTemporaryValue("combat_dam", vals.atk),
			dam = self:addTemporaryValue("combat_atk", vals.dam),
			crit = self:addTemporaryValue("combat_physcrit", vals.crit),
		}
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("combat_physspeed", p.speed)
		self:removeTemporaryValue("combat_physcrit", p.crit)
		self:removeTemporaryValue("combat_dam", p.dam)
		self:removeTemporaryValue("combat_atk", p.atk)
		return true
	end,
	info = function(self, t)
		local vals = t.getCombatVals(self, t)
		return ([[You switch to a fluid and fast battle stance, increasing your firing speed by %d%% at the cost of your Accuracy (%d), Physical Power (%d), and critical chance (%d%%).]]):
		format(vals.speed*100, vals.atk, vals.dam, vals.crit)
	end,
}

newTalent{
	name = "Relaxed Shot",
	type = {"technique/archery-training", 4},
	no_energy = "fake",
	points = 5,
	random_ego = "attack",
	cooldown = 14,
	require = techs_dex_req4,
	range = archery_range,
	requires_target = true,
	tactical = { ATTACK = { weapon = 1 }, STAMINA = 1 },
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent) end,
	action = function(self, t)
		local targets = self:archeryAcquireTargets(nil, {one_shot=true})
		if not targets then return end
		self:archeryShoot(targets, t, nil, {mult=self:combatTalentWeaponDamage(t, 0.5, 1.1)})
		self:incStamina(12 + self:getTalentLevel(t) * 8)
		return true
	end,
	info = function(self, t)
		return ([[You fire a shot without putting much strength into it, doing %d%% damage.
		That brief moment of relief allows you to regain %d stamina.]]):format(self:combatTalentWeaponDamage(t, 0.5, 1.1) * 100, 12 + self:getTalentLevel(t) * 8)
	end,
}

-------------------------------- Utility -----------------------------------

newTalent{
	name = "Flare",
	type = {"technique/archery-utility", 1},
	no_energy = "fake",
	points = 5,
	cooldown = 15,
	stamina = 15,
	range = archery_range,
	radius = function(self, t)
		local rad = 1
		if self:getTalentLevel(t) >= 3 then rad = rad + 1 end
		if self:getTalentLevel(t) >= 5 then rad = rad + 1 end
		return rad
	end,
	require = techs_dex_req1,
	tactical = { ATTACKAREA = { FIRE = 2 }, DISABLE = { blind = 2 } },
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent) end,
	requires_target = true,
	target = function(self, t)
		return {type="ball", x=x, y=y, radius=self:getTalentRadius(t), range=self:getTalentRange(t)}
	end,
	archery_onreach = function(self, t, x, y)
		local tg = self:getTalentTarget(t)
		self:project(tg, x, y, DamageType.LITE, 1)
		if self:getTalentLevel(t) >= 3 then
			tg.selffire = false
			self:project(tg, x, y, DamageType.BLINDPHYSICAL, 3)
		end
		game.level.map:particleEmitter(x, y, tg.radius, "ball_light", {radius=tg.radius})
	end,
	action = function(self, t)
		local targets = self:archeryAcquireTargets(nil, {one_shot=true})
		if not targets then return end
		self:archeryShoot(targets, t, nil, {mult=self:combatTalentWeaponDamage(t, 0.5, 1.2), damtype=DamageType.FIRE})
		return true
	end,
	info = function(self, t)
		local rad = 1
		if self:getTalentLevel(t) >= 3 then rad = rad + 1 end
		if self:getTalentLevel(t) >= 5 then rad = rad + 1 end
		return ([[You fire a burning shot, doing %d%% fire damage to the target and lighting up the area around the target in a radius of %d.
		At level 3, it also has a chance to blind for 3 turns.]]):
		format(self:combatTalentWeaponDamage(t, 0.5, 1.2) * 100, rad)
	end,
}

newTalent{
	name = "Crippling Shot",
	type = {"technique/archery-utility", 2},
	no_energy = "fake",
	points = 5,
	random_ego = "attack",
	cooldown = 10,
	stamina = 15,
	require = techs_dex_req2,
	range = archery_range,
	tactical = { ATTACK = { weapon = 1 }, DISABLE = 1 },
	requires_target = true,
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent) end,
	archery_onhit = function(self, t, target, x, y)
		target:setEffect(target.EFF_SLOW, 7, {power=util.bound((self:combatAttack() * 0.15 * self:getTalentLevel(t)) / 100, 0.1, 0.4), apply_power=self:combatAttack()})
	end,
	action = function(self, t)
		local targets = self:archeryAcquireTargets(nil, {one_shot=true})
		if not targets then return end
		self:archeryShoot(targets, t, nil, {mult=self:combatTalentWeaponDamage(t, 1, 1.5)})
		return true
	end,
	info = function(self, t)
		return ([[You fire a crippling shot, doing %d%% damage and reducing your target's speed by %d%% for 7 turns.
		The status power and status hit chance improve with your Accuracy.]]):format(self:combatTalentWeaponDamage(t, 1, 1.5) * 100, util.bound((self:combatAttack() * 0.15 * self:getTalentLevel(t)) / 100, 0.1, 0.4) * 100)
	end,
}

newTalent{
	name = "Pinning Shot",
	type = {"technique/archery-utility", 3},
	no_energy = "fake",
	points = 5,
	random_ego = "attack",
	cooldown = 10,
	stamina = 15,
	require = techs_dex_req3,
	range = archery_range,
	tactical = { ATTACK = { weapon = 1 }, DISABLE = { pin = 2 } },
	requires_target = true,
	getDur = function(self, t) return math.floor(self:combatTalentScale(t, 2.3, 5.5)) end,
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent) end,
	archery_onhit = function(self, t, target, x, y)
		if target:canBe("pin") then
			target:setEffect(target.EFF_PINNED, t.getDur(self, t), {apply_power=self:combatAttack()})
		else
			game.logSeen(target, "%s resists!", target.name:capitalize())
		end
	end,
	action = function(self, t)
		local targets = self:archeryAcquireTargets(nil, {one_shot=true})
		if not targets then return end
		self:archeryShoot(targets, t, nil, {mult=self:combatTalentWeaponDamage(t, 1, 1.4)})
		return true
	end,
	info = function(self, t)
		return ([[You fire a pinning shot, doing %d%% damage and pinning your target to the ground for %d turns.
		The pinning chance increases with your Dexterity.]])
		:format(self:combatTalentWeaponDamage(t, 1, 1.4) * 100,
		t.getDur(self, t))
	end,
}

newTalent{
	name = "Scatter Shot",
	type = {"technique/archery-utility", 4},
	no_energy = "fake",
	points = 5,
	random_ego = "attack",
	cooldown = 14,
	stamina = 15,
	require = techs_dex_req4,
	range = archery_range,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 1.3, 2.7)) end,
	tactical = { ATTACKAREA = { weapon = 2 }, DISABLE = { stun = 3 } },
	requires_target = true,
	target = function(self, t)
		local weapon, ammo = self:hasArcheryWeapon()
		return {type="ball", radius=self:getTalentRadius(t), range=self:getTalentRange(t), display=self:archeryDefaultProjectileVisual(weapon, ammo)}
	end,
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent) end,
	getStunDur = function(self, t) return math.floor(self:combatTalentScale(t, 3, 7)) end,
	archery_onhit = function(self, t, target, x, y)
		if target:canBe("stun") then
			target:setEffect(target.EFF_STUNNED, t.getStunDur(self, t), {apply_power=self:combatAttack()})
		else
			game.logSeen(target, "%s resists the stunning shot!", target.name:capitalize())
		end
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local targets = self:archeryAcquireTargets(tg, {one_shot=true})
		if not targets then return end
		self:archeryShoot(targets, t, tg, {mult=self:combatTalentWeaponDamage(t, 0.5, 1.5)})
		return true
	end,
	info = function(self, t)
		return ([[You fire multiple shots in a circular pattern with radius %d, doing %d%% damage and stunning everyone hit for %d turns.
		The stun chance increases with your Accuracy.]])
		:format(self:getTalentRadius(t), self:combatTalentWeaponDamage(t, 0.5, 1.5) * 100, t.getStunDur(self,t))
	end,
}
