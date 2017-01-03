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
	name = "Evasion",
	type = {"technique/mobility", 1},
	points = 5,
	require = techs_dex_req1,
	random_ego = "defensive",
	tactical = { ESCAPE = 2, DEFEND = 2 },
	cooldown = 30,
	base_stamina = 20,
	stamina = mobility_stamina,
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
		return ([[Your quick wit and reflexes allow you to anticipate melee attacks, granting you a %d%% chance to completely evade them plus %d defense for %d turns.
		The chance to evade and defense bonus increase with your Dexterity.]]):
		format(chance, def,t.getDur(self,t))
	end,
}

newTalent{
	name = "Disengage",
	type = {"technique/mobility", 2},
	require = techs_dex_req2,
	points = 5,
	random_ego = "utility",
	cooldown = 10,
	base_stamina = 12,
	stamina = mobility_stamina,
	range = 7,
	getSpeed = function(self, t) return self:combatTalentScale(t, 100, 200, "log") end,
	getReload = function(self, t) return math.floor(self:combatTalentScale(t, 2, 10)) end,
	tactical = { ESCAPE = 2, DEFEND = 0.5, AMMO = 0.5 },
	requires_target = true,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	on_pre_use = mobility_pre_use,
	getDist = function(self, t) return math.floor(self:combatTalentLimit(t, 11, 2, 5.5)) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end

		if not self:hasEffect(self.EFF_EVASION) then
			self:forceUseTalent(self.T_EVASION, {ignore_cd=true, ignore_energy=true, silent=true, ignore_ressources=true, force_level=math.max(1, self:getTalentLevelRaw(self.T_EVASION))})
			local eff = self:hasEffect(self.EFF_EVASION)
			if eff then eff.dur = 1 end
		end
		
		game:onTickEnd(function()
			self:setEffect(self.EFF_WILD_SPEED, 3, {power=t.getSpeed(self,t)}) 
		end)
		
		self:knockback(target.x, target.y, t.getDist(self, t))
		self:reload()

		return true
	end,
	info = function(self, t)
		return ([[Jump back %d grids from your target and gain %d%% increased movement speed for 3 turns.
		As part of this move, you will also gain 1 turn of Evasion for free and perform one turn's reloading of your equipped ammo after moving.
		The extra speed ends if you take any actions other than movement.
		This talent is not usable with heavy armor or while immobilized.]]):
		format(t.getDist(self, t), t.getSpeed(self,t))
	end,
}

newTalent {
	name = "Tumble",
	type = {"technique/mobility", 3},
	require = techs_dex_req3,
	points = 5,
	random_ego = "attack",
	on_pre_use = mobility_pre_use,
	cooldown = function(self, t) return math.ceil(self:combatTalentLimit(t, 3, 10, 6)) end,
	no_energy = true,
	no_break_stealth = true,
	tactical = { CLOSEIN = 2 },
--	tactical = { ESCAPE = 2, CLOSEIN = 2 }, -- update with AI
	base_stamina = 10,
	stamina = mobility_stamina,
	getExhaustion = function(self, t) return self:combatTalentLimit(t, 20, 50, 35) end,
	range = function(self, t) return math.floor(self:combatTalentScale(t, 2, 5, "log")) end,
	getDuration = function(self, t)	return math.ceil(self:combatTalentLimit(t, 5, 20, 10)) end, -- always >=2 turns higher than cooldown
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

-- Could let player/NPC select sensitivity to damage instead of simple toggle.
newTalent {
	name = "Trained Reactions",
	type = {"technique/mobility", 4},
	mode = "sustained",
	points = 5,
	require = techs_dex_req4,
	sustain_stamina = 10,
	no_energy = true,
	tactical = { DEFEND = 2 },
	pinImmune = function(self, t) return self:combatTalentLimit(t, 1, .17, .5) end, -- limit < 100%
	passives = function(self, t, p)
		self:talentTemporaryValue(p, "pin_immune", t.pinImmune(self, t))
	end,
	on_pre_use = function(self, t, silent, fake)
		if self:hasHeavyArmor() then
			if not silent then game.logPlayer(self, "%s is not usable while wearing heavy armour.", t.name) end
			return
		end
		return true
	end,
	getReduction = function(self, t, fake) -- get % reduction based on TL and defense
		return self:combatTalentLimit(t, 0.9, 0.15, 0.7)*self:combatLimit(self:combatDefense(fake), 0.9, 0.20, 10, 0.70, 50) -- vs TL/def: 1/10 == ~3%, 1.3/10 == ~6%, 1.3/50 == ~19%, 6.5/50 == ~52%, 6.5/100 = ~59%
	end,
	getStamina = function(self, t) return 10*(1 + self:combatFatigue()/100)*math.max(0.1, self:combatTalentLimit(t, 1, 0.17, 0.8)) end, -- scales up with effectiveness (gets more efficient with TL)
	getLifeTrigger = function(self, t, cur_stam)
		local percent_hit = self:combatTalentLimit(t, 10, 35, 20)
		local stam_cost = t.getStamina(self, t)
		cur_stam = cur_stam or self:getStamina()
		return percent_hit*util.bound(10*stam_cost/cur_stam, .5, 2) -- == 1 @ 10% stamina cost
	end,
	callbackOnTakeDamage = function(self, t, src, x, y, type, dam, state)
		if state and (state.is_melee or state.is_archery) and not self:attr("encased_in_ice") and not self:attr("invulnerable") then
			local stam, stam_cost = self:getStamina()
			-- don't charge stamina more than once per attack (state set in Combat.attackTargetWith)
			if self.turn_procs[t.id] ~= state then
				stam_cost = t.getStamina(self, t)
				self.turn_procs[t.id] = state
			else
				stam_cost = 0
			end
			--game.log("#GREY#Trained Reactions test for %s: %s %s damage from %s", self.name, dam, type, src.name)
			if stam_cost < stam and dam > self.life*t.getLifeTrigger(self, t, stam)/100 then
				self:incStamina(-stam_cost) -- Note: force_talent_ignore_ressources has no effect on this
				local reduce = t.getReduction(self, t)*(self:attr("never_move") and 0.5 or 1)
				if stam_cost > 0 then src:logCombat(self, "#Target# reacts to an attack from #source#, avoiding some damage!") end

				dam = dam*(1-reduce)
				print("[PROJECTOR] dam after callbackOnTakeDamage", t.id, dam)
				return {dam = dam}
			end
		end
	end,
	activate = function(self, t)
		local ret = {}
		ret.life_trigger, ret.life_level = t.getLifeTrigger(self, t)
		return ret
	end,
	deactivate = function(self, t, p)
		return true
	end,
	info = function(self, t)
		local stam = t.getStamina(self, t)
		local triggerMin, triggerFull, triggerCur = t.getLifeTrigger(self, t, stam), t.getLifeTrigger(self, t, self:getMaxStamina()), t.getLifeTrigger(self, t)
		local reduce = t.getReduction(self, t, true)*100
		return ([[You have trained to be very light on your feet and have conditioned your reflexes to react faster than thought to attacks as they strike you.
		You permanently gain %d%% pinning immunity.
		While this talent is active, you reduce the damage of significant melee or archery attacks hitting you by %d%% (improved with Defense).  This requires %0.1f stamina per attack.
		The nearly instant reactions required are both difficult and exhausting; they cannot be performed while wearing heavy armor and are only half effective if you are immobilized.
		Larger attacks are easier to react to and you become more vigilant when wounded, but your reactions slow as your stamina is depleted.  The smallest attack your reflexes can affect, as a percent of your current life (currently %d%%), ranges from %d%% at full Stamina to %d%% with minimum Stamina.]])
		:format(t.pinImmune(self, t)*100, reduce, stam, triggerCur, triggerFull, triggerMin)
	end,
}

