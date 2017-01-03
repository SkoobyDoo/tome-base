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

--[[ ideas:
	Heightened Senses: restore trap detection, remove unseen attackers damage reduction
	Device Mastery: remove trap detection, leave trap disarming
	Danger Sense: get damage from unseen attackers, reduce general damage reduction,
		gain? trap detection? blind-fighting like ability?

--]]

newTalent{
	name = "Heightened Senses",
	type = {"cunning/survival", 1},
	require = cuns_req1,
	mode = "passive",
	points = 5,
	sense = function(self, t) return math.floor(self:combatTalentScale(t, 5, 9)) end,
	seePower = function(self, t) return self:combatScale(self:getCun(15, true)*self:getTalentLevel(t), 5, 0, 80, 75) end,
	getResists = function(self, t) return self:combatTalentLimit(t, 40, 5, 25) end,
	passives = function(self, t, p)
		self:talentTemporaryValue(p, "heightened_senses", t.sense(self, t))
		self:talentTemporaryValue(p, "see_invisible", t.seePower(self, t))
		self:talentTemporaryValue(p, "see_stealth", t.seePower(self, t))
		if self:getTalentLevel(t) >= 3 then
			self:talentTemporaryValue(p, "resist_unseen", t.getResists(self, t))
		end
	end,
	info = function(self, t)
		return ([[You notice the small things others do not notice, allowing you to "see" creatures in a %d radius even outside of light radius.
		This is not telepathy, however, and it is still limited to line of sight.
		Also, your attention to detail increases stealth detection and invisibility detection by %d.
		At level 3, you are able to react quickly to stealthed and invisible enemies attacking you, reducing the damage they deal by %d%%.
		The detection power improves with your Cunning.]]):
		format(t.sense(self,t), t.seePower(self,t), t.getResists(self,t))
	end,
}

newTalent{
	name = "Device Mastery",
	type = {"cunning/survival", 2},
	require = cuns_req2,
	mode = "passive",
	points = 5,
	cdReduc = function(tl)
		if tl <=0 then return 0 end
		return math.floor(100*tl/(tl+7.5)) -- Limit < 100%
	end,
	passives = function(self, t, p)
		self:talentTemporaryValue(p, "use_object_cooldown_reduce", t.cdReduc(self:getTalentLevel(t)))
	end,
	autolearn_talent = "T_DISARM_TRAP",
	trapPower = function(self, t) return self:combatScale(self:getTalentLevel(t) * self:getCun(25, true), 0, 0, 125, 125) end,
	info = function(self, t)
		return ([[Your cunning manipulations allow you to use charms (wands, totems and torques) more efficiently, reducing their cooldowns and the power cost of all usable items by %d%%.
In addition, your knowledge of devices allows you to detect traps around you and disarm known traps (%d detection and disarm 'power').
The trap detection and disarming ability improves with your Cunning. ]]):
		format(t.cdReduc(self:getTalentLevel(t)), t.trapPower(self,t)) --I5
	end,
}

newTalent{
	name = "Track",
	type = {"cunning/survival", 2},
	require = cuns_req2,
	points = 5,
	random_ego = "utility",
	cooldown = 20,
	radius = function(self, t) return math.floor(self:combatScale(self:getCun(10, true) * self:getTalentLevel(t), 5, 0, 55, 50)) end,
	no_npc_use = true,
	action = function(self, t)
		local rad = self:getTalentRadius(t)
		self:setEffect(self.EFF_SENSE, 3 + self:getTalentLevel(t), {
			range = rad,
			actor = 1,
		})
		return true
	end,
	info = function(self, t)
		local rad = self:getTalentRadius(t)
		return ([[Sense foes around you in a radius of %d for %d turns.
		The radius will increase with your Cunning.]]):format(rad, 3 + self:getTalentLevel(t))
	end,
}

--- This presents some balance problems: Everyone can get this, and it defends against everything.
-- consider flat damage armour instead of %? (based on Cun/Dex)
newTalent{
	name = "Danger Sense",
	type = {"cunning/survival", 3},
	require = cuns_req4,
	points = 5,
	mode = "passive",
	cooldown = function(self, t) return math.ceil(self:combatStatLimit("wil", 10, 30, 20)) end, -- Limit > 10
	fixed_cooldown = true,
	getTrigger = function(self, t) -- return % of life, minimum life fraction
		return self:combatTalentLimit(t, 0.15, 0.5, 0.3), 0.25
	end,
--	no_npc_use = true,
	getReduction = function(self, t) -- depends on both Dex and Cun to prevent being too useful to Berserkers, Oozemancers,  Mages ...
		return self:combatLimit((self:getDex() + self:getCun()-20)*self:getTalentLevel(t), 75, 5, 26, 55, 1170) -- Limit < 75%, = 5% @ TL1.0 dex/cun = 10/36, ~= 41% @ TL6.5, dex/cun = 50/50, ~= 55% @ TL6.5, dex/cun = 100/100
	end,
	callbackOnHit = function(self, t, cb, src)
		if not self:isTalentCoolingDown(t) then
			--game.log("#GREY#%s: Checking Danger Sense: dam=%0.2f, life = %d, max_life=%d", self.name, cb.value, self.life, self.max_life)
			local dam_trigger, life_trigger = t.getTrigger(self, t)
			dam_trigger, life_trigger = dam_trigger*self.life, life_trigger*self.max_life
			if cb.value > dam_trigger or self.life - cb.value < life_trigger then
				--game.log("#GREY#%s: Danger Sense Triggered! dam=%0.2f, d_t=%0.2f, l_t=%0.2f", self.name, cb.value, dam_trigger, life_trigger)
				local reduce = t.getReduction(self, t)
				self:setEffect("EFF_DANGER_SENSE", 1, {reduce = reduce})
				local eff = self:hasEffect("EFF_DANGER_SENSE")
				eff.dur = eff.dur - 1
				cb.value = cb.value * (100-reduce) / 100
				self:startTalentCooldown(t)
				return cb.value
			end
		end
	end,
	info = function(self, t)
		local life_fct, life_min = t.getTrigger(self, t)
		return ([[You have an enhanced sense of self preservation, and use keen intuition and fast reflexes to react quickly when you feel your life is in peril.
		If damage would deal more than %d%% of your current life (ignoring any negative life limit), or would reduce your life below 25%% of maximum (%d), you avoid %d%% of that damage and any additional damage received later in the same turn.
		The damage avoidance improves with Cunning and Dexterity.
		This talent has a cooldown that decreases with your Willpower.]]):
		format(life_fct*100, life_min*self.max_life, t.getReduction(self,t) )
	end,
}

-- track to detect and device master to disarm?
newTalent{
	name = "Disarm Trap",
	type = {"base/class", 1},
	no_npc_use = true,
	innate = true,
	points = 1,
	range = 1,
	message = false,
	no_break_stealth = true,
	image = "talents/trap_priming.png",
	target = {type="hit", range=1, nowarning=true, immediate_keys=true, no_lock=false},
	action = function(self, t)
		if self.player then
--			core.mouse.set(game.level.map:getTileToScreen(self.x, self.y, true))
			game.log("#CADET_BLUE#Disarm A Trap: (direction keys to select where to disarm, shift+direction keys to move freely)")
		end
		local tg = self:getTalentTarget(t)
		local x, y, dir = self:getTarget(tg)
		if not (x and y) then return end
		
		dir = util.getDir(x, y, self.x, self.y)
		x, y = util.coordAddDir(self.x, self.y, dir)
		print("Requesting disarm trap", self.name, t.id, x, y)
		local tl = self:getTalentLevel(self.T_DEVICE_MASTERY)
		local trap = self:detectTrap(nil, x, y)
		if trap then
			print("Found trap", trap.name, x, y)
			if tl < 3 then
				game.logPlayer(self, "#CADET_BLUE#You need more skill to disarm traps.")
			elseif (x == self.x and y == self.y) or self:canMove(x, y) then
				local px, py = self.x, self.y
				self:move(x, y, true) -- temporarily move to make sure trap can trigger properly
				trap:trigger(self.x, self.y, self) -- then attempt to disarm the trap, which may trigger it
				self:move(px, py, true)
			else
				game.logPlayer(self, "#CADET_BLUE#You cannot disarm traps in grids you cannot enter.")
			end
		else
			game.logPlayer(self, "#CADET_BLUE#You don't see a trap there.")
		end
		
		return true
	end,
	info = function(self, t)
		local ths = self:getTalentFromId(self.T_DEVICE_MASTERY)
		local power = ths.trapPower(self,ths)
		return ([[You search an adjacent grid for a hidden trap (%d detection 'power') and disarm it (%d disarm 'power') if possible.
		To disarm, you must have at least 3 talent levels in %s and be able to enter the trap's grid to manipulate it, though you stay in your current location.  A failed attempt to disarm a trap may trigger it.
		Your skill improves with your your Cunning.]]):format(power, power + (self:attr("disarm_bonus") or 0), ths.name)
	end,
}