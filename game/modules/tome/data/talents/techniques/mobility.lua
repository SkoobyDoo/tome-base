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

local Map = require "engine.Map"

local function mobility_pre_use(self, t, silent, fake)
	if self:attr("never_move") then
		if not silent then game.logPlayer(self, "You must be able to move to use %s!", t.name) end
		return
	elseif self:hasHeavyArmor() then
		if not silent then game.logPlayer(self, "%s is not usable while wearing heavy armour.", t.name) end
		return
	end
	return true
end

local function mobility_stamina(self, t)
	local cost = t.base_stamina or 0
	local eff = self:hasEffect(self.EFF_EXHAUSTION)
	if eff then cost = cost*(1 + eff.fatigue/100) end
	return cost
end

newTalent{
	name = "Disengage",
	type = {"technique/mobility", 1},
	require = techs_dex_req1,
	points = 5,
	random_ego = "utility",
	cooldown = 10,
	base_stamina = 8,
	stamina = mobility_stamina,
	range = 7,
	getSpeed = function(self, t) return self:combatTalentScale(t, 100, 200, "log") end,
	getReload = function(self, t) return math.floor(self:combatTalentScale(t, 2, 8)) end,
	getNb = function(self, t) return math.floor(self:combatTalentScale(t, 1, 3)) end,
	tactical = { ESCAPE = 2, AMMO = 0.5 },
	requires_target = true,
	target = function(self, t) return {type="bolt", range=self:getTalentRange(t)} end,
	getDist = function(self, t) return math.floor(self:combatTalentLimit(t, 10, 3, 7)) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end
		
		local dist = core.fov.distance(self.x, self.y, x, y) + t.getDist(self,t)

		local tg2 = {type="beam", source_actor = target, range=dist, talent=t}	
		local tx, ty, t2 = self:getTarget(tg2)
		if not tx or not ty or t2 or game.level.map:checkEntity(tx, ty, Map.TERRAIN, "block_move", self) then
			game.logPlayer(self, "You must have an empty space to disengage to.")
			return false
		end
		
		if (self:attr("never_move") and self:hasHeavyArmor()) or self:attr("encased_in_ice") then
			if not silent then game.logPlayer(self, "You must be able to move to use %s!", t.name) end
		return end
		
		local check = false
		
		local block_actor = function(_, bx, by) return game.level.map:checkEntity(bx, by, Map.TERRAIN, "block_move", self) end
		local linestep = target:lineFOV(tx, ty, block_actor)

		local x2, y2, lx, ly, is_corner_blocked
		repeat  -- make sure each tile is passable
			x2, xy = lx, ly
			lx, ly, is_corner_blocked = linestep:step()
			if self.x == lx and self.y == ly then check = true end
		until is_corner_blocked or not lx or not ly or game.level.map:checkAllEntities(lx, ly, "block_move", self)


		if not check then
			game.logPlayer(self, "You must disengage away from your target in a straight line.")
			return
		end
		
		self:move(tx, ty, true)

		if not self:hasHeavyArmor() then		
			game:onTickEnd(function()
				self:setEffect(self.EFF_WILD_SPEED, 3, {power=t.getSpeed(self,t)}) 
			end)
		end
		
		local weapon, ammo, offweapon = self:hasArcheryWeapon()	
		if weapon and ammo and not ammo.infinite then
			ammo.combat.shots_left = math.min(ammo.combat.shots_left + t.getReload(self, t), ammo.combat.capacity)
			game.logSeen(self, "%s reloads.", self.name:capitalize())
		end

		if self:knowTalent(self.T_THROWING_KNIVES) then
			local max = self:callTalent(self.T_THROWING_KNIVES, "getNb")
			local reload = math.min(max, t.getReload(self,t))
			self:setEffect(self.EFF_THROWING_KNIVES, 1, {stacks=reload, max_stacks=max })
		end

		return true
	end,
	info = function(self, t)
		return ([[Jump back up to %d grids from your target, as well as reloading up to %d of your equipped ammo or throwing knives.
		You must disengage in a straight line (the targeting line must pass through your character).
		If you are not wearing heavy armor, you also gain %d%% increased movement speed and may use this talent while pinned. The extra speed ends if you take any actions other than movement.]]):
		format(t.getDist(self, t), t.getReload(self,t), t.getSpeed(self,t), t.getNb(self,t))
	end,
}

newTalent{
	name = "Evasion",
	type = {"technique/mobility", 2},
	points = 5,
	require = techs_dex_req2,
	random_ego = "defensive",
	tactical = { ESCAPE = 2, DEFEND = 2 },
	cooldown = function(self, t) return math.ceil(self:combatTalentLimit(t, 15, 30, 20)) end, --shorter cooldown but less duration - as especially on randbosses a long duration evasion is frustrating, this makes it a bit more useful for hit and run
	base_stamina = 25,
	stamina = mobility_stamina,
	no_energy = true,
	getDur = function(self, t) return 5 end,
	getChanceDef = function(self, t)
		if self.perfect_evasion then return 100, 0 end
		return self:combatLimit(5*self:getTalentLevel(t) + self:getDex(50,true), 50, 10, 10, 37.5, 75),
		self:combatScale(self:getTalentLevel(t) * (self:getDex(50, true)), 0, 0, 55, 250, 0.75)
		-- Limit evasion chance < 50%, defense bonus ~= 55 at level 50
	end,
	speed = "combat",
	action = function(self, t)
		local dur = t.getDur(self,t)
		local chance, def = t.getChanceDef(self,t)
		self:setEffect(self.EFF_EVASION, dur, {chance=chance, defense = def})
		return true
	end,
	info = function(self, t)
		local chance, def = t.getChanceDef(self,t)
		return ([[Your quick wit and reflexes allow you to anticipate attacks against you, granting you a %d%% chance to evade melee and ranged attacks and %d increased defense for %d turns.
		The chance to evade and defense bonus increase with your Dexterity.]]):
		format(chance, def,t.getDur(self,t))
	end,
}

--quite expensive to use repeatedly but gives a low cooldown instant movement which is super powerful, and at 4/5 the exhaustion will never stack beyond 66~%
newTalent {
	name = "Tumble",
	type = {"technique/mobility", 3},
	require = techs_dex_req3,
	points = 5,
	random_ego = "attack",
	on_pre_use = mobility_pre_use,
	cooldown = function(self, t) return math.ceil(self:combatTalentLimit(t, 4, 13, 7)) end,
	no_energy = true,
	no_break_stealth = true,
	tactical = { CLOSEIN = 2 },
--	tactical = { ESCAPE = 2, CLOSEIN = 2 }, -- update with AI
	base_stamina = 20,
	stamina = mobility_stamina,
	getExhaustion = function(self, t) return self:combatTalentLimit(t, 25, 75, 40) end,
	range = function(self, t) return math.floor(self:combatTalentScale(t, 2, 4, "log")) end,
	getDuration = function(self, t)	return math.ceil(self:combatTalentLimit(t, 5, 25, 15)) end, -- always >=2 turns higher than cooldown
	target = function(self, t)
		return {type="beam", range=self:getTalentRange(t), talent=t}
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not x or not y then return end
		if self.x == x and self.y == y then return end
		if core.fov.distance(self.x, self.y, x, y) > self:getTalentRange(t) or not self:hasLOS(x, y) then return end

		if target or game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move", self) then
			game.logPlayer(self, "You must have an empty space to roll to.")
			return false
		end

		self:move(x, y, true)
		
		game:onTickEnd(function()
			self:setEffect(self.EFF_EXHAUSTION, t.getDuration(self,t), { fatigue = t.getExhaustion(self, t) })
		end)
		
		return true
	end,
	info = function(self, t)
		return ([[In an extreme feat of agility, you move to a spot you can see within range, bounding around, over, or through any enemies in the way.
		This talent cannot be used while wearing heavy armor, and leaves you exhausted.  The exhaustion increases the cost of your activated Mobility talents by %d%% (stacking), but fades over %d turns.]]):format(t.getExhaustion(self, t), t.getDuration(self, t))
	end
}

newTalent{
	name = "Trained Reactions",
	type = {"technique/mobility", 4},
	require = techs_dex_req4,
	tactical = { BUFF = 2 },
	points = 5,
	stamina_per_use = function(self, t) return 10 end,
	sustain_stamina = 10,
	no_energy = true,
	getDamageReduction = function(self, t) 
		return self:combatTalentLimit(t, 1, 0.15, 0.50) * self:combatLimit(self:combatDefense(), 1, 0.15, 10, 0.5, 50) -- Limit < 100%, 25% for TL 5.0 and 50 defense
	end,
	getDamagePct = function(self, t)
		return self:combatTalentLimit(t, 0.1, 0.3, 0.15) -- Limit trigger > 10% life
	end,
	activate = function(self, t)
		return {}
	end,
	deactivate = function(self, t, p)
		return true
	end,
	callbackOnHit = function(self, t, cb)
		local cost = t.stamina_per_use(self, t)
		if ( cb.value > (t.getDamagePct(self, t) * self.max_life) and use_stamina(self, cost) ) then
			local damageReduction = cb.value * t.getDamageReduction(self, t)
			cb.value = cb.value - damageReduction
			game.logPlayer(self, "#GREEN#You evade part of the attack, reducing the damage by #ORCHID#" .. math.ceil(damageReduction) .. "#LAST#.")
		end
		return cb.value
	end, 
	info = function(self, t)
		local cost = t.stamina_per_use(self, t) * (1 + self:combatFatigue() * 0.01)
		return ([[While this talent is sustained, you anticipate deadly attacks against you.  Whenever you would receive damage (from any source) greater than %d%% of your maximum life you duck out of the way and assume a defensive posture, reducing that damage by %0.1f%% (based on your Defense).
		This costs %0.1f Stamina to use, and fails if you do not have enough.]]):
		format(t.getDamagePct(self, t)*100, t.getDamageReduction(self, t)*100, cost)
	end,
}