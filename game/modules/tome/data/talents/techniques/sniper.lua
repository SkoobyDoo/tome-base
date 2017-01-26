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

local DamageType = require "engine.DamageType"
local Object = require "engine.Object"
local Map = require "engine.Map"

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

doWardenPreUse = function(self, weapon, silent)
	if weapon == "bow" then
		local bow, ammo, oh, pf_bow= self:hasArcheryWeapon("bow")
		if not bow and not pf_bow then
			bow, ammo, oh, pf_bow= self:hasArcheryWeapon("bow", true)
		end
		return bow or pf_bow, ammo
	end
	if weapon == "dual" then
		local mh, oh = self:hasDualWeapon()
		if not mh then
			mh, oh = self:hasDualWeaponQS()
		end
		return mh, oh
	end
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

local preUse = function(self, t, silent)
	if not self:hasShield() or not archerPreUse(self, t, true) then
		if not silent then game.logPlayer("You require a ranged weapon and a shield to use this talent.") end
		return false
	end
	return true
end

Talents.archerPreUse = archerPreUse
Talents.wardenPreUse = wardenPreUse

archery_range = Talents.main_env.archery_range

newTalent{
	name = "Concealment",
	type = {"technique/sniper", 1},
	points = 5,
	mode = "sustained",
	require = techs_dex_req_high1,
	cooldown = 10,
	tactical = { BUFF = 2 },
	no_npc_use = true, -- getting 1 shot from an invisible ranged attacker = no
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent, "bow") end,
	getDamage = function(self, t) return math.floor(self:combatTalentScale(t, 10, 35)) end,
	getAvoidance = function(self, t) return math.floor(self:combatTalentScale(t, 15, 40)) end,
	sustain_lists = "break_with_stealth",
	activate = function(self, t)
		local ret = {}
		local chance = t.getAvoidance(self, t)
		self:talentTemporaryValue(ret, "cancel_damage_chance", chance)
		self:talentTemporaryValue(ret, "concealment", 6)
		return ret
	end,
	deactivate = function(self, t, p)
		return true
	end,
	hasFoes = function(self)
		for i = 1, #self.fov.actors_dist do
			local act = self.fov.actors_dist[i]
			if act and self:reactionToward(act) < 0 and self:canSee(act) then return true end
		end
		return false
	end,
	callbackOnActBase = function(self, t)
		if t.hasFoes(self) then
			self:setEffect(self.EFF_TAKING_AIM, 2, {power=t.getDamage(self,t), max_stacks=3, max_power=t.getDamage(self,t)*3 })
		end
	end,
	info = function(self, t)
		local avoid = t.getAvoidance(self,t)
		local dam = t.getDamage(self,t)
		return ([[Enter a concealed sniping stance. You gain a %d%% chance to completely avoid incoming damage and status effects, and enemies further than 6 tiles away will be unable to clearly see you, effectively blinding them.
While in this stance, you will take aim if a foe is visible. Each stack of take aim increases the damage of your next Steady Shot by %d%% and the chance to mark by 30%%, stacking up to 3 times.
This requires a bow to use.]]):
		format(avoid, dam, dam*3)
	end,
}

newTalent{
	name = "Shadow Shot",
	type = {"technique/sniper", 2},
	require = techs_dex_req2,
	no_energy = "fake",
	points = 5,
	random_ego = "attack",
	stamina = 18,
	cooldown = 14,
	require = techs_dex_req_high2,
	range = archery_range,
	requires_target = true,
	tactical = { ATTACK = { weapon = 2 }, DISABLE = 2 },
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent, "bow") end,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 1, 2.7)) end,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 1.1, 1.9) end,
	archery_onreach = function(self, t, x, y)
		local tg = self:getTalentTarget(t)
		self:project(tg, x, y, function(px, py)
			local e = Object.new{
				block_sight=true,
				temporary = 4,
				x = px, y = py,
				canAct = false,
				act = function(self)
					local t = self.summoner:getTalentFromId(self.summoner.T_SHADOW_SHOT)
					local rad = self.summoner:getTalentRadius(t)
					local Map = require "engine.Map"
					self:useEnergy()
					local actor = game.level.map(self.x, self.y, Map.ACTOR)
					self.temporary = self.temporary - 1
					if self.temporary <= 0 then
						if self.particles then game.level.map:removeParticleEmitter(self.particles) end
						game.level.map:remove(self.x, self.y, engine.Map.TERRAIN+rad)
						self.smokeBomb = nil
						game.level:removeEntity(self)
						game.level.map:scheduleRedisplay()
					end
				end,
				summoner_gain_exp = true,
				summoner = self,
			}
			e.smokeBomb = e -- used for checkAllEntities to return the dark Object itself
			game.level:addEntity(e)
			game.level.map(px, py, Map.TERRAIN+self:getTalentRadius(t), e)
			e.particles = Particles.new("creeping_dark", 1, { })
			e.particles.x = px
			e.particles.y = py
			game.level.map:addParticleEmitter(e.particles)

			end, nil, {type="dark"})

		game.level.map:redisplay()
	end,
	target = function(self, t)
		local weapon, ammo = self:hasArcheryWeapon()
		return {type="ball", radius=self:getTalentRadius(t), range=self:getTalentRange(t), selffire=false, display=self:archeryDefaultProjectileVisual(weapon, ammo)}
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local targets = self:archeryAcquireTargets(nil, {one_shot=true})
		if not targets then return end
		local dam = t.getDamage(self,t)
		self:archeryShoot(targets, t, nil, {mult=dam})
		game:onTickEnd(function()
			if self:knowTalent(self.T_CONCEALMENT) and not self:isTalentActive(self.T_CONCEALMENT)  then
				self.talents_cd[self.T_CONCEALMENT] = 0
				self:forceUseTalent(self.T_CONCEALMENT, {ignore_energy=true, silent = true})
			end
		end)
		game.level.map:redisplay()
		return true
	end,
	info = function(self, t)
		local dam = t.getDamage(self,t)*100
		local radius = self:getTalentRadius(t)
		return ([[Fire an arrow tipped with a smoke bomb, inflicting %d%% damage. The bomb will create a radius %d cloud of smoke on impact for 4 turns that blocks line of sight.
You take advantage of this distraction to immediately enter Concealment.]]):
		format(dam, radius)
	end,
}

newTalent{
	name = "Aim",
	type = {"technique/sniper", 3},
	mode = "sustained",
	points = 5,
	require = techs_dex_req_high3,
	cooldown = 30,
	sustain_stamina = 50,
	tactical = { BUFF = 2 },
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent, "bow") end,
	getPower = function(self, t) return math.floor(self:combatTalentScale(t, 10, 45)) end,
	getSpeed = function(self, t) return math.floor(self:combatTalentLimit(t, 150, 50, 110)) end,
	getDamage = function(self, t) return math.floor(self:combatTalentLimit(t, 10, 1, 5)) end,
	sustain_slots = 'archery_stance',
	activate = function(self, t)
		local weapon = self:hasArcheryWeapon()
		if not weapon then
			game.logPlayer(self, "You cannot use Aim without a bow or sling!")
			return nil
		end

		local power = t.getPower(self,t)
		local speed = t.getSpeed(self,t)
		return {
			atk = self:addTemporaryValue("combat_dam", power),
			dam = self:addTemporaryValue("combat_atk", power),
			speed = self:addTemporaryValue("slow_projectiles_outgoing", -speed),
		}
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("slow_projectiles_outgoing", p.speed)
		self:removeTemporaryValue("combat_atk", p.atk)
		self:removeTemporaryValue("combat_dam", p.dam)
		return true
	end,
	info = function(self, t)
		local power = t.getPower(self,t)
		local speed = t.getSpeed(self,t)
		local dam = t.getDamage(self,t)
		return ([[Enter a calm, focused stance, increasing physical power and accuracy by %d and projectile speed by %d%%.
This makes your shots more effective at range, increasing all damage dealt by %d%% per tile travelled beyond 3, to a maximum of %d%% damage at range 10.]]):
		format(power, speed, dam, dam*7)
	end,
}

newTalent{
	name = "Snipe",
	type = {"technique/sniper", 4},
	points = 5,
	random_ego = "attack",
	stamina = 30,
	cooldown = 8,
	require = techs_dex_req_high4,
	range = archery_range,
	requires_target = true,
	tactical = { ATTACK = { weapon = 3 }, },
	no_npc_use = true, --no way am i giving a npc a 300%+ ranged shot
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent, "bow") end,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 1.4, 3.0) end, -- very high damage as this effectively takes 2 turns
	getDamageReduction = function(self, t) return math.floor(self:combatTalentLimit(t, 100, 25, 70)) end,
	action = function(self, t)
		local dam = t.getDamage(self,t)
		local reduction = t.getDamageReduction(self,t)
		self:setEffect(self.EFF_SNIPE, 2, {src=self, power=reduction, dam=dam})
		local eff = self:hasEffect("EFF_SNIPE")
		eff.dur = eff.dur - 1

		return true
	end,
	info = function(self, t)
		local dam = t.getDamage(self,t)*100
		local reduction = t.getDamageReduction(self,t)
		return ([[Take aim for 1 turn, preparing a deadly shot. During the next turn, this talent will be replaced with the ability to fire a lethal shot dealing %d%% damage and marking the target.
While aiming, your intense focus causes you to shrug of %d%% incoming damage and all negative effects.]]):
		format(dam, reduction)
	end,
}

newTalent{
	name = "Snipe", short_name = "SNIPE_FIRE",
	type = {"technique/other", 1},
	no_energy = "fake",
	points = 1,
	random_ego = "attack",
	range = archery_range,
	requires_target = true,
	tactical = { ATTACK = { weapon = 4 }, },
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent) end,
	archery_onhit = function(self, t, target, x, y)
		target:setEffect(target.EFF_MARKED, 5, {src=self})
	end,
	target = function(self, t) return {type = "hit", range = self:getTalentRange(t), talent = t } end,
	action = function(self, t)
		local eff = self:hasEffect(self.EFF_SNIPE)
		if not eff then return nil end
		
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not x or not y then return end
		
		local target = game.level.map(x, y, game.level.map.ACTOR)
		
		if not target then return nil end
		local targets = self:archeryAcquireTargets(tg, {one_shot=true, x=target.x, y=target.y})

		if not targets then return end

		self:archeryShoot(targets, t, {type = "hit", speed = 200}, {mult=eff.dam, atk=100})
		
		self:removeEffect(self.EFF_SNIPE)
		
		return true
	end,
	info = function(self, t)
		return ([[Fire a lethal shot. This shot will bypass other enemies between you and your target, and gains 100 increased accuracy.]]):
		format(dam, reduction)
	end,
}