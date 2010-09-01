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
	name = "Bone Spear",
	type = {"corruption/bone", 1},
	require = corrs_req1,
	points = 5,
	vim = 13,
	cooldown = 4,
	range = 20,
	action = function(self, t)
		local tg = {type="beam", range=self:getTalentRange(t), talent=t}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		self:project(tg, x, y, DamageType.PHYSICAL, self:spellCrit(self:combatTalentSpellDamage(t, 20, 200)), {type="bones"})
		local _ _, x, y = self:canProject(tg, x, y)
		game:playSoundNear(self, "talents/arcane")
		return true
	end,
	info = function(self, t)
		return ([[Conjures up spear of bones doing %0.2f physical damage to all targets in line.
		The damage will increase with the Magic stat]]):format(self:combatTalentSpellDamage(t, 20, 200))
	end,
}

newTalent{
	name = "Bone Grab",
	type = {"corruption/bone", 2},
	require = corrs_req2,
	points = 5,
	vim = 28,
	cooldown = 15,
	range = 15,
	action = function(self, t)
		local tg = {type="bolt", range=self:getTalentRange(t)}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end

		local dam = self:combatTalentSpellDamage(t, 5, 140)

		self:project(tg, x, y, function(px, py)
			local target = game.level.map(px, py, engine.Map.ACTOR)
			if not target then return end

			local nx, ny = util.findFreeGrid(self.x, self.y, 5, true, {[Map.ACTOR]=true})
			if not nx then return end
			target:move(nx, ny, true)

			DamageType:get(DamageType.PHYSICAL).projector(self, nx, ny, DamageType.PHYSICAL, dam)
			if target:checkHit(self:combatSpellpower(), target:combatPhysicalResist(), 0, 95, 10) and target:canBe("pin") then
				target:setEffect(target.EFF_PINNED, math.floor(3 + self:getTalentLevel(t)), {})
			else
				game.logSeen(target, "%s resists the bone!", target.name:capitalize())
			end
		end)
		game:playSoundNear(self, "talents/arcane")

		return true
	end,
	info = function(self, t)
		return ([[Grab a target and teleport it to your side, pinning it there with a bone raising from the ground for %d turns.
		The bone will also deal %0.2f physical damage.
		The damage will increase with your Magic stat.]]):
		format(math.floor(3 + self:getTalentLevel(t)), self:combatTalentSpellDamage(t, 5, 140))
	end,
}

newTalent{
	name = "Bone Nova",
	type = {"corruption/bone", 3},
	require = corrs_req3,
	points = 5,
	vim = 25,
	cooldown = 12,
	range = function(self, t) return self:getTalentLevelRaw(t) end,
	action = function(self, t)
		local tg = {type="ball", radius=self:getTalentRange(t), friendlyfire=false}
		self:project(tg, self.x, self.y, DamageType.PHYSICAL, self:combatTalentSpellDamage(t, 8, 180), {type="bones"})
		game:playSoundNear(self, "talents/arcane")
		return true
	end,
	info = function(self, t)
		return ([[Fire bone spears in all directions, hitting all your foes for %0.2f physical damage.
		The damage will increase with your Magic stat.]]):format(self:combatTalentSpellDamage(t, 8, 180))
	end,
}

newTalent{
	name = "Bone Shield",
	type = {"corruption/bone", 4},
	points = 5,
	mode = "sustained", no_sustain_autoreset = true,
	require = corrs_req4,
	cooldown = 60,
	sustain_vim = 150,
	tactical = {
		DEFEND = 10,
	},
	absorb = function(self, t, p)
		game.logPlayer(self, "Your bone shield absorbs the damage!")
		self:removeParticles(table.remove(p.particles))
		if #p.particles <= 0 then
			local old = self.energy.value
			self.energy.value = 100000
			self:useTalent(t.id)
			self.energy.value = old
		end
	end,
	activate = function(self, t)
		local nb = math.floor(self:getTalentLevel(t))

		local ps = {}
		for i = 1, nb do ps[#ps+1] = self:addParticles(Particles.new("bone_shield", 1)) end

		game:playSoundNear(self, "talents/spell_generic2")
		return {
			particles = ps,
		}
	end,
	deactivate = function(self, t, p)
		for i, particle in ipairs(p.particles) do self:removeParticles(particle) end
		return true
	end,
	info = function(self, t)
		return ([[Bone shields start circling around you, they will each absorb fully one attack.
		%d shield(s) will be generated.]]):
		format(math.floor(self:getTalentLevel(t)))
	end,
}
