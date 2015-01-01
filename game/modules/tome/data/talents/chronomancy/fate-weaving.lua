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
	name = "Spin Fate",
	type = {"chronomancy/fate-weaving", 1},
	require = chrono_req1,
	mode = "passive",
	points = 5,
	getSaveBonus = function(self, t) return math.ceil(self:combatTalentScale(t, 2, 8, 0.75)) end,
	callbackOnTakeDamage = function(self, t, src, x, y, type, dam, tmp, no_martyr)
		if dam > 0 and src ~= self then
			if self.turn_procs and not self.turn_procs.spin_fate then
				
				self:setEffect(self.EFF_SPIN_FATE, 3, {save_bonus=t.getSaveBonus(self, t), spin=1, max_spin=3})
				
				-- Set our turn procs, we do spin_fate last since it's the only one checked above
				if self.hasEffect and self:hasEffect(self.EFF_WEBS_OF_FATE) and not self.turn_procs.spin_webs then
					self.turn_procs.spin_webs = true
				elseif self.hasEffect and self:hasEffect(self.EFF_SEAL_FATE) and not self.turn_procs.spin_seal then
					self.turn_procs.spin_seal = true
				else
					self.turn_procs.spin_fate = true
				end
				
				-- Reduce damage if we know Fateweaver
				if self:knowTalent(self.T_FATEWEAVER) then
					local reduction = dam * self:callTalent(self.T_FATEWEAVER, "getReduction")
					dam = dam - reduction
					game:delayedLogDamage(src, self, 0, ("%s(%d fatewever)#LAST#"):format(DamageType:get(type).text_color or "#aaaaaa#", reduction), false)
				end				
			end
		end
		
		return {dam=dam}
	end,
	info = function(self, t)
		local save = t.getSaveBonus(self, t)
		return ([[Each time you take damage from someone else you gain one spin, increasing your defense and saves by %d for three turns.
		This effect may occur once per turn and stacks up to three spin (for a maximum bonus of %d).]]):
		format(save, save * 3)
	end,
}
newTalent{
	name = "Webs of Fate",
	type = {"chronomancy/fate-weaving", 2},
	require = chrono_req2,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 12,
	tactical = { BUFF = 2, CLOSEIN = 2, ESCAPE = 2 },
	getPower = function(self, t) return paradoxTalentScale(self, t, 15, 30, 50)/100 end,
	getDuration = function(self, t) return getExtensionModifier(self, t, 5) end,
	no_energy = true,
	action = function(self, t)
		local effs = {}
			
		-- Find all pins
		for eff_id, p in pairs(self.tmp) do
			local e = self.tempeffect_def[eff_id]
			if e.subtype.pin or e.subtype.stun then
				effs[#effs+1] = {"effect", eff_id}
			end
		end
		
		-- And remove them
		while #effs > 0 do
			local eff = rng.tableRemove(effs)

			if eff[1] == "effect" then
				self:removeEffect(eff[2])
			end
		end
		
		-- Set our power based on current spin
		local imm = t.getPower(self, t)
		local eff = self:hasEffect(self.EFF_SPIN_FATE)
		if eff then 
			imm = imm * (1 + eff.spin/3)
		end
		
		self:setEffect(self.EFF_WEBS_OF_FATE, t.getDuration(self, t), {imm=imm})
		
		return true
	end,
	info = function(self, t)
		local power = t.getPower(self, t) * 100
		local duration = t.getDuration(self, t)
		return ([[Activate to remove pins and stuns.  You also gain %d%% pin and stun immunity for %d turns.
		If you have Spin Fate active these bonuses will be increased by 33%% per spin (up to a maximum of %d%%).
		While Webs of Fate is active you may gain one additional spin per turn.  These bonuses will scale with your Spellpower.]])
		:format(power, duration, power * 2)
	end,
}

newTalent{
	name = "Fateweaver",
	type = {"chronomancy/fate-weaving", 3},
	require = chrono_req3,
	mode = "passive",
	points = 5,
	getReduction = function(self, t) return paradoxTalentScale(self, t, 10, 30, 40)/100 end,
	info = function(self, t)
		local reduction = t.getReduction(self, t)*100
		return ([[When Spin Fate is triggered you reduce the triggering damage by %d%%.
		This effect scales with your Spellpower.]]):
		format(reduction)
	end,
}

newTalent{
	name = "Seal Fate",
	type = {"chronomancy/fate-weaving", 4},
	require = chrono_req4,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 20) end,
	cooldown = 24,
	tactical = { BUFF = 2 },
	getDuration = function(self, t) return getExtensionModifier(self, t, 5) end,
	getProcs = function(self, t) return math.floor(self:combatTalentScale(t, 1, 5)) end,
	no_energy = true,
	action = function(self, t)
		self:setEffect(self.EFF_SEAL_FATE, t.getDuration(self, t), {procs=t.getProcs(self, t)})
		return true
	end,
	info = function(self, t)
		local procs = t.getProcs(self, t)
		local duration = t.getDuration(self, t)
		return ([[Activate to Seal Fate for %d turns.  When you damage a target while Seal Fate is active you have a 50%% chance to increase the duration of one detrimental status effect on it by one turn.
		If you have Spin Fate active the chance will be increased by 33%% per Spin (to a maximum of 100%% at three Spin.)
		This can occur at most %d times per turn.  While Seal Fate is active you may gain one additional spin per turn.]]):format(duration, procs)
	end,
}