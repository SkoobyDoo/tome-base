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

newTalent{
	name = "Heightened Senses",
	type = {"cunning/survival", 1},
	require = cuns_req1,
	mode = "passive",
	points = 5,
	sense = function(self, t) return math.floor(self:combatTalentScale(t, 5, 9)) end,
	trapPower = function(self, t) return self:combatScale(self:getTalentLevel(t) * self:getCun(25, true), 0, 0, 90, 125) end, -- ~90 at TL5, 100 cunning
	passives = function(self, t, p)
		self:talentTemporaryValue(p, "heightened_senses", t.sense(self, t))
	end,
	on_learn = function(self, t)
		if self:getTalentLevel(t) >= 3 and not self:knowTalent(self.T_DISARM_TRAP) then
			self:learnTalent(self.T_DISARM_TRAP, true, 1)
		end
	end,
	on_unlearn = function(self, t)
		if self:getTalentLevel(t) < 3 and self:knowTalent(self.T_DISARM_TRAP) then
			self:unlearnTalent(self.T_DISARM_TRAP, 1)
		end
	end,
	info = function(self, t)
		return ([[You notice the small things others do not notice, allowing you to "see" creatures in a %d radius even outside of light radius.
		This is not telepathy, however, and it is still limited to line of sight.
		Also, your attention to detail allows you to detect traps around you (%d detection 'power').
		At level 3, you learn to disarm known traps (%d disarm 'power').
		The trap detection and disarming ability improves with your Cunning.]]):
		format(t.sense(self,t),t.trapPower(self,t),t.trapPower(self,t))
	end,
}

newTalent{
	name = "Disarm Trap",
	type = {"base/class", 1},
	no_npc_use = true,
	innate = true,
	points = 1,
	range = 1,
	message = false,
	image = "talents/trap_priming.png",
	target = {type="hit", range=1, nowarning=true, immediate_keys=true, no_lock=false},
	action = function(self, t)
		if self.player then
			core.mouse.set(game.level.map:getTileToScreen(self.x, self.y, true))
			game.log("#CADET_BLUE#Disarm A Trap: (direction keys to select where to disarm, shift+direction keys to move freely)")
		end
		local tg = self:getTalentTarget(t)
		local x, y, dir = self:getTarget(tg)
		if not (x and y) then return end
		
		dir = util.getDir(x, y, self.x, self.y)
		x, y = util.coordAddDir(self.x, self.y, dir)
		print("Requesting disarm trap", self.name, t.id, x, y)
		local trap = self:detectTrap(nil, x, y)
		if trap then
			print("Found trap", trap.name, x, y)
			if (x == self.x and y == self.y) or self:canMove(x, y) then
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
		local ths = self:getTalentFromId(self.T_HEIGHTENED_SENSES)
		local power = ths.trapPower(self,ths)
		return ([[You search an adjacent grid for a hidden trap (%d detection 'power') and attempt to disarm it (%d disarm 'power').
		To disarm a trap, you must be able to enter its grid to manipulate it, even though you stay in your current location.
		Success depends on your skill in the %s talent and your Cunning, and failing to disarm a trap may trigger it.]]):format(power, power + (self:attr("disarm_bonus") or 0), ths.name)
	end,
}

newTalent{
	name = "Charm Mastery",
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
--	on_unlearn = function(self, t)
--	end,
	info = function(self, t)
		return ([[Your cunning manipulations allow you to use charms (wands, totems and torques) more efficiently, reducing their cooldowns by %d%%.]]):
		format(t.cdReduc(self:getTalentLevel(t)))
	end,
}

newTalent{
	name = "Piercing Sight",
	type = {"cunning/survival", 3},
	require = cuns_req3,
	mode = "passive",
	points = 5,
	--  called by functions _M:combatSeeStealth and _M:combatSeeInvisible functions mod\class\interface\Combat.lua
	seePower = function(self, t) return self:combatScale(self:getCun(15, true)*self:getTalentLevel(t), 5, 0, 80, 75) end, --I5
	info = function(self, t)
		return ([[You look at your surroundings with more intensity than most people, allowing you to see stealthed or invisible creatures.
		Increases stealth detection by %d and invisibility detection by %d.
		The detection power increases with your Cunning.]]):
		format(t.seePower(self,t), t.seePower(self,t))
	end,
}

newTalent{
	name = "Evasion",
	type = {"cunning/survival", 4},
	points = 5,
	require = cuns_req4,
	random_ego = "defensive",
	tactical = { ESCAPE = 2, DEFEND = 2 },
	cooldown = 30,
	getDur = function(self) return math.floor(self:combatStatLimit("wil", 30, 6, 15)) end, -- Limit < 30
	getChanceDef = function(self, t)
		if self.perfect_evasion then return 100, 0 end
		return self:combatLimit(5*self:getTalentLevel(t) + self:getCun(25,true) + self:getDex(25,true), 50, 10, 10, 37.5, 75),
		self:combatScale(self:getTalentLevel(t) * (self:getCun(25, true) + self:getDex(25, true)), 0, 0, 55, 250, 0.75)
		-- Limit evasion chance < 50%, defense bonus ~= 55 at level 50
	end,
	speed = "combat",
	action = function(self, t)
		local dur = t.getDur(self)
		local chance, def = t.getChanceDef(self,t)
		self:setEffect(self.EFF_EVASION, dur, {chance=chance, defense = def})
		return true
	end,
	info = function(self, t)
		local chance, def = t.getChanceDef(self,t)
		return ([[Your quick wit allows you to see attacks before they land, granting you a %d%% chance to completely evade them and granting you %d defense for %d turns.
		Duration increases with Willpower, and chance to evade and defense with Cunning and Dexterity.]]):
		format(chance, def,t.getDur(self))
	end,
}
