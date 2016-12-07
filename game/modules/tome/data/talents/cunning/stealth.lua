-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2016 Nicolas Casalini
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

-- Compute the total detection ability of enemies to see through stealth
-- Each foe loses 10% detection power per tile beyond range 1
-- returns detect, closest = total detection power, distance to closest enemy
-- if estimate is true, only counts the detection power of seen actors
local function stealthDetection(self, radius, estimate)
	if not self.x then return nil end
	local dist = 0
	local closest, detect = math.huge, 0
	for i, act in ipairs(self.fov.actors_dist) do
		dist = core.fov.distance(self.x, self.y, act.x, act.y)
		if dist > radius then break end
		if act ~= self and act:reactionToward(self) < 0 and not act:attr("blind") and (not act.fov or not act.fov.actors or act.fov.actors[self]) and (not estimate or self:canSee(act)) then
			detect = detect + act:combatSeeStealth() * (1.1 - dist/10) -- detection strength reduced 10% per tile
			if dist < closest then closest = dist end
		end
	end
	return detect, closest
end
Talents.stealthDetection = stealthDetection

newTalent{
	name = "Stealth",
	type = {"cunning/stealth", 1},
	require = cuns_req1,
	mode = "sustained", no_sustain_autoreset = true,
	points = 5,
	cooldown = 10,
	allow_autocast = true,
	no_energy = true,
	tactical = { BUFF = 3 },
	no_break_stealth = true,
	getStealthPower = function(self, t) return math.max(0, self:combatScale(self:getCun(10, true) * self:getTalentLevel(t), 15, 1, 64, 50)) end, --TL 5, cun 100 = 64
	getRadius = function(self, t) return math.ceil(self:combatTalentLimit(t, 0, 8.9, 4.6)) end, -- Limit to range >= 1
	on_pre_use = function(self, t, silent, fake)
		local armor = self:getInven("BODY") and self:getInven("BODY")[1]
		if armor and (armor.subtype == "heavy" or armor.subtype == "massive") then
			if not silent then game.logPlayer(self, "You cannot be stealthy with such heavy armour on!") end
			return nil
		end
		if self:isTalentActive(t.id) then return true end
		
		-- Check nearby actors detection ability
		if not self.x or not self.y or not game.level then return end
		if self:knowTalent(self.T_SOOTHING_DARKNESS) and not game.level.map.lites(self.x, self.y) then return true end
		if not rng.percent(self.hide_chance or 0) then
			if stealthDetection(self, t.getRadius(self, t)) > 0 then
				if not silent then game.logPlayer(self, "You are being observed too closely to enter Stealth!") end
				return nil
			end
		end
		return true
	end,
	sustain_lists = "break_with_stealth",
	activate = function(self, t)
		if self:knowTalent(self.T_SOOTHING_DARKNESS) then
			local life = self:callTalent(self.T_SOOTHING_DARKNESS, "getLife")
			local sta = self:callTalent(self.T_SOOTHING_DARKNESS, "getStamina")
			local dr = self:callTalent(self.T_SOOTHING_DARKNESS, "getReduction")
			local dur = self:callTalent(self.T_SOOTHING_DARKNESS, "getDuration")
			
			self:setEffect(self.EFF_SOOTHING_DARKNESS, dur, {life=life, stamina=sta, dr=dr})
		end
		
		if self:knowTalent(self.T_SHADOWSTRIKE) then
			local power = self:callTalent(self.T_SHADOWSTRIKE, "getMultiplier")
			local dur = self:callTalent(self.T_SHADOWSTRIKE, "getDuration")
			
			self:setEffect(self.EFF_SHADOWSTRIKE, dur, {power=power})
		end
		
		local res = {
			stealth = self:addTemporaryValue("stealth", t.getStealthPower(self, t)),
			lite = self:addTemporaryValue("lite", -1000),
			infra = self:addTemporaryValue("infravision", 1),
		}
		self:resetCanSeeCacheOf()
		if self.updateMainShader then self:updateMainShader() end
		return res
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("stealth", p.stealth)
		self:removeTemporaryValue("infravision", p.infra)
		self:removeTemporaryValue("lite", p.lite)
		if self:knowTalent(self.T_TERRORIZE) then
			local t = self:getTalentFromId(self.T_TERRORIZE)
			t.terrorize(self,t)
		end
		if self:hasEffect(self.EFF_SHADOW_DANCE) then
			self:removeEffect(self.EFF_SHADOW_DANCE)
		end
		self:resetCanSeeCacheOf()
		if self.updateMainShader then self:updateMainShader() end
		return true
	end,
	callbackOnActBase = function(self, t)
		if self:knowTalent(self.T_SOOTHING_DARKNESS) then
			local life = self:callTalent(self.T_SOOTHING_DARKNESS, "getLife")
			local sta = self:callTalent(self.T_SOOTHING_DARKNESS, "getStamina")
			local dr = self:callTalent(self.T_SOOTHING_DARKNESS, "getReduction")
			local dur = self:callTalent(self.T_SOOTHING_DARKNESS, "getDuration")
			
			self:setEffect(self.EFF_SOOTHING_DARKNESS, dur, {life=life, stamina=sta, dr=dr})
		end
		
		if self:knowTalent(self.T_SHADOWSTRIKE) then
			local power = self:callTalent(self.T_SHADOWSTRIKE, "getMultiplier")
			local dur = self:callTalent(self.T_SHADOWSTRIKE, "getDuration")
			
			self:setEffect(self.EFF_SHADOWSTRIKE, dur, {power=power})
		end

	end,
	info = function(self, t)
		local stealthpower = t.getStealthPower(self, t) + (self:attr("inc_stealth") or 0)
		local radius = t.getRadius(self, t)
		return ([[Enters stealth mode (power %d, based on Cunning), making you harder to detect.
		If successful (re-checked each turn), enemies will not know exactly where you are, or may not notice you at all.
		Stealth reduces your light radius to 0, and will not work with heavy or massive armours.
		You cannot enter stealth if there are foes in sight within range %d.
		Any non-instant, non-movement actions will break stealth if not otherwise specified.]]):
		format(stealthpower, radius)
	end,
}

newTalent{
	name = "Shadowstrike",
	type = {"cunning/stealth", 2},
	require = cuns_req2,
	mode = "passive",
	points = 5,
	getMultiplier = function(self, t) return self:combatTalentScale(t, 10, 35) end,
	getDuration = function(self,t) if self:getTalentLevel(t) >= 3 then return 3 else return 2 end end,
	info = function(self, t)
	local multiplier = t.getMultiplier(self, t)
	return ([[When striking from stealth, the attack is automatically critical if the target does not notice you just before you land it. Spell and mind crits always critically strike, regardless of whether the target can see you.
In addition, the surprise caused by your assault increases your critical multiplier by %d%%. This effect persists for 3 turns after exiting stealth, or 4 turns at talent level 3 and above.]]):
		format(multiplier)
	end,
}

newTalent{
	name = "Soothing Darkness",
	type = {"cunning/stealth", 3},
	require = cuns_req3,
	points = 5,
	mode = "passive",
	getLife = function(self, t) return self:combatTalentScale(t, 1, 3) end,
	getStamina = function(self, t) return self:combatTalentScale(t, 0.5, 2) end,
	getReduction = function(self, t) return self:combatTalentStatDamage(t, "cun", 5, 25) end,
	getDuration = function(self,t) if self:getTalentLevel(t) >= 3 then return 3 else return 2 end end,
	info = function(self, t)
		return ([[You have a special affinity for darkness.
		When standing in an unlit grid, enemies observing you will not prevent you from entering stealth.
		While stealted, and for %d turns thereafter, all damage against you is reduced by %d, your life regeneration is increased by %0.1f, and your stamina regeneration is increased %0.1f]]):
		format(t.getDuration(self, t), t.getReduction(self,t), t.getLife(self,t), t.getStamina(self,t))
	end,
}

newTalent{
	name = "Shadow Dance",
	type = {"cunning/stealth", 4},
	require = cuns_req4,
	no_energy = true,
	no_break_stealth = true,
	points = 5,
	stamina = 30,
	cooldown = function(self, t) return self:combatTalentLimit(t, 10, 30, 15) end,
	tactical = { DEFEND = 2, ESCAPE = 2 },
	on_pre_use = function(self, t, silent)
		if self:isTalentActive(self.T_STEALTH) then 
			if not silent then game.logPlayer(self, "You must be out of stealth to enter Shadow Dance.") end
			return false
		end
		return true
	end,
	getRadius = function(self, t) return math.ceil(self:combatTalentLimit(t, 0, 8.9, 4.6)) end, -- Limit to range >= 1
	getDuration = function(self, t) return 1 + math.min(self:combatTalentScale(t, 1, 3),3) end,
	action = function(self, t)
		if self:isTalentActive(self.T_STEALTH) then return end
		
		self:forceUseTalent(self.T_STEALTH, {ignore_energy=true, ignore_cd=true, no_talent_fail=true, silent=true})
		for act, param in pairs(self.fov.actors) do
			if act ~= self and act.ai_target and act.ai_target.actor == self then act:setTarget() end
		end
		
		self:setEffect(self.EFF_SHADOW_DANCE, t.getDuration(self,t), {src=self, rad=t.getRadius(self,t)}) 
		
		return true
	end,
	info = function(self, t)
		return ([[Your mastery of stealth allows you to vanish from sight, returning to stealth and causing stealth to no longer break from unstealthy actions for %d turns.
		When triggered, all enemies with a direct line of sight to you completely lose track of you.
		When this effect ends, you must make a stealth check against targets in radius %d or be revealed.
You must be unstealthed to use this talent.]]):
		format(t.getDuration(self, t), t.getRadius(self,t))
	end,
}