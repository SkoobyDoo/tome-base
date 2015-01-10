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
	name = "Celerity",
	type = {"chronomancy/speed-control", 1},
	require = chrono_req1,
	points = 5,
	mode = "passive",
	getSpeed = function(self, t) return self:combatTalentScale(t, 10, 30)/100 end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 2, 4))) end,
	callbackOnTalentPost = function(self, t,  ab)
		if ab.type[1]:find("^chronomancy/") then
			if self.turn_procs.celerity then return end -- temp fix to prevent over stacking
			local speed = t.getSpeed(self, t)
			self:setEffect(self.EFF_CELERITY, t.getDuration(self, t), {speed=speed, charges=1, max_charges=3})
			self.turn_procs.celerity = true
		end
	end,
	info = function(self, t)
		local speed = t.getSpeed(self, t) * 100
		local duration = t.getDuration(self, t)
		return ([[When you use a chronomancy spell you gain %d%% movement speed for %d turn.  This effect stacks up to three times but can only occur once per turn.
		]]):format(speed, duration)
	end,
}

newTalent{
	name = "Time Dilation",
	type = {"chronomancy/speed-control",2},
	require = chrono_req2,
	points = 5,
	mode = "passive",
	getSpeed = function(self, t) return self:combatTalentScale(t, 10, 30)/200 end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 2, 4))) end,
	callbackOnMove = function(self, t, moved, force, ox, oy)
		if not force and moved and ox and oy and (ox ~= self.x or oy ~= self.y) then
			if self.turn_procs.time_dilation then return end -- temp fix to prevent over stacking
			local speed = t.getSpeed(self, t)
			self:setEffect(self.EFF_TIME_DILATION, t.getDuration(self, t), {speed=speed, charges=1, max_charges=3})
			self.turn_procs.time_dilation = true
		end
	end,
	info = function(self, t)
		local speed = t.getSpeed(self, t) * 100
		local duration = t.getDuration(self, t)
		return ([[When you move you gain %d%% attack, spell, and mind speed for %d turns.  This effect stacks up to three times but can only occur once per turn.
		]]):format(speed, duration)
	end,
}

newTalent{
	name = "Haste",
	type = {"chronomancy/speed-control", 3},
	require = chrono_req3,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 20) end,
	cooldown = 24,
	tactical = { BUFF = 2, CLOSEIN = 2, ESCAPE = 2 },
	getSpeed = function(self, t) return self:combatTalentScale(t, 10, 30)/200 end,
	getDuration = function(self, t) return getExtensionModifier(self, t, 4) end,
	no_energy = true,
	action = function(self, t)
		local celerity = self:hasEffect(self.EFF_CELERITY) and self:hasEffect(self.EFF_CELERITY).charges or 0
		local dilation = self:hasEffect(self.EFF_TIME_DILATION) and self:hasEffect(self.EFF_TIME_DILATION).charges or 0
		local stacks = dilation + celerity
		
		self:setEffect(self.EFF_HASTE, t.getDuration(self, t), {power=stacks*t.getSpeed(self, t)})
		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local speed = t.getSpeed(self, t) * 100
		return ([[Increases your global speed by %d%% per stack of Celerity and Time Dilation.  The effect lasts %d game turns.]]):format(speed, duration)
	end,
}

newTalent{
	name = "Time Stop",
	type = {"chronomancy/speed-control", 4},
	require = chrono_req4,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 24) end,
	cooldown = function(self, t) return math.ceil(self:combatTalentLimit(t, 10, 45, 25)) end, -- Limit >10
	tactical = { BUFF = 2, CLOSEIN = 2, ESCAPE = 2 },
	no_energy = true,
	on_pre_use = function(self, t, silent)
		local can_stop = false
		if self:hasEffect(self.EFF_TIME_DILATION) and self:hasEffect(self.EFF_TIME_DILATION).charges == 3 then 
			can_stop = true
		elseif self:hasEffect(self.EFF_CELERITY) and self:hasEffect(self.EFF_CELERITY).charges == 3 then 
			can_stop = true
		end
		if not can_stop then if not silent then game.logPlayer(self, "Celerity or Time Dilation must be at full power in order to cast Time Stop.") end return false end return true 
	end,
	getReduction = function(self, t) return 80 - paradoxTalentScale(self, t, 0, 20, 40) end,
	getDuration = function(self, t) return getExtensionModifier(self, t, 2) end,
	action = function(self, t)
		self.energy.value = self.energy.value + (t.getDuration(self, t) * 1000)
		self:setEffect(self.EFF_TIME_STOP, 1, {power=t.getReduction(self, t)})
		game.logSeen(self, "#STEEL_BLUE#%s has stopped time!#LAST#", self.name:capitalize())
		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local reduction = t.getReduction(self, t)
		return ([[Gain %d turns.  During this time your damage will be reduced by %d%%.
		Time Dilation or Celerity must be fully stacked in order to use this talent.
		The damage reduction penalty will be lessened by your Spellpower.]]):format(duration, reduction)
	end,
}
