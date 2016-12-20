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

newTalent{
	name = "Disengage",
	type = {"technique/mobility", 1},
	require = techs_dex_req1,
	points = 5,
	random_ego = "utility",
	cooldown = 10,
	stamina = 12,
	range = 7,
	getSpeed = function(self, t) return self:combatTalentScale(t, 100, 250, 0.75) end,
	getReload = function(self, t) return math.floor(self:combatTalentScale(t, 2, 10)) end,
	tactical = { ESCAPE = 2 },
	requires_target = true,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	on_pre_use = function(self, t)
		if self:attr("never_move") then return false end
		return true
	end,
	getDist = function(self, t) return math.floor(self:combatTalentScale(t, 3, 7)) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end

		self:knockback(target.x, target.y, t.getDist(self, t))
		
		if self:getTalentLevel(t) >= 4 then
			self:setEffect("EFF_AVOIDANCE", 1, {power=100})
			local eff = self:hasEffect("EFF_AVOIDANCE")
			eff.dur = eff.dur - 1
		end
		
		game:onTickEnd(function()
			self:setEffect(self.EFF_WILD_SPEED, 3, {power=t.getSpeed(self,t)}) 
		end)
		
		local weapon, ammo, offweapon = self:hasArcheryWeapon()	
		if weapon and ammo and not ammo.infinite then
			ammo.combat.shots_left = math.min(ammo.combat.shots_left + t.getReload(self, t), ammo.combat.capacity)
			game.logSeen(self, "%s reloads.", self.name:capitalize())
		end

		return true
	end,
	info = function(self, t)
		return ([[Jump away %d grids from your target and gain a burst of speed on landing, increasing you movement speed by %d%% for 3 turns.
		Any actions other than movement will end the speed boost.
		At talent level 4 you avoid all attacks against you while disengaging.
		If you have a quiver equip, you also take the time to reload %d shots.]]):
		format(t.getDist(self, t), t.getSpeed(self,t), t.getReload(self,t))
	end,
}

newTalent {
	name = "Tumble",
	type = {"technique/mobility", 2},
	require = techs_dex_req2,
	points = 5,
	random_ego = "attack",
	cooldown = function(self, t) 
		return math.max(10 - self:getTalentLevel(t), 1) 
	end,
	no_energy = true,
	no_break_stealth = true,
	tactical = { ESCAPE = 2 },
	stamina = function(self, t)
		local eff = self:hasEffect(self.EFF_EXHAUSTION)
		if eff and eff.charges then
			return 15 + eff.charges*15
		else
			return 15
		end
	end,
	range = function(self, t)
		return math.floor(self:combatTalentScale(t, 2, 4))
	end,
	getDuration = function(self, t)
		return math.max(20 - self:getTalentLevel(t), 5)
	end,
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
			self:setEffect(self.EFF_EXHAUSTION, t.getDuration(self,t), { max_stacks=5 })
		end)
		
		return true
	end,
	info = function(self, t)
		return ([[Move to a spot within range, bounding around, over, or through any enemies in the way. This can be used while pinned, and does not break stealth.
		This quickly becomes exhausting to use, increasing the stamina cost by 15 for %d turns after use.]]):format(t.getDuration(self,t))
	end
}

newTalent {
	name = "Trained Reactions",
	type = {"technique/mobility", 3},
	mode = "sustained",
	points = 5,
	cooldown = function(self, t) return 10 end,
	sustain_stamina = 10,
	no_energy = true,
	require = techs_dex_req3,
	tactical = { BUFF = 2 },
	activate = function(self, t)
		return {}
	end,
	deactivate = function(self, t, p)
		return true
	end,
	getLifeTrigger = function(self, t)
		return self:combatTalentLimit(t, 10, 40, 22)
	end,
	getReduction = function(self, t) 
		return (0.05 + (self:combatTalentLimit(t, 1, 0.15, 0.50) * self:combatLimit(self:combatDefense(), 1, 0.20, 10, 0.50, 50)))*100
	end,
	callbackOnHit = function(self, t, cb, src)
		if cb.value >= self.max_life * t.getLifeTrigger(self, t) * 0.01 and use_stamina(self, 10) then
				-- Apply effect with duration 0.
				self:setEffect("EFF_SKIRMISHER_DEFENSIVE_ROLL", 1, {reduce = t.getReduction(self, t)})
				local eff = self:hasEffect("EFF_SKIRMISHER_DEFENSIVE_ROLL")
				eff.dur = eff.dur - 1

				cb.value = cb.value * (100-t.getReduction(self, t)) / 100
		end
		return cb.value
	end,
	info = function(self, t)
		local trigger = t.getLifeTrigger(self, t)
		local reduce = t.getReduction(self, t)
		return ([[While this talent is sustained, you anticipate deadly attacks against you.
		Any time you would lose more than %d%% of your life in a single hit, you instead duck out of the way and assume a defensive posture.
		This reduces the triggering damage and all further damage in the same turn by %d%%.
		This costs 10 stamina each time it triggers.
		The damage reduction increases based on your Defense.]])
		:format(trigger, reduce, cost)
	end,
}

newTalent{
	name = "Evasion",
	type = {"technique/mobility", 4},
	points = 5,
	require = techs_dex_req4,
	random_ego = "defensive",
	tactical = { ESCAPE = 2, DEFEND = 2 },
	cooldown = 30,
	stamina = 20,
	no_energy = true,
	getDur = function(self, t) return math.floor(self:combatTalentLimit(t, 30, 5, 9)) end, -- Limit < 30
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
		return ([[Your quick wit allows you to see melee attacks before they land, granting you a %d%% chance to completely evade them and granting you %d defense for %d turns.
		The chance to evade and defense increases with your Dexterity.]]):
		format(chance, def,t.getDur(self,t))
	end,
}