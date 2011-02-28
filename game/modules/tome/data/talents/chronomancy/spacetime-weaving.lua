-- ToME - Tales of Maj'Eyal
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
	name = "Spacetime Tuning",
	type = {"chronomancy/other", 1},
	hide = true,
	points = 1,
	message = "@Source@ retunes the fabric of spacetime.",
	cooldown = 100,
	tactical = { PARADOX = 2 },
	no_npc_use = true,
	no_energy = true,
	getAnomaly = function(self, t) return 6 - (self:getTalentLevelRaw(self.T_STATIC_HISTORY) or 0) end,
	getPower = function(self, t) return math.floor(self:getWil()/2) end,
	action = function(self, t)
		-- open dialog to get desired paradox
		local q = engine.dialogs.GetQuantity.new("Retuning the fabric of spacetime...", 
		"What's your desired paradox level?", math.floor(self.paradox), nil, function(qty)
			
			-- get reduction amount and find duration
			amount = qty - self.paradox
			local dur = math.floor(math.abs(qty-self.paradox)/t.getPower(self, t))
						
			-- set tuning effect
			if amount >= 0 then
				self:setEffect(self.EFF_SPACETIME_TUNING, dur, {power = t.getPower(self, t)})
			elseif amount < 0 then
				self:setEffect(self.EFF_SPACETIME_TUNING, dur, {power = - t.getPower(self, t)})
			end
			
		end)
		game:registerDialog(q)
		return true
	end,
	info = function(self, t)
		local chance = t.getAnomaly(self, t)
		return ([[Retunes your Paradox towards the desired level and informs you of failure, anomaly, and backfire chances when you finish tuning.  You will be dazed while tuning and each turn your Paradox will increase or decrease by an amount equal to one half of your Willpower stat.
		Each turn you spend increasing Paradox will have a %d%% chance of triggering a temporal anomaly which will end the tuning process.  Decreasing Paradox has no chance of triggering an anomaly.]]):
		format(chance)
	end,
}

newTalent{
	name = "Static History",
	type = {"chronomancy/spacetime-weaving", 1},
	require = temporal_req1,
	points = 5,
	message = "@Source@ fixes some of the damage caused to the timeline.",
	cooldown = 24,
	tactical = { PARADOX = 2 },
	getReduction = function(self, t)
		
		--check for Paradox Mastery
		if self:knowTalent(self.T_PARADOX_MASTERY) and self:isTalentActive(self.T_PARADOX_MASTERY) then
			modifier = self:getWil() * (1 + (self:getTalentLevel(self.T_PARADOX_MASTERY)/10) or 0 )
		else
			modifier = self:getWil()
		end
		
		local reduction = (20 + (modifier * self:getTalentLevel(t)/2))
		return reduction
	end,
	action = function(self, t)
		self:incParadox (- t.getReduction(self, t))
		game:playSoundNear(self, "talents/spell_generic")
		return true
	end,
	info = function(self, t)
		local reduction = t.getReduction (self, t)
		return ([[Reduce Paradox by %d by revising past damage you've inflicted on the spacetime continuum.  Talent points invested in Static History will also reduce your chances of triggering an anomaly while using Spacetime Tuning.
		The effect will increase with the Willpower stat.]]):
		format(reduction)
	end,
}

newTalent{
	name = "Dimensional Step",
	type = {"chronomancy/spacetime-weaving", 2},
	require = temporal_req2,
	points = 5,
	paradox = 5,
	cooldown = function(self, t) return 20 - (self:getTalentLevelRaw(t) * 2) end,
	tactical = { CLOSEIN = 2, ESCAPE = 2 },
	range = function(self, t)
		return 5 + (self:getTalentLevelRaw(t))
	end,
	requires_target = true,
	target = function(self, t)
		return {type="hit", range=self:getTalentRange(t)}
	end,
	direct_hit = true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _, x, y = self:canProject(tg, x, y)
		if not self:canBe("teleport") or game.level.map.attrs(x, y, "no_teleport") then
			game.logSeen(self, "The spell fizzles!")
			return true
		end
		if self:hasLOS(x, y) and not game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move") then
			local tx, ty = util.findFreeGrid(x, y, 5, true, {[Map.ACTOR]=true})
			if tx and ty then
				self:move(tx, ty, true)
			end
			game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
			self:move(tx, ty, true)
			game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
			game:playSoundNear(self, "talents/teleport")
		else
			game.logSeen(self, "You cannot move there.")
			return nil
		end
		return true
	end,
	info = function(self, t)
		local range = self:getTalentRange(t)
		return ([[Teleports you to up to %d tiles away to a targeted location in line of sight.
		Additional talent points will lower the cooldown and increase the range.]]):format(range)
	end,
}

newTalent{
	name = "Temporal Reprieve",
	type = {"chronomancy/spacetime-weaving", 3},
	require = temporal_req3,
	points = 5,
	paradox = 20,
	cooldown = 50,
	tactical = { BUFF = 0.5 },
	message = "@Source@ manipulates the flow of time.",
	getCooldownReduction = function(self, t) return 2 + math.ceil(self:getTalentLevel(t) * getParadoxModifier(self, pm)) end,
	action = function(self, t)
		for tid, cd in pairs(self.talents_cd) do
			self.talents_cd[tid] = cd - t.getCooldownReduction(self, t)
		end
		game:playSoundNear(self, "talents/spell_generic2")
		return true
	end,
	info = function(self, t)
		local reduction = t.getCooldownReduction(self, t)
		return ([[All your talents, runes, and infusions currently on cooldown are %d turns closer to being off cooldown.
		The effect will scale with your Paradox.]]):
		format(reduction)
	end,
}

newTalent{
	name = "Wormhole",
	type = {"chronomancy/spacetime-weaving", 4},
	require = temporal_req4,
	points = 5,
	paradox = 20,
	cooldown = 20,
	tactical = { ESCAPE = 2 },
	range = function (self, t)
		return 10 + math.floor(self:getTalentLevel(t)/2)
	end,
	radius = function(self, t)
		return math.floor(7 - self:getTalentLevel(t))
	end,
	requires_target = function(self, t) return self:getTalentLevel(t) >= 4 end,
	getDuration = function (self, t) return 5 + math.floor(self:getTalentLevel(t)*getParadoxModifier(self, pm)) end,
	no_npc_use = true,
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, talent=t}
		local entrance_x, entrance_y = self:getTarget(tg)
		if not entrance_x or not entrance_y then return nil end
		local _ _, entrance_x, entrance_y = self:canProject(tg, entrance_x, entrance_y)
		local trap = game.level.map(entrance_x, entrance_y, engine.Map.TRAP)
		if trap then
			game.logPlayer(self, "You can't place a wormhole entrance on a trap.")
		return end
		if game.level.map.attrs(entrance_x, entrance_y, "no_teleport") or game.level.map:checkEntity(entrance_x, entrance_y, Map.TERRAIN, "block_move") then
			game.logPlayer(self, "You cannot place a wormhole here.")
			return false
		end
		-- Finding the exit location
		-- First, find the center possible exit locations
		local x, y, radius, minimum_distance
		if self:getTalentLevel(t) >= 4 then
			radius = self:getTalentRadius(t)
			minimum_distance = 0
			local tg = {type="ball", nolock=true, pass_terrain=true, nowarning=true, range=self:getTalentRange(t), radius=radius}
			x, y = self:getTarget(tg)
			if not x then return nil end
			-- See if we can actually project to the selected location
			if not self:canProject(tg, x, y) then
				game.logPlayer(self, "Pick a valid location")
				return false
			end
		else
			x, y = self.x, self.y
			radius = 15
			minimum_distance = 10
		end
		-- Second, select one of the possible exit locations
		local poss = {}
			for i = x - radius, x + radius do
				for j = y - radius, y + radius do
					if game.level.map:isBound(i, j) and
						core.fov.distance(x, y, i, j) <= radius and
						core.fov.distance(x, y, i, j) >= minimum_distance and
						self:canMove(i, j) and not game.level.map.attrs(i, j, "no_teleport") and not game.level.map(i, j, engine.Map.TRAP) then
						poss[#poss+1] = {i,j}
					end
				end
			end
			if #poss == 0 then
				game.logPlayer(self, "No exit location could be found.")
			return false end
			local pos = poss[rng.range(1, #poss)]
			exit_x, exit_y = pos[1], pos[2]
		print("[[wormhole]] entrance ", entrance_x, " :: ", entrance_y)
		print("[[wormhole]] exit ", exit_x, " :: ", exit_y)
		-- Adding the entrance wormhole
		local entrance = mod.class.Trap.new{
			name = "wormhole",
			type = "annoy", subtype="teleport", id_by_type=true, unided_name = "trap",
			image = "terrain/wormhole.png",
			display = '&', color_r=255, color_g=255, color_b=255, back_color=colors.STEEL_BLUE,
			message = "@Target@ moves through the wormhole.",
			triggered = function(self, x, y, who)
				local tx, ty = util.findFreeGrid(self.dest.x, self.dest.y, 5, true, {[engine.Map.ACTOR]=true})
				if not tx or not who:canBe("teleport") or game.level.map.attrs(tx, ty, "no_teleport") then
					game.logPlayer(who, "You try to enter the wormhole but a violent force pushes you back.")
					return true
				else
					who:move(tx, ty, true)
				end
				return true
			end,
			disarm = function(self, x, y, who) return false end,
			temporary = t.getDuration(self, t),
			x = entrance_x, y = entrance_y,
			canAct = false,
			energy = {value=0},
			act = function(self)
				self:useEnergy()
				self.temporary = self.temporary - 1
				if self.temporary <= 0 then
					game.logSeen(self, "Reality asserts itself and forces the wormhole shut.")
					game.level.map:remove(self.x, self.y, engine.Map.TRAP)
					game.level:removeEntity(self)
				end
			end,
		}
		game.level:addEntity(entrance)
		entrance:identify(true)
		entrance:setKnown(self, true)
		game.zone:addEntity(game.level, entrance, "trap", entrance_x, entrance_y)
		game.level.map:particleEmitter(entrance_x, entrance_y, 1, "teleport")
		game:playSoundNear(self, "talents/heal")
		-- Adding the exit wormhole
		local exit = entrance:clone()
		exit.x = exit_x
		exit.y = exit_y
		game.level:addEntity(exit)
		exit:identify(true)
		exit:setKnown(self, true)
		game.zone:addEntity(game.level, exit, "trap", exit_x, exit_y)
		game.level.map:particleEmitter(exit_x, exit_y, 1, "teleport")
		-- Linking the wormholes
		entrance.dest = exit
		exit.dest = entrance
		game.logSeen(self, "%s folds the space between two points.", self.name)
		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local radius = self:getTalentRadius(t)
		return ([[You fold the space between two points, allowing travel back and forth between them for the next %d turns.
		At level 4 you may choose the exit location target area (radius %d).  The duration will scale with your Paradox.]])
		:format(duration, radius)
	end,
}
