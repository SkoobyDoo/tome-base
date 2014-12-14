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

-- EDGE TODO: Particles, Timed Effect Particles

newTalent{
	name = "Celerity",
	type = {"chronomancy/speed-control", 1},
	require = chrono_req1,
	points = 5,
	mode = "passive",
	getSpeed = function(self, t) return self:combatTalentScale(t, 10, 30)/100 end,
	doCelerity = function(self, t, x, y)
		if self.x ~= x or self.y ~= x then
			local speed = t.getSpeed(self, t)
			self:setEffect(self.EFF_CELERITY, 1, {speed=speed, charges=1, max_charges=3})
		end
		return true
	end,
	info = function(self, t)
		local speed = t.getSpeed(self, t) * 100
		return ([[When you move you gain %d%% movement speed for one turn.  This effect stacks up to three times.
		]]):format(speed)
	end,
}

newTalent{
	name = "Time Dilation",
	type = {"chronomancy/speed-control",2},
	require = chrono_req2,
	points = 5,
	sustain_paradox = 36,
	mode = "sustained",
	no_sustain_autoreset = true,
	cooldown = 12,
	tactical = { ATTACKAREA = 1, DISABLE = 3 },
	range = 0,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 2.5, 4.5)) end,
	getSlow = function(self, t) return paradoxTalentScale(self, t, 20, 40, 60)/100 end,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), friendlyfire=false, radius = self:getTalentRadius(t), talent=t}
	end,
	iconOverlay = function(self, t, p)
		local val = p.charges or 0
		if val <= 0 then return "" end
		local fnt = "buff_font"
		return tostring(math.ceil(val)), fnt
	end,
	callbackOnActBase = function(self, t)
		local p = self:isTalentActive(t.id)
		-- If we moved lower the power
		if self.x ~= p.x or self.y ~= p.y then
			p.x = self.x; p.y=self.y; p.charges = math.max(0, p.charges - 1)
		-- Otherwise increase it
		else
			p.charges = math.min(p.charges + 1, 3)
		end
		
		-- Dilate Time
		if p.charges > 0 and not self.resting then
			self:project(self:getTalentTarget(t), self.x, self.y, function(px, py)
				local target = game.level.map(px, py, Map.ACTOR)
				if not target then return end
				target:setEffect(target.EFF_SLOW, 1, {power=p.power*p.charges, apply_power=getParadoxSpellpower(self, t), no_ct_effect=true})		
			end)
		end
	end,
	updateOnTeleport = function(self, t, x, y)
		local p = self:isTalentActive(self.T_TIME_DILATION)
		p.x, p.y = x, y
	end,
	activate = function(self, t)
		local ret ={
			x = self.x, y=self.y, power = t.getSlow(self, t)/3, charges = 0
		}
		game:playSoundNear(self, "talents/arcane")
		return ret
	end,
	deactivate = function(self, t, p)
	--	self:removeParticles(p.particle)
		return true	
	end,
	info = function(self, t)
		local slow = t.getSlow(self, t) * 100
		local radius = self:getTalentRadius(t)
		return ([[Time Dilates around you, reducing the speed of all enemies within a radius of %d by up to %d%%.  This effect builds gradually over three turns and loses %d%% power each time you move.
		Movement via teleport will not lower the power and the speed decrease will scale with your Spellpower.]]):
		format(radius, slow, slow/3)
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
	getPower= function(self, t) return paradoxTalentScale(self, t, 20, 40, 60)/300 end,
	getDuration = function(self, t) return getExtensionModifier(self, t, 4) end,
	no_energy = true,
	action = function(self, t)
		local celerity = self:hasEffect(self.EFF_CELERITY) and self:hasEffect(self.EFF_CELERITY).charges or 0
		local dilation = self:isTalentActive(self.T_TIME_DILATION) and self:isTalentActive(self.T_TIME_DILATION).charges or 0
		local move = t.getPower(self, t) * celerity
		local speed = t.getPower(self, t) * dilation
		
		self:setEffect(self.EFF_HASTE, t.getDuration(self, t), {move=move, speed=speed})
		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local power = t.getPower(self, t) * 100
		return ([[Increases your movement speed by %d%% per stack of Celerity and your attack, spell, and mind speed by %d%% per stack of Time Dilation for the next %d game turns.
		The speed increase will scale with your Spellpower.]]):format(power, power, duration)
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
		local time_dilated = false
		if self:isTalentActive(self.T_TIME_DILATION) then
			local p = self:isTalentActive(self.T_TIME_DILATION)
			if p.charges == 3 then
				time_dilated = true
			end
		end
		if not time_dilated then if not silent then game.logPlayer(self, "Time must be fully dilated in order to cast time stop.") end return false end return true 
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
		Time must be fully dilated in order to use this talent.
		The damage reduction penalty will be lessened by your Spellpower.]]):format(duration, reduction)
	end,
}
