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
		return ([[While active your ranged and melee attacks deal an %0.2f additional temporal damage in a radius %d burst.
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
	getPercent = function(self, t) return self:combatTalentWeaponDamage(t, 0.5, 1.1) end,
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
		doWardenWeaponSwap(m, "blade")
		m.on_act = function(self)
			if not self.blended_target.dead then
				self:attackTarget(self.blended_target, nil, self:callTalent(self.T_FRAYED_THREADS, "getDamage"), true)
				self:useEnergy()
			end
			game:onTickEnd(function()self:die()end)
			game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
		end
		
		-- If we find space, add the clone to the level, it will die after attacking
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
	end,
	doBowWarden = function(self, t, target)
		-- Sanity check
		if not self.turn_procs.blade_warden then
			self.turn_procs.blade_warden = true
		else
			return
		end
	
		-- Make our clone
		local m = makeParadoxClone(self, self, 2)
		m.energy.value = 1000
		m:attr("archery_pass_friendly", 1)
		doWardenWeaponSwap(m, "bow")
		m.on_act = function(self)
			if not self.blended_target.dead then
				local targets = self:archeryAcquireTargets(nil, {one_shot=true, x=self.blended_target.x, y=self.blended_target.y, no_energy = true})
				if targets then
					self:archeryShoot(targets, self:getTalentFromId(self.T_SHOOT), {type="bolt"}, {mult=self:callTalent(self.T_FRAYED_THREADS, "getDamage")})
				end
				self:useEnergy()
			end
			game:onTickEnd(function()self:die()end)
			game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
		end

		-- Find space
		local tgts= t.findTarget(self, t)
		if #tgts > 0 then
			local a, id = rng.table(tgts)
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
			-- Add the clone to the level, it will die after shooting
			if #poss == 0 then return end
			local pos = poss[rng.range(1, #poss)]
			x, y = pos[1], pos[2]
			game.zone:addEntity(game.level, m, "actor", x, y)
			m.blended_target = a
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
		local percent = t.getPercent(self, t) * 100
		return ([[When you hit with a blade-threading or a bow-threading talent a clone will shoot or attack a random enemy for %d%% weapon damage.
		Each of these effects can only occur once per turn.]])
		:format(percent)
	end
}

newTalent{
	name = "Twin Threads",
	type = {"chronomancy/threaded-combat", 4},
	require = chrono_req_high4,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 20) end,
	cooldown = function(self, t) return math.ceil(self:combatTalentLimit(t, 15, 45, 25)) end, -- Limit >15
	tactical = { ATTACK = {weapon = 4} },
	range = 10,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 6, 12))) end,
	getDamagePenalty = function(self, t) return 60 - self:combatTalentLimit(t, 0, 20, 30) end,
	requires_target = true,
	target = function(self, t)
		return {type="hit", range=self:getTalentRange(t)}
	end,
	direct_hit = true,
	remove_on_clone = true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		if not self:hasLOS(x, y) or game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move") then
			game.logSeen(self, "You do not have line of sight.")
			return nil
		end
		local __, x, y = self:canProject(tg, x, y)

		-- First find a position
		local blade_warden = false
		local tx, ty = util.findFreeGrid(x, y, 5, true, {[Map.ACTOR]=true})
		-- Create our melee clone
		if tx and ty then
			game.level.map:particleEmitter(tx, ty, 1, "temporal_teleport")

			-- clone our caster
			local m = makeParadoxClone(self, self, t.getDuration(self, t))

			-- remove some talents; note most of this is handled by makeParadoxClone, but we want to be more extensive
			local tids = {}
			for tid, _ in pairs(m.talents) do
				local t = m:getTalentFromId(tid)
				local tt = self:getTalentFromId(tid)
				if not tt.type[1]:find("^chronomancy/blade") and not tt.type[1]:find("^chronomancy/threaded") and not tt.type[1]:find("^chronomancy/guardian") then
					tids[#tids+1] = t
				end
			end
			for i, t in ipairs(tids) do
				if t.mode == "sustained" and m:isTalentActive(t.id) then m:forceUseTalent(t.id, {ignore_energy=true, silent=true}) end
				m.talents[t.id] = nil
			end

			m.ai_state = { talent_in=2, ally_compassion=10 }
			m.generic_damage_penalty = t.getDamagePenalty(self, t)
			m.remove_from_party_on_death = true

			game.zone:addEntity(game.level, m, "actor", tx, ty)

			m:setTarget(target or nil)

			if game.party:hasMember(self) then
				game.party:addMember(m, {
					control="no",
					type="temporal-clone",
					title="Blade Warden",
					orders = {target=true},
				})
			end

			-- Swap to our blade if needed
			doWardenWeaponSwap(m, t, 0, "blade")
			blade_warden = true
		else
			game.logPlayer(self, "Not enough space to summon blade warden!")
		end

		-- First find a position
		local bow_warden = false
		local poss = {}
		local range = 6
		for i = x - range, x + range do
			for j = y - range, y + range do
				if game.level.map:isBound(i, j) and
					core.fov.distance(x, y, i, j) <= range and -- make sure they're within arrow range
					core.fov.distance(i, j, self.x, self.y) <= range/2 and -- try to place them close to the caster so enemies dodge less
					self:canMove(i, j) and self:hasLOS(i, j) then -- try to keep them in LOS
					-- Make sure our clone can shoot our target, if we have one
					if target and target:hasLOS(i, j) then
						poss[#poss+1] = {i,j}
					elseif not target then
						poss[#poss+1] = {i,j}
					end
				end
			end
		end
		-- Create our archer clone
		if #poss > 0 then
			local pos = poss[rng.range(1, #poss)]
			tx, ty = pos[1], pos[2]
			game.level.map:particleEmitter(tx, ty, 1, "temporal_teleport")

			-- clone our caster
			local m = makeParadoxClone(self, self, t.getDuration(self, t))

			-- remove some talents; note most of this is handled by makeParadoxClone, but we want to be more extensive
			local tids = {}
			for tid, _ in pairs(m.talents) do
				local t = m:getTalentFromId(tid)
				local tt = self:getTalentFromId(tid)
				if not tt.type[1]:find("^chronomancy/bow") and not tt.type[1]:find("^chronomancy/threaded") and not tt.type[1]:find("^chronomancy/guardian") and not t.innate then
					tids[#tids+1] = t
				end
			end
			for i, t in ipairs(tids) do
				if t.mode == "sustained" and m:isTalentActive(t.id) then m:forceUseTalent(t.id, {ignore_energy=true, silent=true}) end
				m.talents[t.id] = nil
			end

			m.ai_state = { talent_in=2, ally_compassion=10 }
			m.generic_damage_penalty = t.getDamagePenalty(self, t)
			m:attr("archery_pass_friendly", 1)
			m.remove_from_party_on_death = true

			game.zone:addEntity(game.level, m, "actor", tx, ty)

			m:setTarget(target or nil)

			if game.party:hasMember(self) then
				game.party:addMember(m, {
					control="no",
					type="temporal-clone",
					title="Bow Warden",
					orders = {target=true},
				})
			end

			-- Swap to our bow if needed
			doWardenWeaponSwap(m, t, 0, "bow")
			bow_warden = true
		else
			game.logPlayer(self, "Not enough space to summon bow warden!")
		end

		game:playSoundNear(self, "talents/teleport")

		if not blade_warden and not bow_warden then  -- If neither summons then don't punish the player
			game.logPlayer(self, "Not enough space to summon!")
			return
		end

		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local damage_penalty = t.getDamagePenalty(self, t)
		return ([[Summons a blade warden and a bow warden from an alternate timeline for %d turns.  The wardens are out of phase with this reality and deal %d%% less damage but the bow warden's arrows will pass through friendly targets.
		Each warden knows all Threaded Combat, Temporal Guardian, and Blade Threading or Bow Threading spells you know.
		The damage penalty will be lessened by your Spellpower.]]):format(duration, damage_penalty)
	end,
}
