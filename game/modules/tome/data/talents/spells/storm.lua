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
	name = "Nova",
	type = {"spell/storm",1},
	require = spells_req1,
	points = 5,
	mana = 12,
	cooldown = 8,
	tactical = {
		ATTACKAREA = 10,
		DEFEND = 4,
	},
	direct_hit = true,
	range = function(self, t) return math.floor(2 + self:getTalentLevel(t) * 0.7) end,
	action = function(self, t)
		local tg = {type="ball", range=0, radius=self:getTalentRange(t), friendlyfire=false, talent=t}
		local dam = self:spellCrit(self:combatTalentSpellDamage(t, 28, 170))
		self:project(tg, self.x, self.y, DamageType.LIGHTNING_DAZE, rng.avg(dam / 3, dam, 3))
		local x, y = self.x, self.y
		-- Lightning ball gets a special treatment to make it look neat
		local sradius = (tg.radius + 0.5) * (engine.Map.tile_w + engine.Map.tile_h) / 2
		local nb_forks = 16
		local angle_diff = 360 / nb_forks
		for i = 0, nb_forks - 1 do
			local a = math.rad(rng.range(0+i*angle_diff,angle_diff+i*angle_diff))
			local tx = x + math.floor(math.cos(a) * tg.radius)
			local ty = y + math.floor(math.sin(a) * tg.radius)
			game.level.map:particleEmitter(x, y, tg.radius, "lightning", {radius=tg.radius, grids=grids, tx=tx-x, ty=ty-y, nb_particles=25, life=8})
		end

		game:playSoundNear(self, "talents/lightning")
		return true
	end,
	info = function(self, t)
		local dam = damDesc(self, DamageType.LIGHTNING, self:combatTalentSpellDamage(t, 28, 170))
		return ([[A lightning emanates from you in a circual wave, doing %0.2f to %0.2f lightning damage and possibly dazing them.
		The damage will increase with the Magic stat]]):format(dam / 3, dam)
	end,
}

newTalent{
	name = "Shock",
	type = {"spell/storm",2},
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
		local tg = {type="bolt", range=self:getTalentRange(t), talent=t, display={particle="bolt_lightning", trail="lightningtrail"}}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local dam = self:combatTalentSpellDamage(t, 25, 200)
		self:projectile(tg, x, y, DamageType.LIGHTNING_DAZE, {daze=100, dam=self:spellCrit(rng.avg(dam / 3, dam, 3))}, {type="lightning_explosion"})
		game:playSoundNear(self, "talents/lightning")
		return true
	end,
	info = function(self, t)
		return ([[Conjures up a bolt of lightning, doing %0.2f lightning damage and dazing the target.
		The damage will increase with the Magic stat]]):format(damDesc(self, DamageType.LIGHTNING, self:combatTalentSpellDamage(t, 25, 200)))
	end,
}

newTalent{
	name = "Hurricane",
	type = {"spell/storm",3},
	require = spells_req3,
	points = 5,
	mode = "sustained",
	sustain_mana = 100,
	cooldown = 30,
	tactical = {
		ATTACKAREA = 10,
	},
	range = 20,
	direct_hit = true,
	do_hurricane = function(self, t, target)
		if not rng.percent(30 + self:getTalentLevel(t) * 5) then return end

		local rad = 2
		if self:getTalentLevel(t) >= 3 then rad = 3 end
		target:setEffect(target.EFF_HURRICANE, 10, {src=self, dam=self:combatTalentSpellDamage(t, 25, 150), radius=rad})
		game:playSoundNear(self, "talents/thunderstorm")
	end,
	activate = function(self, t)
		return {}
	end,
	deactivate = function(self, t, p)
		return true
	end,
	info = function(self, t)
		local dam = damDesc(self, DamageType.LIGHTNING, self:combatTalentSpellDamage(t, 25, 150))
		return ([[Each time one of your lightning spell dazes a target it has %d%% chances to creates a chain reaction that summons a mighty Hurricane around the target.
		Each turn all creatures around it will take %0.2f to %0.2f lightning damage.
		Only 2 hurricanes can exist at the same time.
		The damage will increase with the Magic stat]]):format(30 + self:getTalentLevel(t) * 5, dam / 3, dam)
	end,
}

newTalent{
	name = "Tempest",
	type = {"spell/storm",4},
	require = spells_req4,
	points = 5,
	mode = "sustained",
	sustain_mana = 80,
	cooldown = 30,
	activate = function(self, t)
		game:playSoundNear(self, "talents/thunderstorm")
		return {
			dam = self:addTemporaryValue("inc_damage", {[DamageType.LIGHTNING] = self:getTalentLevelRaw(t) * 2}),
			resist = self:addTemporaryValue("resists_pen", {[DamageType.LIGHTNING] = self:getTalentLevelRaw(t) * 10}),
			particle = self:addParticles(Particles.new("tempest", 1)),
		}
	end,
	deactivate = function(self, t, p)
		self:removeParticles(p.particle)
		self:removeTemporaryValue("inc_damage", p.dam)
		self:removeTemporaryValue("resists_pen", p.resist)
		return true
	end,
	info = function(self, t)
		return ([[Surround yourself with a Tempest, increasing all your lightning damage by %d%% and ignoring %d%% lightning resistance of your targets.]])
		:format(self:getTalentLevelRaw(t) * 2, self:getTalentLevelRaw(t) * 10)
	end,
}
