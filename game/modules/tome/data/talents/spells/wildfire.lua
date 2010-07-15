-- ToME - Tales of Middle-Earth
-- Copyright (C) 2009, 2010 Nicolas Casalini
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
	name = "Blastwave",
	type = {"spell/wildfire",1},
	require = spells_req1,
	points = 5,
	mana = 12,
	cooldown = 3,
	tactical = {
		ATTACKAREA = 10,
		DEFEND = 4,
	},
	range = function(self, t) return 1 + self:getTalentLevelRaw(t) end,
	action = function(self, t)
		local tg = {type="ball", range=0, radius=self:getTalentRange(t), friendlyfire=false, talent=t}
		local grids = self:project(tg, self.x, self.y, DamageType.FIREKNOCKBACK, {dist=3, dam=self:spellCrit(self:combatTalentSpellDamage(t, 28, 150))})
		game.level.map:particleEmitter(self.x, self.y, tg.radius, "ball_fire", {radius=tg.radius, grids=grids, tx=self.x, ty=self.y})
		game:playSoundNear(self, "talents/fire")
		return true
	end,
	info = function(self, t)
		return ([[A wave of fire emanates from you, knocking back anything caught inside and setting them ablaze and doing %0.2f fire damage over 3 turns.
		The damage will increase with the Magic stat]]):format(self:combatTalentSpellDamage(t, 25, 250))
	end,
}

newTalent{
	name = "Dancing Fires",
	type = {"spell/wildfire",2},
	require = spells_req2,
	points = 5,
	mana = 12,
	cooldown = 3,
	tactical = {
		ATTACK = 10,
	},
	range = 20,
	reflectable = true,
	action = function(self, t)
		game:playSoundNear(self, "talents/fire")
		return true
	end,
	info = function(self, t)
		return ([[Conjures up a bolt of fire, setting the target ablaze and doing %0.2f fire damage over 3 turns.
		The damage will increase with the Magic stat]]):format(self:combatTalentSpellDamage(t, 25, 290))
	end,
}

newTalent{
	name = "Combust",
	type = {"spell/wildfire",3},
	require = spells_req3,
	points = 5,
	mana = 12,
	cooldown = 3,
	tactical = {
		ATTACK = 10,
	},
	range = 20,
	reflectable = true,
	action = function(self, t)
		game:playSoundNear(self, "talents/fire")
		return true
	end,
	info = function(self, t)
		return ([[Conjures up a bolt of fire, setting the target ablaze and doing %0.2f fire damage over 3 turns.
		The damage will increase with the Magic stat]]):format(self:combatTalentSpellDamage(t, 25, 290))
	end,
}

newTalent{
	name = "Wildfire",
	type = {"spell/wildfire",4},
	require = spells_req4,
	points = 5,
	mana = 12,
	cooldown = 3,
	tactical = {
		ATTACK = 10,
	},
	range = 20,
	reflectable = true,
	action = function(self, t)
		game:playSoundNear(self, "talents/fire")
		return true
	end,
	info = function(self, t)
		return ([[Conjures up a bolt of fire, setting the target ablaze and doing %0.2f fire damage over 3 turns.
		The damage will increase with the Magic stat]]):format(self:combatTalentSpellDamage(t, 25, 290))
	end,
}
