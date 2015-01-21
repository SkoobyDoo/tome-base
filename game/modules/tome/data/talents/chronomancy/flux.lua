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
	getParadoxMulti = function(self, t) return self:combatTalentLimit(t, 2, 0.10, .75) end,
	anomaly_type = "no-major",
	passives = function(self, t, p)
		self:talentTemporaryValue(p, "anomaly_paradox_recovery", t.getParadoxMulti(self, t))
	end,
	action = function(self, t)
		local reduction = self:spellCrit(t.getReduction(self, t))
		self:paradoxDoAnomaly(reduction, t.anomaly_type, "forced")
		return true
	end,
	info = function(self, t)
		local reduction = t.getReduction(self, t)
		local paradox = 100 * t.getParadoxMulti(self, t)
		return ([[Create an anomaly, reducing your Paradox by %d.  This spell will never produce a major anomaly.
		Additionally you recover %d%% more Paradox from random anomalies when they occur (%d%% total).
		The Paradox reduction will increase with your Spellpower.]]):format(reduction, paradox, paradox + 200)
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
	callbackOnHit = function(self, t, cb, src)
		local absorb = cb.value * t.getPercent(self, t)
		local paradox = absorb*t.getConversionRatio(self, t)
		self:setEffect(self.EFF_REALITY_SMEARING, t.getDuration(self, t), {paradox=paradox/t.getDuration(self, t), no_ct_effect=true})
		game:delayedLogMessage(self, nil,  "reality smearing", "#LIGHT_BLUE##Source# converts damage to paradox!")
		game:delayedLogDamage(src, self, 0, ("#LIGHT_BLUE#(%d converted)#LAST#"):format(absorb), false)
		cb.value = cb.value - absorb
		
		return cb.value
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
		
		local particle_name = "temporal_flash"
		if dt_name == "physical" then particle_name = "gravity_spike" end
		game.level.map:particleEmitter(x, y, tg.radius, particle_name, {radius=tg.radius})
		game:playSoundNear(self, "talents/tidalwave")

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local duration = t.getDuration(self, t)
		local radius = self:getTalentRadius(t)
		local reduction = t.getReduction(self, t)
		local dt_type, dt_name = t.getDamageType(self, t)
		return ([[Deals %0.2f %s damage over %d turns to all other targets in a radius of %d.  If the target is slain before the effect expires you'll recover %d Paradox.
		If you have Gravity Locus sustained this spell will deal physical damage, otherwise it deals temporal damage.
		If the target is hit by an Anomaly the remaining damage will be done instantly.
		The damage will scale with your Spellpower.]]):format(damDesc(self, dt_type, damage), dt_name, duration, radius, reduction)
	end,
}

newTalent{
	name = "Twist Fate",
	type = {"chronomancy/flux", 4},
	require = chrono_req4,
	points = 5,
	cooldown = 6,
	tactical = { ATTACKAREA = 2 },
	on_pre_use = function(self, t, silent) if not self:hasEffect(self.EFF_TWIST_FATE) then if not silent then game.logPlayer(self, "You must have a twisted anomaly to cast this spell.") end return false end return true end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 1, 5))) end,
	doTwistFate = function(self, t, twist)
		local eff = self:hasEffect(self.EFF_TWIST_FATE)
		eff.twisted = twist or false
		local anom = self:getTalentFromId(eff.talent)
		anom.action(self, anom)
		self:incParadox(-eff.paradox)
		self:removeEffect(self.EFF_TWIST_FATE)
	end,
	setEffect = function(self, t, talent, paradox)
		game.logPlayer(self, "#STEEL_BLUE#You take control of %s.", self:getTalentFromId(talent).name or nil)
		self:setEffect(self.EFF_TWIST_FATE, t.getDuration(self, t), {talent=talent, paradox=paradox})
	end,
	action = function(self, t)
		t.doTwistFate(self, t, true)
		return true
	end,
	info = function(self, t)
		local eff = self:hasEffect(self.EFF_TWIST_FATE)
		local talent = "None"
		if eff then talent = self:getTalentFromId(eff.talent).name end
		local duration = t.getDuration(self, t)
		return ([[If Twist Fate is not on cooldown minor anomalies will be held for %d turns, allowing your spell to cast as normal.  While held you may cast Twist Fate in order to trigger the anomaly and may choose the target area.
		If a second anomaly occurs while a prior one is held or the timed effect expires the first anomaly will trigger immediately, interrupting your current turn or action.
		Paradox reductions from held anomalies occur when triggered.
				
		Current Twisted Anomaly: %s]]):
		format(duration, talent)
	end,
}