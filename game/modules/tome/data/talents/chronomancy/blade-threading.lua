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

local function bow_warden(self, target)
	if self:knowTalent(self.T_FRAYED_THREADS) and not self.turn_procs.bow_warden then
		self.turn_procs.bow_warden = true

		local m = makeParadoxClone(self, self, 2)
		m.energy.value = 1000
		m:attr("archery_pass_friendly", 1)
		doWardenWeaponSwap(m, "bow")
		m.on_act = function(self)
			if not self.frayed_target.dead then
				local targets = self:archeryAcquireTargets(nil, {one_shot=true, x=self.frayed_target.x, y=self.frayed_target.y, no_energy = true})
				if targets then
					self:archeryShoot(targets, self:getTalentFromId(self.T_SHOOT), {type="bolt"}, {mult=self:callTalent(self.T_FRAYED_THREADS, "getDamage")})
				end
				self:useEnergy()
			end
			game:onTickEnd(function()self:die()end)
			game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
		end
		
		-- Search for targets
		local tgts = {}
		local grids = core.fov.circle_grids(target.x, target.y, 10, true)
		for x, yy in pairs(grids) do for y, _ in pairs(grids[x]) do
			local target_type = Map.ACTOR
			local a = game.level.map(x, y, Map.ACTOR)
			if a and self:reactionToward(a) < 0 and self:hasLOS(a.x, a.y) then
				tgts[#tgts+1] = a
			end
		end end
		
		-- Choose a random target
		if #tgts > 0 then
			local a, id = rng.tableRemove(tgts)
			
			local poss = {}
			local range = archery_range(m)
			local x, y = a.x, a.y
			for i = x - range, x + range do
				for j = y - range, y + range do
					if game.level.map:isBound(i, j) and
						core.fov.distance(x, y, i, j) <= range and -- make sure they're within arrow range
						core.fov.distance(i, j, self.x, self.y) <= range/2 and -- try to place them close to the caster so enemies dodge less
						self:canMove(i, j) and target:hasLOS(i, j) then
						poss[#poss+1] = {i,j}
					end
				end
			end
				
			if #poss == 0 then return end
			local pos = poss[rng.range(1, #poss)]
			x, y = pos[1], pos[2]
			game.zone:addEntity(game.level, m, "actor", x, y)
			m.frayed_target = a
		end
	end
end

newTalent{
	name = "Warp Blade",
	type = {"chronomancy/blade-threading", 1},
	require = chrono_req1,
	points = 5,
	cooldown = 6,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	tactical = { ATTACK = {weapon = 2}, DISABLE = 3 },
	requires_target = true,
	speed = "weapon",
	range = 1,
	is_melee = true,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t), talent=t} end,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 1, 1.5) end,
	getWarp = function(self, t) return 7 + self:combatSpellpower(0.092) * self:combatTalentScale(t, 1, 7) end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 3, 7))) end,
	on_pre_use = function(self, t, silent) if not doWardenPreUse(self, "dual") then if not silent then game.logPlayer(self, "You require two weapons to use this talent.") end return false end return true end,
	action = function(self, t)
		local swap = doWardenWeaponSwap(self, "blade")

		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then
			if swap then doWardenWeaponSwap(self, "bow") end
			return nil
		end

		-- Hit?
		local hitted = self:attackTarget(target, nil, t.getDamage(self, t), true)

		-- Project our warp
		if hitted then
			bow_warden(self, target)
			self:project({type="hit"}, target.x, target.y, DamageType.WARP, self:spellCrit(t.getWarp(self, t)))
			game.level.map:particleEmitter(target.x, target.y, 1, "generic_discharge", {rm=64, rM=64, gm=134, gM=134, bm=170, bM=170, am=35, aM=90})
		end

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t) * 100
		local duration = t.getDuration(self, t)
		local warp = t.getWarp(self, t)
		return ([[Attack the target with your melee weapons for %d%%.
		If the attack hits you'll warp the target, dealing %0.2f temporal and %0.2f physical damage, and may stun, blind, pin, or confuse them for %d turns.
		The bonus damage improves with your Spellpower.]])
		:format(damage, damDesc(self, DamageType.TEMPORAL, warp/2), damDesc(self, DamageType.PHYSICAL, warp/2), duration)
	end
}

newTalent{
	name = "Weapon Folding", short_name = "WEAPON_FOLDING_BAD",
	type = {"chronomancy/blade-threading", 2},
	mode = "sustained",
	require = chrono_req2,
	sustain_paradox = 12,
	cooldown = 10,
	tactical = { BUFF = 2 },
	points = 5,
	getDamage = function(self, t) return 7 + self:combatSpellpower(0.092) * self:combatTalentScale(t, 1, 7) end,
	activate = function(self, t)
		return {}
	end,
	deactivate = function(self, t, p)
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		return ([[Folds a single dimension of your weapons (or ammo) upon itself, adding %0.2f temporal damage to your strikes and  increasing your armour penetration by %d.
		The armour penetration and damage will increase with your Spellpower.]]):format(damDesc(self, DamageType.TEMPORAL, damage), damage/2)
	end,
}

newTalent{
	name = "Braided Blade",
	type = {"chronomancy/blade-threading", 3},
	require = chrono_req3,
	points = 5,
	cooldown = 8,
	paradox = function (self, t) return getParadoxCost(self, t, 15) end,
	tactical = { ATTACKAREA = {weapon = 2}, DISABLE = 3 },
	requires_target = true,
	speed = "weapon",
	range = 1,
	is_melee = true,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t), talent=t} end,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 1, 1.5) end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 3, 7))) end,
	getPower = function(self, t) return self:combatTalentSpellDamage(t, 50, 150, getParadoxSpellpower(self, t)) end,
	on_pre_use = function(self, t, silent) if not doWardenPreUse(self, "dual") then if not silent then game.logPlayer(self, "You require two weapons to use this talent.") end return false end return true end,
	action = function(self, t)
		local swap = doWardenWeaponSwap(self, "blade")

		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then
			if swap then doWardenWeaponSwap(self, "bow") end
			return nil
		end

		local braid_targets = {}

		-- get left and right side
		local dir = util.getDir(x, y, self.x, self.y)
		local lx, ly = util.coordAddDir(self.x, self.y, util.dirSides(dir, self.x, self.y).left)
		local rx, ry = util.coordAddDir(self.x, self.y, util.dirSides(dir, self.x, self.y).right)
		local lt, rt = game.level.map(lx, ly, Map.ACTOR), game.level.map(rx, ry, Map.ACTOR)

		-- target hit
		local hit1 = self:attackTarget(target, nil, t.getDamage(self, t), true)
		if hit1 then braid_targets[#braid_targets+1] = target end

		--left hit
		if lt and self:reactionToward(lt) < 0 then
			local hit2 = self:attackTarget(lt, nil, t.getDamage(self, t), true)
			if hit2 then braid_targets[#braid_targets+1] = lt end
		end
		--right hit
		if rt and self:reactionToward(rt) < 0 then
			local hit3 = self:attackTarget(rt, nil, t.getDamage(self, t), true)
			if hit3 then braid_targets[#braid_targets+1] = rt end
		end

		-- if we hit more than one, braid them
		if #braid_targets > 1 then
			for i = 1, #braid_targets do
				local target = braid_targets[i]
				target:setEffect(target.EFF_BRAIDED, t.getDuration(self, t), {power=t.getPower(self, t), src=self, targets=braid_targets})
			end
		end

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t) * 100
		local duration = t.getDuration(self, t)
		local power = t.getPower(self, t)
		return ([[Attack your foes in a frontal arc, doing %d%% weapon damage.  If two or more targets are hit you'll braid their lifelines for %d turns.
		Braided targets take %d%% of all damage dealt to other braided targets.
		The damage transfered by the braid effect scales with your Spellpower.]])
		:format(damage, duration, power)
	end
}

newTalent{
	name = "Temporal Assault",
	type = {"chronomancy/blade-threading", 4},
	require = chrono_req4,
	points = 5,
	cooldown = 12,
	paradox = function (self, t) return getParadoxCost(self, t, 15) end,
	tactical = { ATTACKAREA = {weapon = 2}, ATTACK = {weapon = 2},  },
	requires_target = true,
	is_teleport = true,
	speed = "weapon",
	range = 1,
	is_melee = true,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t), talent=t} end,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 0.6, 1.2) end,
	getTeleports = function(self, t) return self:getTalentLevel(t) >= 5 and 2 or 1 end,
	on_pre_use = function(self, t, silent) if not doWardenPreUse(self, "dual") then if not silent then game.logPlayer(self, "You require two weapons to use this talent.") end return false end return true end,
	action = function(self, t)
		local swap = doWardenWeaponSwap(self, "blade")

		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then
			if swap then doWardenWeaponSwap(self, "bow") end
			return nil
		end

		-- Hit the target
		local hitted = self:attackTarget(target, nil, dam, true)

		if hitted then
			-- Get available targets
			local tgts = {}
			local grids = core.fov.circle_grids(self.x, self.y, 10, true)
			for x, yy in pairs(grids) do for y, _ in pairs(grids[x]) do
				local target_type = Map.ACTOR
				local a = game.level.map(x, y, Map.ACTOR)
				if a and self:reactionToward(a) < 0 and self:hasLOS(a.x, a.y) then
					tgts[#tgts+1] = a
					print("Temporal Assault Target %s", a.name)
				end
			end end

			-- Randomly take targets
			local teleports = t.getTeleports(self, t)
			local attempts = 10
			while teleports > 0 and #tgts > 0 and attempts > 0 do
				local a, id = rng.tableRemove(tgts)
				-- since we're using a precise teleport we'll look for a free grid first
				local tx2, ty2 = util.findFreeGrid(a.x, a.y, 5, true, {[Map.ACTOR]=true})
				if tx2 and ty2 and not a.dead then
					game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
					if not self:teleportRandom(tx2, ty2, 0) then
						attempts = attempts - 1
					else
						game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
						if core.fov.distance(self.x, self.y, a.x, a.y) <= 1 then
							self:attackTarget(a, nil, t.getDamage(self, t), true)
							teleports = teleports - 1
						end
					end
				else
					attempts = attempts - 1
				end
			end
		end

		game:playSoundNear(self, "talents/teleport")

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t) * 100
		local teleports = t.getTeleports(self, t)
		return ([[Attack the target with your melee weapons for %d%% damage.  If the attack hits you'll teleport next to up to %d random enemies, attacking for %d%% damage.
		Temporal Assault can hit the same target multiple times and at talent level five you get an additional teleport.]])
		:format(damage, teleports, damage)
	end
}
