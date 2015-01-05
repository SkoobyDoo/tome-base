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
	name = "Dimensional Step",
	type = {"chronomancy/spacetime-weaving", 1},
	require = chrono_req1,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 10,
	tactical = { CLOSEIN = 2, ESCAPE = 2 },
	range = function(self, t) return math.floor(self:combatTalentScale(t, 5, 9, 0.5, 0, 1)) end,
	requires_target = true,
	target = function(self, t)
		return {type="hit", nolock=true, range=self:getTalentRange(t)}
	end,
	direct_hit = true,
	no_energy = true,
	is_teleport = true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		if not self:hasLOS(x, y) or game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move") then -- To prevent teleporting through walls
			game.logSeen(self, "You do not have line of sight.")
			return nil
		end
		local _ _, x, y = self:canProject(tg, x, y)
		
		-- Swap?
		if self:getTalentLevel(t) >= 5 and target then
			-- Hit?
			if target:canBe("teleport") and self:checkHit(getParadoxSpellpower(self, t), target:combatSpellResist() + (target:attr("continuum_destabilization") or 0)) then
				-- Grab the caster's location
				local ox, oy = self.x, self.y
			
				-- Remove the target so the destination tile is empty
				game.level.map:remove(target.x, target.y, Map.ACTOR)
				
				-- Try to teleport to the target's old location
				if self:teleportRandom(x, y, 0) then
					-- Put the target back in the caster's old location
					game.level.map(ox, oy, Map.ACTOR, target)
					target.x, target.y = ox, oy
					
					game.level.map:particleEmitter(target.x, target.y, 1, "temporal_teleport")
					game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
				else
					-- If we can't teleport, return the target
					game.level.map(target.x, target.y, Map.ACTOR, target)
					game.logSeen(self, "The spell fizzles!")
				end
			else
				game.logSeen(target, "%s resists the swap!", target.name:capitalize())
			end
		else
			game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
			-- since we're using a precise teleport we'll look for a free grid first
			local tx, ty = util.findFreeGrid(x, y, 5, true, {[Map.ACTOR]=true})
			if tx and ty then
				if not self:teleportRandom(tx, ty, 0) then
					game.logSeen(self, "The spell fizzles!")
				else
					game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
				end
			end
		end
		
		game:playSoundNear(self, "talents/teleport")
		return true
	end,
	info = function(self, t)
		local range = self:getTalentRange(t)
		return ([[Teleports you to up to %d tiles away, to a targeted location in line of sight.
		At talent level 5 you may swap positions with a target creature.]]):format(range)
	end,
}

newTalent{
	name = "Dimensional Shift",
	type = {"chronomancy/spacetime-weaving", 2},
	mode = "passive",
	require = chrono_req2,
	points = 5,
	getReduction = function(self, t) return math.ceil(self:getTalentLevel(t)) end,
	getCount = function(self, t)
		return 1 + math.floor(self:combatTalentLimit(t, 3, 0, 2))
	end,
	doShift = function(self, t)
		local effs = {}
		for eff_id, p in pairs(self.tmp) do
			local e = self.tempeffect_def[eff_id]
			if e.type ~= "other" and e.status == "detrimental" and e.subtype ~= "cross tier" then
				effs[#effs+1] = p
			end
		end
		
		for i=1, t.getCount(self, t) do
			local eff = rng.tableRemove(effs)
			if not eff then break end
			eff.dur = eff.dur - t.getReduction(self, t)
			if eff.dur <= 0 then
				self:removeEffect(eff.effect_id)
			end
		end

	end,
	info = function(self, t)
		local count = t.getCount(self, t)
		local reduction = t.getReduction(self, t)
		return ([[When you teleport you reduce the duration of up to %d detrimental effects by %d turns.]]):
		format(count, reduction)
	end,
}

newTalent{
	name = "Wormhole",
	type = {"chronomancy/spacetime-weaving", 3},
	require = chrono_req3,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 10,
	tactical = { ESCAPE = 2 },
	range = function(self, t) return math.floor(self:combatTalentScale(t, 5, 9, 0.5, 0, 1)) end,
	radius = function(self, t) return math.floor(self:combatTalentLimit(t, 1, 5, 2)) end, -- Limit to radius 1
	requires_target = true,
	getDuration = function (self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(self:getTalentLevel(t), 6, 10))) end,
	no_npc_use = true,
	action = function(self, t)
		-- Target the entrance location
		local tg = {type="bolt", nowarning=true, range=1, nolock=true, simple_dir_request=true, talent=t}
		local entrance_x, entrance_y = self:getTarget(tg)
		if not entrance_x or not entrance_y then return nil end
		local _ _, entrance_x, entrance_y = self:canProject(tg, entrance_x, entrance_y)
		local trap = game.level.map(entrance_x, entrance_y, engine.Map.TRAP)
		if trap or game.level.map:checkEntity(entrance_x, entrance_y, Map.TERRAIN, "block_move") then game.logPlayer(self, "You can't place a wormhole entrance here.") return end

		-- Target the exit location
		local tg = {type="hit", nolock=true, pass_terrain=true, nowarning=true, range=self:getTalentRange(t)}
		local exit_x, exit_y = self:getTarget(tg)
		if not exit_x or not exit_y then return nil end
		local _ _, exit_x, exit_y = self:canProject(tg, exit_x, exit_y)
		local trap = game.level.map(exit_x, exit_y, engine.Map.TRAP)
		if trap or game.level.map:checkEntity(exit_x, exit_y, Map.TERRAIN, "block_move") or core.fov.distance(entrance_x, entrance_y, exit_x, exit_y) < 2 then game.logPlayer(self, "You can't place a wormhole exit here.") return end

		-- Wormhole values
		local power = getParadoxSpellpower(self, t)
		local dest_power = getParadoxSpellpower(self, t, 0.3)
		
		-- Our base wormhole
		local function makeWormhole(x, y, dest_x, dest_y)
			local wormhole = mod.class.Trap.new{
				name = "wormhole",
				type = "annoy", subtype="teleport", id_by_type=true, unided_name = "trap",
				image = "terrain/wormhole.png",
				display = '&', color_r=255, color_g=255, color_b=255, back_color=colors.STEEL_BLUE,
				message = "@Target@ moves onto the wormhole.",
				temporary = t.getDuration(self, t),
				x = x, y = y, dest_x = dest_x, dest_y = dest_y,
				radius = self:getTalentRadius(t),
				canAct = false,
				energy = {value=0},
				disarm = function(self, x, y, who) return false end,
				power = power, dest_power = dest_power,
				summoned_by = self, -- "summoner" is immune to it's own traps
				triggered = function(self, x, y, who)
					local hit = who == self.summoned_by or who:checkHit(self.power, who:combatSpellResist()+(who:attr("continuum_destabilization") or 0), 0, 95) and who:canBe("teleport") -- Bug fix, Deprecrated checkhit call
					if hit then
						game.level.map:particleEmitter(who.x, who.y, 1, "temporal_teleport")
						if not who:teleportRandom(self.dest_x, self.dest_y, self.radius, 1) then
							game.logSeen(who, "%s tries to enter the wormhole but a violent force pushes it back.", who.name:capitalize())
						else
							if who ~= self.summoned_by then who:setEffect(who.EFF_CONTINUUM_DESTABILIZATION, 100, {power=self.dest_power}) end
							game.level.map:particleEmitter(who.x, who.y, 1, "temporal_teleport")
							game:playSoundNear(self, "talents/teleport")
						end
					else
						game.logSeen(who, "%s ignores the wormhole.", who.name:capitalize())
					end
					return true
				end,
				act = function(self)
					self:useEnergy()
					self.temporary = self.temporary - 1
					if self.temporary <= 0 then
						game.logSeen(self, "Reality asserts itself and forces the wormhole shut.")
						if game.level.map(self.x, self.y, engine.Map.TRAP) == self then game.level.map:remove(self.x, self.y, engine.Map.TRAP) end
						game.level:removeEntity(self)
					end
				end,
			}
			
			return wormhole
		end
		
		-- Adding the entrance wormhole
		local entrance = makeWormhole(entrance_x, entrance_y, exit_x, exit_y)
		game.level:addEntity(entrance)
		entrance:identify(true)
		entrance:setKnown(self, true)
		game.zone:addEntity(game.level, entrance, "trap", entrance_x, entrance_y)
		entrance.faction = nil
		game:playSoundNear(self, "talents/heal")

		-- Adding the exit wormhole
		local exit = makeWormhole(exit_x, exit_y, entrance_x, entrance_y)
		exit.x = exit_x
		exit.y = exit_y
		game.level:addEntity(exit)
		exit:identify(true)
		exit:setKnown(self, true)
		game.zone:addEntity(game.level, exit, "trap", exit_x, exit_y)
		exit.faction = nil

		-- Linking the wormholes
		entrance.dest = exit
		exit.dest = entrance

		game.logSeen(self, "%s folds the space between two points.", self.name)
		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local radius = self:getTalentRadius(t)
		local range = self:getTalentRange(t)
		return ([[You fold the space between yourself and a second point within a range of %d, creating a pair of wormholes.  Any creature stepping on either wormhole will be teleported near the other (radius %d accuracy).  
		The wormholes will last %d turns and must be placed at least two tiles apart.
		The chance of teleporting enemies will scale with your Spellpower.]])
		:format(range, radius, duration)
	end,
}

newTalent{
	name = "Phase Pulse",
	type = {"chronomancy/spacetime-weaving", 4},
	require = chrono_req4,
	tactical = { ATTACKAREA = {TEMPORAL = 1, PHYSICAL = 1} },
	mode = "sustained",
	sustain_paradox = 36,
	cooldown = 10,
	points = 5,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 15, 70, getParadoxSpellpower(self, t)) end,
	range = 0,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 1.5, 3.5)) end,
	target = function(self, t)
		return {type="ball", range=100, radius=self:getTalentRadius(t), selffire=false, talent=t}
	end,
	doPulse = function(self, t, ox, oy, fail)
		local tg = self:getTalentTarget(t)
		local dam = self:spellCrit(t.getDamage(self, t))
		local distance = core.fov.distance(self.x, self.y, ox, oy)
		local chance = distance * 10
		
		if not fail then
			dam = dam * (1 + math.min(1, distance/10))
			game:onTickEnd(function()
				self:project(tg, ox, oy, DamageType.WARP, dam)
				self:project(tg, self.x, self.y, DamageType.WARP, dam)
			end)
		else
			dam = dam *2
			chance = 100
			tg.radius = tg.radius * 2
			game:onTickEnd(function()
				self:project(tg, self.x, self.y, DamageType.WARP, dam)
			end)
		end
	end,
	activate = function(self, t)
		game:playSoundNear(self, "talents/spell_generic")
		return {}
	end,
	deactivate = function(self, t, p)
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)/2
		local radius = self:getTalentRadius(t)
		return ([[When you teleport with Phase Pulse active you deal %0.2f physical and %0.2f temporal (warp) damage to all targets in a radius of %d around you.
		For each space you move from your original location the damage is increased by 10%% (to a maximum bonus of 100%%).  If the teleport fails, the blast radius and damage will be doubled.
		This effect occurs both at the entrance and exist locations and the damage will scale with your Spellpower.]]):
		format(damDesc(self, DamageType.PHYSICAL, damage), damDesc(self, DamageType.TEMPORAL, damage), radius)
	end,
}