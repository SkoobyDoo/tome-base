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

local Object = require "mod.class.Object"

newTalent{
	name = "Static History",
	type = {"chronomancy/stasis",1},
	require = chrono_req1,
	points = 5,
	cooldown = 24,
	tactical = { PARADOX = 2 },
	getDuration = function(self, t)
		local duration = math.floor(self:combatTalentScale(t, 3.5, 6.5))
		if self:knowTalent(self.T_PARADOX_MASTERY) then
			duration = duration + self:callTalent(self.T_PARADOX_MASTERY, "getStabilityDuration")
		end
		return duration
	end,
	getParadoxMulti = function(self, t) return self:combatTalentLimit(t, 2, 0.40, .60) end,
	no_energy = true,
	action = function(self, t)
		game:playSoundNear(self, "talents/spell_generic")
		self:setEffect(self.EFF_STATIC_HISTORY, t.getDuration(self, t), {power=t.getParadoxMulti(self, t)})
		return true
	end,
	info = function(self, t)
		local multi = t.getParadoxMulti(self, t) * 100
		local duration = t.getDuration(self, t)
		return ([[For the next %d turns all your chronomancy spells cost %d%% less Paradox.]]):
		format(duration, multi)
	end,
}

newTalent{
	name = "Time Shield", short_name = "CHRONO_TIME_SHIELD",
	type = {"chronomancy/stasis",2},
	require = chrono_req2,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 18,
	tactical = { DEFEND = 2 },
	range = 10,
	no_energy = true,
	getMaxAbsorb = function(self, t) return 50 + self:combatTalentSpellDamage(t, 50, 450, getParadoxSpellpower(self, t)) end,
	getDuration = function(self, t) return util.bound(5 + math.floor(self:getTalentLevel(t)), 5, 15) end,
	getTimeReduction = function(self, t) return 25 + util.bound(15 + math.floor(self:getTalentLevel(t) * 2), 15, 35) end,
	action = function(self, t)
		self:setEffect(self.EFF_TIME_SHIELD, t.getDuration(self, t), {power=t.getMaxAbsorb(self, t), dot_dur=5, time_reducer=t.getTimeReduction(self, t)})
		game:playSoundNear(self, "talents/spell_generic")
		return true
	end,
	info = function(self, t)
		local maxabsorb = t.getMaxAbsorb(self, t)
		local duration = t.getDuration(self, t)
		local time_reduc = t.getTimeReduction(self,t)
		return ([[This intricate spell instantly erects a time shield around the caster, preventing any incoming damage and sending it forward in time.
		Once either the maximum damage (%d) is absorbed, or the time runs out (%d turns), the stored damage will return as a temporal restoration field over time (5 turns).
		Each turn the restoration field is active, you get healed for 10%% of the absorbed damage (Aegis Shielding talent affects the percentage).
		While under the effect of Time Shield, all newly applied magical, physical and mental effects will have their durations reduced by %d%%.
		The shield's max absorption will increase with your Spellpower.]]):
		format(maxabsorb, duration, time_reduc)
	end,
}

newTalent{
	name = "Fractured Space",
	type = {"chronomancy/stasis",3},
	require = chrono_req_high3,
	mode = "sustained",
	sustain_paradox = 24,
	cooldown = 10,
	tactical = { BUFF = 2 },
	points = 5,
	getDamage = function(self, t) return self:combatTalentLimit(t, 100, 10, 75)/12 end,
	getChance = function(self, t) return self:combatTalentLimit(t, 100, 10, 75)/6 end,
	iconOverlay = function(self, t, p)
		local val = p.charges or 0
		if val <= 0 then return "" end
		local fnt = "buff_font"
		return tostring(math.ceil(val)), fnt
	end,
	callbackOnActBase = function(self, t)
		-- Charge decay
		local p = self:isTalentActive(self.T_FRACTURED_SPACE)
		p.decay = p.decay + 1
		if p.decay >=2 then
			p.decay = 0
			p.charges = math.max(p.charges - 1, 0)
		end
	end,
	activate = function(self, t)
		game:playSoundNear(self, "talents/heal")
		--local particle = Particles.new("ultrashield", 1, { rm=0, rM=176, gm=196, gM=255, bm=222, bM=255, am=25, aM=125, radius=0.2, density=30, life=28, instop=-40})
		return {
			charges = 0, decay = 0
		--	particle = self:addParticles(particle)
		}
	end,
	deactivate = function(self, t, p)
	--	self:removeParticles(p.particle)
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local chance = t.getChance(self, t)
		local charges = self:isTalentActive(self.T_FRACTURED_SPACE) and self:isTalentActive(self.T_FRACTURED_SPACE).charges or 0
		return ([[Each time you deal warp damage Fractured Space gains one charge, up to a maximum of six charges.  If you're not generating charges one charge will decay every other turn.
		Each charge increases warp damage by %d%% and gives your Warp damage a %d%% chance to stun, blind, pin, or confuse affected targets for 3 turns.
		If Fractured Space is fully charged, your Spatial Tears talents will consume them when cast and have bonus effects (see indvidual talent descriptions).
		
		Current damage bonus:   %d%%
		Current effect chance:  %d%%]]):format(damage, chance, damage * charges, chance * charges)
	end,
}

newTalent{
	name = "Paradox Mastery",
	type = {"chronomancy/stasis", 4},
	mode = "passive",
	points = 5,
	-- Static history bonus handled in timetravel.lua, backfire calcs performed by _M:getModifiedParadox function in mod\class\Actor.lua	
	getWilMult = function(self, t) return self:combatTalentScale(t, 0.15, 0.5) end,
	getStabilityDuration = function(self, t) return math.floor(self:combatTalentScale(t, 0.4, 2.7, "log")) end,  --This is still used by an older talent, leave it here for backwards compatability
	passives = function(self, t, p)
		self:talentTemporaryValue(p, "paradox_will_mutli", t.getWilMult(self, t))
	end,
	info = function(self, t)
		local will = t.getWilMult(self, t)
		local duration = t.getStabilityDuration(self, t)
		return ([[You've learned to focus your control over the spacetime continuum, and quell anomalous effects.  Increases your Willpower for determing modified Paradox by %d%%.
		Additionally increases the duration of Static History by %d turns.]]):
		format(will * 100, duration)
	end,
}
