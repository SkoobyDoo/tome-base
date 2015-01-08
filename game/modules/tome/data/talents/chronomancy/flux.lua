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
	name = "Induce Anomaly",
	type = {"chronomancy/flux", 1},
	require = chrono_req1,
	points = 5,
	cooldown = 12,
	tactical = { PARADOX = 2 },
	getReduction = function(self, t) return self:combatTalentSpellDamage(t, 20, 80, getParadoxSpellpower(self, t)) end,
	getAnomalySpeed = function(self, t) return self:combatTalentLimit(t, 1, 0.10, .75) end,
	anomaly_type = "no-major",
	no_energy = true,
	passives = function(self, t, p)
		self:talentTemporaryValue(p, "anomaly_recovery_speed", t.getAnomalySpeed(self, t))
	end,
	action = function(self, t)
		local reduction = self:spellCrit(t.getReduction(self, t))
		self:paradoxDoAnomaly(reduction, t.anomaly_type, "forced")
		return true
	end,
	info = function(self, t)
		local reduction = t.getReduction(self, t)
		local anomaly_speed = (1 - t.getAnomalySpeed(self, t)) * 100
		return ([[Create an anomaly, reducing your Paradox by %d.  This spell will never produce a major anomaly.
		Additionally random anomalies only cost you %d%% of a turn rather than a full turn when they occur.
		The Paradox reduction will increase with your Spellpower.]]):format(reduction, anomaly_speed)
	end,
}

newTalent{
	name = "Reality Smearing",
	type = {"chronomancy/flux", 2},
	require = chrono_req2,
	mode = "sustained", 
	sustain_paradox = 0,
	points = 5,
	cooldown = 10,
	tactical = { DEFEND = 2 },
	getPercent = function(self, t) return self:combatTalentLimit(t, 50, 10, 30)/100 end, -- Limit < 50%
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 3, 6))) end,
	getConversionRatio = function(self, t) return 200 / self:combatTalentSpellDamage(t, 60, 600) end,
	damage_feedback = function(self, t, p, src)
		if p.particle and p.particle._shader and p.particle._shader.shad and src and src.x and src.y then
			local r = -rng.float(0.2, 0.4)
			local a = math.atan2(src.y - self.y, src.x - self.x)
			p.particle._shader:setUniform("impact", {math.cos(a) * r, math.sin(a) * r})
			p.particle._shader:setUniform("impact_tick", core.game.getTime())
		end
	end,
	iconOverlay = function(self, t, p)
		local val = p.rest_count or 0
		if val <= 0 then return "" end
		local fnt = "buff_font"
		return tostring(math.ceil(val)), fnt
	end,
	doRealitySmearing = function(self, t, src, dam)
		local absorb = dam * t.getPercent(self, t)
		local paradox = absorb*t.getConversionRatio(self, t)
		self:setEffect(self.EFF_REALITY_SMEARING, t.getDuration(self, t), {paradox=paradox/t.getDuration(self, t), no_ct_effect=true})
		game:delayedLogMessage(self, nil,  "reality smearing", "#LIGHT_BLUE##Source# converts damage to paradox!")
		game:delayedLogDamage(src, self, 0, ("#LIGHT_BLUE#(%d converted)#LAST#"):format(absorb), false)
		dam = dam - absorb
		
		return dam
	end,
	activate = function(self, t)
		game:playSoundNear(self, "talents/arcane")

		local ret = {}
		if core.shader.active(4) then
			ret.particle1, ret.particle2 = self:addParticles3D("volumetric", {kind="conic_cylinder", radius=1.4, base_rotation=180, growSpeed=0.004, img="freehand_labyrinth_01"})
		else
			ret.particle1 = self:addParticles(Particles.new("time_shield", 1))
		end
		return ret
	end,
	deactivate = function(self, t, p)
		if p.particle1 then self:removeParticles(p.particle1) end
		if p.particle2 then self:removeParticles(p.particle2) end
		return true
	end,
	info = function(self, t)
		local ratio = t.getPercent(self, t) * 100
		local absorb = t.getConversionRatio(self, t) * 100
		local duration = t.getDuration(self, t)
		return ([[While active, %d%% of all damage you take increases your Paradox by %d%% of the damage absorbed over %d turns.
		The amount of Paradox damage you recieve will be reduced by your Spellpower.]]):
		format(ratio, absorb, duration)
	end,
}

newTalent{
	name = "Attenuate",
	type = {"chronomancy/flux", 3},
	require = chrono_req3,
	points = 5,
	cooldown = 4,
	tactical = { ATTACKAREA = { TEMPORAL = 2 } },
	range = 10,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 1, 2)) end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 25, 290, getParadoxSpellpower(self, t)) end,
	getDuration = function(self, t) return getExtensionModifier(self, t, 4) end,
	getReduction = function(self, t) return self:getTalentLevel(t) * 2 end,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), selffire=false, nowarning=true, talent=t}
	end,
	requires_target = true,
	direct_hit = true,
	getDamageType = function(self, t)
		local damage_type = DamageType.TEMPORAL
		local dt_name = "temporal"
		if self:isTalentActive(self.T_GRAVITY_LOCUS) then
			damage_type = DamageType.PHYSICAL
			dt_name = "physical"
		end
		return damage_type, dt_name
	end,
	doAnomaly = function(self, t, target, eff)
		self:project({type=hit}, target.x, target.y, t.getDamageType(self, t), eff.power * eff.dur)
		target:removeEffect(target.EFF_ATTENUATE)
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		
		local damage = self:spellCrit(t.getDamage(self, t))
		local dt_type, dt_name = t.getDamageType(self, t)
		self:project(tg, x, y, function(px, py)
			local target = game.level.map(px, py, Map.ACTOR)
			if not target then return end
			target:setEffect(target.EFF_ATTENUATE, t.getDuration(self, t), {power=damage/4, src=self, dt_type=dt_type, dt_name=dt_name, reduction=t.getReduction(self, t), apply_power=getParadoxSpellpower(self, t)})
		end)

		game.level.map:particleEmitter(x, y, tg.radius, "temporal_flash", {radius=tg.radius})

		game:playSoundNear(self, "talents/tidalwave")

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local duration = t.getDuration(self, t)
		local radius = self:getTalentRadius(t)
		local reduction = t.getReduction(self, t)
		local dt_type, dt_name = t.getDamageType(self, t)
		return ([[Deals %0.2f %s over %d turns to all other targets in a radius of %d.  If the target is slain before the effect expires you'll recover %d Paradox.
		If the target is hit by an Anomaly the remaining damage will be done instantly.
		The damage will scale with your Spellpower.]]):format(damDesc(self, dt_type, damage), dt_name, duration, radius, reduction)
	end,
}

newTalent{
	name = "Flux Control",
	type = {"chronomancy/flux", 4},
	require = chrono_req4,
	points = 5,
	cooldown = 10,
	-- Anomaly biases can be set manually for monsters
	-- Use the following format anomaly_bias = { type = "teleport", chance=50}
	no_npc_use = true,  -- so rares don't learn useless talents
	allow_temporal_clones = true,  -- let clones copy it anyway so they can benefit from the effects
	on_pre_use = function(self, t, silent) if self ~= game.player then return false end return true end,  -- but don't let them cast it
	getBiasChance = function(self, t) return self:combatTalentLimit(t, 100, 10, 75) end,
	getTargetChance = function(self, t) return self:combatTalentLimit(t, 100, 10, 75) end,
	getParadoxMulti = function(self, t) return self:combatTalentLimit(t, 2, 0.10, .75) end,
	passives = function(self, t, p)
		self:talentTemporaryValue(p, "anomaly_paradox_recovery", t.getParadoxMulti(self, t))
	end,
	on_learn = function(self, t)
		if self.anomaly_bias and self.anomaly_bias.chance then
			self.anomaly_bias.chance = t.getBiasChance(self, t)
		end
	end,
 	on_unlearn = function(self, t)
		if self:getTalentLevel(t) == 0 then
			self.anomaly_bias = nil
		elseif self.anomaly_bias and self.anomaly_bias.chance then
			self.anomaly_bias.chance = t.getBiasChance(self, t)
		end
 	end,
	action = function(self, t)
		local state = {}
		local Chat = require("engine.Chat")
		local chat = Chat.new("chronomancy-bias-weave", {name="Bias Weave"}, self, {version=self, state=state})
		local d = chat:invoke()
		local co = coroutine.running()
		d.unload = function() coroutine.resume(co, state.set_bias) end
		if not coroutine.yield() then return nil end
		return true
	end,
	info = function(self, t)
		local target_chance = t.getTargetChance(self, t)
		local bias_chance = t.getBiasChance(self, t)
		local paradox = 100 * t.getParadoxMulti(self, t)
		return ([[You've learned to focus non-major anomalies and may choose the target area with %d%% probability.
		You may also activate this talent to pick an anomaly bias; choosing the type of anomaly effects you produce with %d%% probability (%d%% for major anomalies).
		Additionally you recover %d%% more Paradox from random anomalies (%d%% total).]]):format(target_chance, bias_chance, bias_chance/2, paradox, paradox + 200)
	end,
}