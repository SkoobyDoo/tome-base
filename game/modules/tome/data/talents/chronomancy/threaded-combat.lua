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
	name = "Frayed Threads",
	type = {"chronomancy/threaded-combat", 1},
	require = chrono_req_high1,
	mode = "sustained",
	points = 5,
	sustain_paradox = 24,
	cooldown = 10,
	tactical = { BUFF = 2 },
	activate = function(self, t)
		return {}
	end,
	deactivate = function(self, t, p)
		return true
	end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 10, 100, getParadoxSpellpower(self, t)) end,
	getRadius = function(self, t) return self:getTalentLevel(t) > 4 and 2 or 1 end,
	callbackOnArcheryAttack = function(self, t, target, hitted, crit, weapon, ammo, damtype, mult, dam)
		if not hitted then return end
		if not target then return end
		t.doExplosion(self, t, target)
	end,
	callbackOnMeleeAttack = function(self, t, target, hitted, crit, weapon, damtype, mult, dam)
		if not hitted then return end
		if not target then return end
		t.doExplosion(self, t, target)
	end,
	doExplosion = function(self, t, target)
		if self.turn_procs.frayed_threads then return end
		self.turn_procs.frayed_threads = true
		
		self:project({type="ball", radius=t.getRadius(self, t), friendlyfire=false}, target.x, target.y, DamageType.TEMPORAL, t.getDamage(self,t))
		-- fixme: graphics by damage type?
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local radius = t.getRadius(self, t)
		return ([[While active your ranged and melee attacks deal an additional %0.2f temporal damage in a radius %d burst.
		This effect may only happen once per turn and the damage will scale with your Spellpower.]])
		:format(damDesc(self, DamageType.TEMPORAL, damage), radius)
	end
}

newTalent{
	name = "Thread the Needle",
	type = {"chronomancy/threaded-combat", 2},
	require = chrono_req_high2,
	points = 5,
	cooldown = 8,
	fixed_cooldown = true,
	paradox = function (self, t) return getParadoxCost(self, t, 15) end,
	tactical = { ATTACKAREA = { weapon = 3 } , DISABLE = 3 },
	requires_target = true,
	range = function(self, t)
		if self:hasArcheryWeapon("bow") then return util.getval(archery_range, self, t) end
		return 0
	end,
	is_melee = function(self, t) return not self:hasArcheryWeapon("bow") end,
	speed = function(self, t) return self:hasArcheryWeapon("bow") and "archery" or "weapon" end,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 1.2, 1.9) end,
	getCooldown = function(self, t) return self:getTalentLevel(t) >= 5 and 2 or 1 end,
	on_pre_use = function(self, t, silent) if self:attr("disarmed") then if not silent then game.logPlayer(self, "You require a weapon to use this talent.") end return false end return true end,
	target = function(self, t)
		local tg = {type="beam", range=self:getTalentRange(t)}
		if not self:hasArcheryWeapon("bow") then
			tg = {type="ball", radius=1, range=self:getTalentRange(t)}
		end
		return tg
	end,
	archery_onhit = function(self, t, target, x, y)
		-- Refresh blade talents
		for tid, cd in pairs(self.talents_cd) do
			local tt = self:getTalentFromId(tid)
			if tt.type[1]:find("^chronomancy/blade") then
				self:alterTalentCoolingdown(tt, - t.getCooldown(self, t))
			end
		end
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local damage = t.getDamage(self, t)
		local mainhand, offhand = self:hasDualWeapon()

		if self:hasArcheryWeapon("bow") then
			-- Ranged attack
			local targets = self:archeryAcquireTargets(tg, {one_shot=true, no_energy = true})
			if not targets then return end
			self:archeryShoot(targets, t, tg, {mult=dam})
		elseif mainhand then
			-- Melee attack
			self:project(tg, self.x, self.y, function(px, py, tg, self)
				local target = game.level.map(px, py, Map.ACTOR)
				if target and target ~= self then
					local hit = self:attackTarget(target, nil, dam, true)
					-- Refresh bow talents
					if hit then
						for tid, cd in pairs(self.talents_cd) do
							local tt = self:getTalentFromId(tid)
							if tt.type[1]:find("^chronomancy/bow") then
								self:alterTalentCoolingdown(tt, - t.getCooldown(self, t))
							end
						end
					end
				end
			end)
			self:addParticles(Particles.new("meleestorm2", 1, {}))
		else
			game.logPlayer(self, "You cannot use Thread the Needle without an appropriate weapon!")
			return nil
		end

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t) * 100
		local cooldown = t.getCooldown(self, t)
		return ([[Attack with your bow or dual-weapons for %d%% damage.
		If you use your bow you'll shoot a beam and each target hit will reduce the cooldown of one Blade Threading spell currently on cooldown by %d.
		If you use your dual-weapons you'll attack all targets within a radius of one around you and each target hit will reduce the cooldown of one Bow Threading spell currently on cooldown by %d.
		At talent level five cooldowns are reduced by two.]])
		:format(damage, cooldown, cooldown)
	end
}

newTalent{
	name = "Blended Threads",
	type = {"chronomancy/threaded-combat", 3},
	require = chrono_req_high3,
	mode = "passive",
	points = 5,
	getPercent = function(self, t) return self:combatTalentScale(t, 20, 50)/100 end,
	info = function(self, t)
		local percent = t.getPercent(self, t) * 100
		return ([[Your Bow Threading and Blade Threading attacks now deal %d%% more weapon damage if you did not have the appropriate weapon equipped when you initated the attack.]])
		:format(percent)
	end
}

newTalent{
	name = "Warden's Call", short_name = WARDEN_S_CALL,
	type = {"chronomancy/threaded-combat", 4},
	require = chrono_req_high4,
	mode = "passive",
	points = 5,
	getDamagePenalty = function(self, t) return 60 - self:combatTalentLimit(t, 30, 0, 20) end,
	doBladeWarden = function(self, t, target)
		-- Sanity check
		if not self.turn_procs.blade_warden then 
			self.turn_procs.blade_warden = true
		else
			return
		end
		
		-- Make our clone
		local m = makeParadoxClone(self, self, 2)
		m.energy.value = 1000
		m.generic_damage_penalty = m.generic_damage_penalty or 0 + t.getDamagePenalty(self, t)
		doWardenWeaponSwap(m, t, nil, "blade")
		m.on_act = function(self)
			if not self.blended_target.dead then
				self:forceUseTalent(self.T_ATTACK, {ignore_cd=true, ignore_energy=true, force_target=self.blended_target, ignore_ressources=true, silent=true})
			end
			self:useEnergy()
			game:onTickEnd(function()self:die()end)
			game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
		end
		
		-- Check Focus first
		local wf = checkWardenFocus(self)
		if wf and not wf.dead then
			local tx, ty = util.findFreeGrid(wf.x, wf.y, 1, true, {[Map.ACTOR]=true})
			if tx and ty then
				game.zone:addEntity(game.level, m, "actor", tx, ty)
				m.blended_target = a
			end
		end
		
		-- Otherwise pick a random target and try to appear next to it
		if not m.blended_target then
			local tgts= t.findTarget(self, t)
			local attempts = 10
			while #tgts > 0 and attempts > 0 do
				local a, id = rng.tableRemove(tgts)
				-- look for space
				local tx, ty = util.findFreeGrid(a.x, a.y, 1, true, {[Map.ACTOR]=true})
				if tx and ty and not a.dead then			
					game.zone:addEntity(game.level, m, "actor", tx, ty)
					m.blended_target = a
					break
				else
					attempts = attempts - 1
				end
			end
		end
	end,
	doBowWarden = function(self, t, target)
		-- Sanity check
		game.logPlayer(self, "You are unable to move!")
		if not self.turn_procs.blade_warden then
			self.turn_procs.blade_warden = true
		else
			return
		end
	
		-- Make our clone
		local m = makeParadoxClone(self, self, 2)
		m.energy.value = 1000
		m.generic_damage_penalty = m.generic_damage_penalty or 0 + t.getDamagePenalty(self, t)
		m:attr("archery_pass_friendly", 1)
		doWardenWeaponSwap(m, t, nil, "bow")
		m.on_act = function(self)
			if not self.blended_target.dead then
				local targets = self:archeryAcquireTargets(nil, {one_shot=true, x=self.blended_target.x, y=self.blended_target.y, no_energy = true})
				if targets then
					self:forceUseTalent(self.T_SHOOT, {ignore_cd=true, ignore_energy=true, force_target=self.blended_target, ignore_ressources=true, silent=true})
				end
			end
			self:useEnergy()
			game:onTickEnd(function()self:die()end)
			game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
		end
		
		-- Find a good location for our shot
		local function find_space(self, target, clone)
			local poss = {}
			local range = archery_range(clone)
			local x, y = target.x, target.y
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
			return x, y
		end
		
		-- Check Focus first
		local wf = checkWardenFocus(self)
		if wf and not wf.dead then
			local tx, ty = find_space(self, target, m)
			if tx and ty then
				game.zone:addEntity(game.level, m, "actor", tx, ty)
				m.blended_target = wf
			end
		else
			local tgts = t.findTarget(self, t)
			if #tgts > 0 then
				local a, id = rng.tableRemove(tgts)
				local tx, ty = find_space(self, target, m)
				game.zone:addEntity(game.level, m, "actor", tx, ty)
				m.blended_target = a
			end
		end
	end,
	findTarget = function(self, t)
		local tgts = {}
		local grids = core.fov.circle_grids(self.x, self.y, 10, true)
		for x, yy in pairs(grids) do for y, _ in pairs(grids[x]) do
			local target_type = Map.ACTOR
			local a = game.level.map(x, y, Map.ACTOR)
			if a and self:reactionToward(a) < 0 and self:hasLOS(a.x, a.y) then
				tgts[#tgts+1] = a
			end
		end end
		
		return tgts
	end,
	info = function(self, t)
		local damage_penalty = t.getDamagePenalty(self, t)
		return ([[When you hit with a blade-threading or a bow-threading talent a warden may appear (depending on available space) from another timeline and shoot or attack a random enemy.
		The wardens are out of phase with this reality and deal %d%% less damage but the bow warden's arrows will pass through friendly targets.
		Each of these effects can only occur once per turn and the wardens return to their own timeline after attacking.]])
		:format(damage_penalty)
	end
}
