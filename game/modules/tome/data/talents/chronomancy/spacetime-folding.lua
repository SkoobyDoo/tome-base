-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2014 Nicolas Casalini
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

-- EDGE TODO: Particles, Timed Effect Particles, Mine Tiles

local Trap = require "mod.class.Trap"

makeWarpMine = function(self, t, x, y, type)
	-- Mine values
	local dam = self:spellCrit(self:callTalent(self.T_WARP_MINES, "getDamage"))
	local duration = self:callTalent(self.T_WARP_MINES, "getDuration")
	local detect = math.floor(self:callTalent(self.T_WARP_MINES, "trapPower") * 0.8)
	local disarm = math.floor(self:callTalent(self.T_WARP_MINES, "trapPower"))
	local power = getParadoxSpellpower(self, t)
	local dest_power = getParadoxSpellpower(self, t, 0.3)
	
	-- Our Mines
	local mine = Trap.new{
		name = ("warp mine: %s"):format(type),
		type = "temporal", id_by_type=true, unided_name = "trap",
		display = '^', color=colors.BLUE, image = ("trap/chronomine_%s_0%d.png"):format(type == "toward" and "blue" or "red", rng.avg(1, 4, 3)),
		shader = "shadow_simulacrum", shader_args = { color = {0.2, 0.2, 0.2}, base = 0.8, time_factor = 1500 },
		dam = dam, t=t, power = power, dest_power = dest_power,
		temporary = duration,
		x = x, y = y, type = type,
		summoner = self, summoner_gain_exp = true,
		disarm_power = disarm,	detect_power = detect,
		canTrigger = function(self, x, y, who)
			if who:reactionToward(self.summoner) < 0 then return mod.class.Trap.canTrigger(self, x, y, who) end
			return false
		end,
		triggered = function(self, x, y, who)
			-- Project our damage
			self.summoner:project({type="hit",x=x,y=y, talent=t}, x, y, engine.DamageType.WARP, self.dam)
			
			-- Teleport?
			if not who.dead then
				-- Does our teleport hit?
				local hit = self.summoner:checkHit(self.power, who:combatSpellResist() + (who:attr("continuum_destabilization") or 0)) and who:canBe("teleport")
				if hit then
					game.level.map:particleEmitter(who.x, who.y, 1, "temporal_teleport")
					local teleport_done = false
					
					if self.type == "toward" then
						-- since we're using a precise teleport we'll look for a free grid first
						local tx, ty = util.findFreeGrid(self.summoner.x, self.summoner.y, 5, true, {[engine.Map.ACTOR]=true})
						if tx and ty then
							game.level.map:particleEmitter(who.x, who.y, 1, "temporal_teleport")
							if not who:teleportRandom(self.summoner.x, self.summoner.y, 1, 0) then
								game.logSeen(self, "The teleport fizzles!")
							else
								teleport_done = true
							end
						end
					elseif self.type == "away" then
						game.level.map:particleEmitter(who.x, who.y, 1, "temporal_teleport")
						if not who:teleportRandom(self.summoner.x, self.summoner.y, 10, 5) then
							game.logSeen(self, "The teleport fizzles!")
						else
							teleport_done = true
						end
					end
					
					-- Destabailize?
					if teleport_done then
						who:setEffect(who.EFF_CONTINUUM_DESTABILIZATION, 100, {power=self.dest_power})
						game.level.map:particleEmitter(who.x, who.y, 1, "temporal_teleport")
						game:playSoundNear(self, "talents/teleport")
					end
				else
					game.logSeen(who, "%s resists the teleport!", who.name:capitalize())
				end					
			end
	
			return true, true
		end,
		canAct = false,
		energy = {value=0},
		act = function(self)
			self:useEnergy()
			self.temporary = self.temporary - 1
			if self.temporary <= 0 then
				if game.level.map(self.x, self.y, engine.Map.TRAP) == self then game.level.map:remove(self.x, self.y, engine.Map.TRAP) end
				game.level:removeEntity(self)
			end
		end,
	}
	
	return mine
end

newTalent{
	name = "Warp Mines",
	type = {"chronomancy/spacetime-folding", 1},
	points = 5,
	mode = "passive",
	require = chrono_req1,
	getRange = function(self, t) return math.floor(self:combatTalentScale(t, 5, 9, 0.5, 0, 1)) end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 200, getParadoxSpellpower(self, t)) end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 6, 10))) end, -- Duration of mines
	trapPower = function(self,t) return math.max(1,self:combatScale(self:getTalentLevel(t) * self:getMag(15, true), 0, 0, 75, 75)) end, -- Used to determine detection and disarm power, about 75 at level 50
	on_learn = function(self, t)
		local lev = self:getTalentLevelRaw(t)
		if lev == 1 then
			self:learnTalent(self.T_WARP_MINE_TOWARD, true, nil, {no_unlearn=true})
			self:learnTalent(self.T_WARP_MINE_AWAY, true, nil, {no_unlearn=true})
		end
	end,
	on_unlearn = function(self, t)
		local lev = self:getTalentLevelRaw(t)
		if lev == 0 then
			self:unlearnTalent(self.T_WARP_MINE_TOWARD)
			self:unlearnTalent(self.T_WARP_MINE_AWAY)
		end
	end,
	info = function(self, t)
		local range = t.getRange(self, t)
		local damage = t.getDamage(self, t)/2
		local detect = t.trapPower(self,t)*0.8
		local disarm = t.trapPower(self,t)
		local duration = t.getDuration(self, t)
		return ([[Learn to lay Warp Mines in a radius of 1 out to a range of %d.
		Warp Mines teleport targets that trigger them either toward you or away from you depending on the type of mine used and inflict %0.2f physical and %0.2f temporal (warp) damage.
		The mines are hidden traps (%d detection and %d disarm power based on your Magic) and last for %d turns.
		The damage caused by your Warp Mines will improve with your Spellpower.]]):
		format(range, damDesc(self, DamageType.PHYSICAL, damage), damDesc(self, DamageType.TEMPORAL, damage), detect, disarm, duration) --I5
	end,
}

newTalent{
	name = "Warp Mine Toward",
	type = {"chronomancy/other", 1},
	points = 1,
	cooldown = 10,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	tactical = { ATTACKAREA = { TEMPORAL = 1, PHYSICAL = 1 }, CLOSEIN = 2  },
	requires_target = true,
	range = function(self, t) return self:callTalent(self.T_WARP_MINES, "getRange")end,
	no_unlearn_last = true,
	target = function(self, t) return {type="ball", nowarning=true, range=self:getTalentRange(t), radius=1, nolock=true, talent=t} end,	
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local tx, ty = self:getTarget(tg)
		if not tx or not ty then return nil end
		local __, tx, ty = self:canProject(tg, tx, ty)
	
		-- Lay the mines in a ball
		self:project(tg, tx, ty, function(px, py)
			local target_trap = game.level.map(px, py, Map.TRAP)
			if target_trap then return end
			if game.level.map:checkEntity(px, py, Map.TERRAIN, "block_move") then return end
			
			-- Make our mine
			local trap = makeWarpMine(self, t, px, py, "toward")
			
			-- Add the mine
			game.level:addEntity(trap)
			trap:identify(true)
			trap:setKnown(self, true)
			game.zone:addEntity(game.level, trap, "trap", px, py)
		end)

		game:playSoundNear(self, "talents/heal")
		self:startTalentCooldown(self.T_WARP_MINE_AWAY)
		
		return true
	end,
	info = function(self, t)
		local damage = self:callTalent(self.T_WARP_MINES, "getDamage")/2
		local duration = self:callTalent(self.T_WARP_MINES, "getDuration")
		local detect = self:callTalent(self.T_WARP_MINES, "trapPower") * 0.8
		local disarm = self:callTalent(self.T_WARP_MINES, "trapPower")
		return ([[Lay Warp Mines in a radius of 1 that teleport enemies to you and inflict %0.2f physical and %0.2f temporal (warp) damage.
		The mines are hidden traps (%d detection and %d disarm power based on your Magic) and last for %d turns.
		The damage caused by your Warp Mines will improve with your Spellpower.
		Using this talent will trigger the cooldown on Warp Mine Away.]]):
		format(damDesc(self, DamageType.PHYSICAL, damage), damDesc(self, DamageType.TEMPORAL, damage), detect, disarm, duration)
	end,
}

newTalent{
	name = "Warp Mine Away",
	type = {"chronomancy/other", 1},
	points = 1,
	cooldown = 10,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	tactical = { ATTACKAREA = { TEMPORAL = 1, PHYSICAL = 1 }, ESCAPE = 2  },
	requires_target = true,
	range = function(self, t) return self:callTalent(self.T_WARP_MINES, "getRange") end,
	no_unlearn_last = true,
	target = function(self, t) return {type="ball", nowarning=true, range=self:getTalentRange(t), radius=1, nolock=true, talent=t} end,	
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local tx, ty = self:getTarget(tg)
		if not tx or not ty then return nil end
		local _ _, tx, ty = self:canProject(tg, tx, ty)
		
		-- Lay the mines in a ball
		self:project(tg, tx, ty, function(px, py)
			local target_trap = game.level.map(px, py, Map.TRAP)
			if target_trap then return end
			if game.level.map:checkEntity(px, py, Map.TERRAIN, "block_move") then return end
			
			-- Make our mine
			local trap = makeWarpMine(self, t, px, py, "away")
			
			-- Add the mine
			game.level:addEntity(trap)
			trap:identify(true)
			trap:setKnown(self, true)
			game.zone:addEntity(game.level, trap, "trap", px, py)
		end)

		game:playSoundNear(self, "talents/heal")
		self:startTalentCooldown(self.T_WARP_MINE_TOWARD)
		
		return true
	end,
	info = function(self, t)
		local damage = self:callTalent(self.T_WARP_MINES, "getDamage")/2
		local duration = self:callTalent(self.T_WARP_MINES, "getDuration")
		local detect = self:callTalent(self.T_WARP_MINES, "trapPower") * 0.8
		local disarm = self:callTalent(self.T_WARP_MINES, "trapPower")
		return ([[Lay Warp Mines in a radius of 1 that teleport enemies away from you and inflict %0.2f physical and %0.2f temporal (warp) damage.
		The mines are hidden traps (%d detection and %d disarm power based on your Magic) and last for %d turns.
		The damage caused by your Warp Mines will improve with your Spellpower.
		Using this talent will trigger the cooldown on Warp Mine Away.]]):
		format(damDesc(self, DamageType.PHYSICAL, damage), damDesc(self, DamageType.TEMPORAL, damage), detect, disarm, duration) 
	end,
}

newTalent{
	name = "Wormhole",
	type = {"chronomancy/spacetime-folding", 2},
	require = chrono_req2,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 10,
	tactical = { ESCAPE = 2 },
	range = function(self, t) return math.floor(self:combatTalentScale(t, 5, 9, 0.5, 0, 1)) end,
	radius = function(self, t) return math.floor(self:combatTalentLimit(t, 1, 7, 3)) end, -- Limit to radius 1
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
	name = "Spatial Tether",
	type = {"chronomancy/spacetime-folding", 3},
	require = chrono_req3,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 10,
	tactical = { DISABLE = 2 },
	range = function(self, t) return math.floor(self:combatTalentScale(t, 5, 9, 0.5, 0, 1)) end,
	requires_target = true,
	getDuration = function (self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(self:getTalentLevel(t), 6, 10))) end,
	getChance = function(self, t) return paradoxTalentScale(self, t, 10, 20, 30) end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 200, getParadoxSpellpower(self, t)) end,
	target = function(self, t)
		return {type="hit", range=self:getTalentRange(t), nowarning=true, talent=t}
	end,
	no_energy=true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		local target = game.level.map(x, y, Map.ACTOR)
		if not target then return end
		if game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move") then return end
		
		-- Tether values
		local power = getParadoxSpellpower(self, t)
		local dest_power = getParadoxSpellpower(self, t, 0.3)
		
		-- Store the old terrain
		local oe = game.level.map(target.x, target.y, engine.Map.TERRAIN)
		if not oe or oe:attr("temporary") then return true end
	
		-- Make our tether
		local tether = mod.class.Object.new{
			old_feat = oe, type = oe.type, subtype = oe.subtype,
			name = "temporal instability", image = oe.image, add_mos = {{image="object/temporal_instability.png"}},
			display = '&', color=colors.LIGHT_BLUE,
			temporary = t.getDuration(self, t), 
			power = power, dest_power = dest_power, chance = t.getChance(self, t),
			x = x, y = y, target = target,
			summoner = self, summoner_gain_exp = true,
			canAct = false,
			energy = {value=0},
			act = function(self)
				self:useEnergy()
				self.temporary = self.temporary - 1
				
				-- Teleport
				if not self.target.dead and (game.level and game.level:hasEntity(self.target)) then
					local hit = self.summoner == self.target or (self.summoner:checkHit(self.power, self.target:combatSpellResist() + (self.target:attr("continuum_destabilization") or 0), 0, 95) and self.target:canBe("teleport"))
					if hit and rng.percent(self.chance * core.fov.distance(self.x, self.y, self.target.x, self.target.y)) then	
						game.level.map:particleEmitter(self.target.x, self.target.y, 1, "temporal_teleport")
						-- Since we're using a precise teleport, find a free grit first
						local tx, ty = util.findFreeGrid(self.x, self.y, 5, true, {[engine.Map.ACTOR]=true})
						if not self.target:teleportRandom(tx, ty, 1, 0) then
							game.logSeen(self, "The teleport fizzles!")
						else
							if target ~= self.summoner then 
								self.target:setEffect(self.target.EFF_CONTINUUM_DESTABILIZATION, 100, {power=self.dest_power})
							end
							game.level.map:particleEmitter(self.target.x, self.target.y, 1, "temporal_teleport")
							game:playSoundNear(self, "talents/teleport")
						end
					else
						game.logSeen(self.target, "%s resists the teleport!", self.target.name:capitalize())
					end
				end
				
				-- End the effect?
				if self.temporary <= 0 then
					game.level.map(self.x, self.y, engine.Map.TERRAIN, self.old_feat)
					game.nicer_tiles:updateAround(game.level, self.target.x, self.target.y)
					game.level:removeEntity(self)
				end
			end,
		}
		
		-- add our tether to the map
		game.level:addEntity(tether)
		game.level.map(x, y, Map.TERRAIN, tether)
		game.nicer_tiles:updateAround(game.level, x, y)
		game.level.map:updateMap(x, y)
		game:playSoundNear(self, "talents/heal")
		
		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local chance = t.getChance(self, t)
		return ([[Tethers the target to the location for %d turns.  For each tile the target moves away from the target location it has a %d%% chance each turn of being teleported back to the tether.
		The teleportation chance scales with your Spellpower.]])
		:format(duration, chance)
	end,
}

newTalent{
	name = "Dimensional Anchor",
	type = {"chronomancy/spacetime-folding", 4},
	require = chrono_req4,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 20) end,
	cooldown = 12,
	tactical = { DISABLE = 2 },
	range = function(self, t) return math.floor(self:combatTalentScale(t, 5, 9, 0.5, 0, 1)) end,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 2.5, 4.5)) end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 230, getParadoxSpellpower(self, t)) end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 6, 10))) end,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), friendlyfire=false, radius=self:getTalentRadius(t), talent=t}
	end,
	requires_target = true,
	direct_hit = true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, _, _, x, y = self:canProject(tg, x, y)

		-- Add a lasting map effect
		local dam = self:spellCrit(t.getDamage(self, t))
		game.level.map:addEffect(self,
			x, y, t.getDuration(self,t),
			DamageType.DIMENSIONAL_ANCHOR, {dam=dam, dur=1, src=self, apply=getParadoxSpellpower(self, t)},
			self:getTalentRadius(t),
			5, nil,
			{type="temporal_cloud"},
			nil, false, false
		)

		game:playSoundNear(self, "talents/teleport")

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)/2
		local radius = self:getTalentRadius(t)
		local duration = t.getDuration(self, t)
		return ([[Create a radius %d anti-telport field for %d turns.  Enemies in the field will be anchored, preventing teleportation and taking %0.2f physical and %0.2f temporal (warp) damage on teleport attempts.
		The damage will scale with your Spellpower.]]):format(radius, duration, damDesc(self, DamageType.PHYSICAL, damage), damDesc(self, DamageType.TEMPORAL, damage))
	end,
}