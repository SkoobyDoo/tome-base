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
		dam = dam, t=t.id, power = power, dest_power = dest_power,
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
			self.summoner:project({type="hit",x=x,y=y, talent=self.t}, x, y, engine.DamageType.WARP, self.dam)
			
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
	name = "Banish",
	type = {"chronomancy/spacetime-folding", 2},
	require = chrono_req2,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 10,
	tactical = { ESCAPE = 2 },
	range = 0,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 2.5, 5.5)) end,
	getTeleport = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(t), 8, 16)) end,
	target = function(self, t)
		return {type="ball", range=0, radius=self:getTalentRadius(t), selffire=false, talent=t}
	end,
	requires_target = true,
	direct_hit = true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local hit = false

		self:project(tg, self.x, self.y, function(px, py)
			local target = game.level.map(px, py, Map.ACTOR)
			if not target or target == self then return end
			game.level.map:particleEmitter(target.x, target.y, 1, "temporal_teleport")
			if self:checkHit(getParadoxSpellpower(self, t), target:combatSpellResist() + (target:attr("continuum_destabilization") or 0)) and target:canBe("teleport") then
				if not target:teleportRandom(target.x, target.y, self:getTalentRadius(t) * 4, self:getTalentRadius(t) * 2) then
					game.logSeen(target, "The spell fizzles on %s!", target.name:capitalize())
				else
					target:setEffect(target.EFF_CONTINUUM_DESTABILIZATION, 100, {power=getParadoxSpellpower(self, t, 0.3)})
					game.level.map:particleEmitter(target.x, target.y, 1, "temporal_teleport")
					hit = true
				end
			else
				game.logSeen(target, "%s resists the banishment!", target.name:capitalize())
			end
		end)
		
		if not hit then
			game:onTickEnd(function()
				if not self:attr("no_talents_cooldown") then
					self.talents_cd[self.T_BANISH] = self.talents_cd[self.T_BANISH] /2
				end
			end)
		end

		game:playSoundNear(self, "talents/teleport")

		return true
	end,
	info = function(self, t)
		local radius = self:getTalentRadius(t)
		local range = t.getTeleport(self, t)
		return ([[Randomly teleports all targets within a radius of %d around you.  Targets will be teleported between %d and %d tiles from their current location.
		If no targets are teleported the cooldown will be halved.
		The chance of teleportion will scale with your Spellpower.]]):format(radius, range / 2, range)
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
							if self.target ~= self.summoner then 
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

		local particle
		if core.shader.active(4) then
			particle = {type="volumetric", args={radius=self:getTalentRadius(t)+2, kind="fast_sphere", img="moony_01", density=60, shininess=50, scrollingSpeed=-0.004}, only_one=true}
		else
			particle = {type="temporal_cloud"}
		end

		-- Add a lasting map effect
		local dam = self:spellCrit(t.getDamage(self, t))
		game.level.map:addEffect(self,
			x, y, t.getDuration(self,t),
			DamageType.DIMENSIONAL_ANCHOR, {dam=dam, dur=1, src=self, apply=getParadoxSpellpower(self, t)},
			self:getTalentRadius(t),
			5, nil,
			particle,
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