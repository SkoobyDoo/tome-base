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

local Object = require "mod.class.Object"

newTalent{
	name = "Spatial Fragments",
	type = {"chronomancy/spatial-tears",1},
	require = chrono_req_high1,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 3,
	tactical = { ATTACK = { TEMPORAL = 1, PHYSICAL = 1 }, },
	range = function(self, t) return math.floor(self:combatTalentScale(t, 5, 9, 0.5, 0, 1)) end,
	proj_speed = 4,
	target = function(self, t)
		return {type="bolt", range=self:getTalentRange(t), talent=t, nowarning=true, display={particle="arrow", particle_args={tile=("particles_images/spatial_fragment"):format(rng.range(1, 4))}}}
	end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 10, 100, getParadoxSpellpower(self, t)) end,
	action = function(self, t)
		local p = self:isTalentActive(self.T_FRACTURED_SPACE)
		
		local tg = self:getTalentTarget(t)
		-- Beam?
		local beam = self:isTalentActive(self.T_FRACTURED_SPACE) and self:isTalentActive(self.T_FRACTURED_SPACE).charges >=6 or false
		if beam then
			tg.type = "beam"
		end
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		if beam then self:isTalentActive(self.T_FRACTURED_SPACE).charges = 0 end
		
		-- Fire one bolt per available target
		if target == self then
			-- Find available targets
			local tgts = {}
			local grids = core.fov.circle_grids(self.x, self.y, self:getTalentRange(t), true)
			for x, yy in pairs(grids) do for y, _ in pairs(grids[x]) do
				local a = game.level.map(x, y, Map.ACTOR)
				if a and self:reactionToward(a) < 0 then
					tgts[#tgts+1] = a
				end
			end end
			
			-- Fire a bolt at each one			
			local dam = self:spellCrit(t.getDamage(self, t))
			for i = 1, 3 do
				if #tgts <= 0 then break end
				local a, id = rng.table(tgts)
				table.remove(tgts, id)
				self:projectile(tg, a.x, a.y, DamageType.WARP, dam, nil)
			end
		else
			-- Fire all bolts at one target
			local dam = self:spellCrit(t.getDamage(self, t))
			for i = 1, 3 do
				self:projectile(tg, x, y, DamageType.WARP, dam, nil)
			end
		end
	
		game:playSoundNear(self, "talents/earth")
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)/2
		return ([[Fire three Spatial Fragments at the target that each inflict %0.2f physical and %0.2f temporal (warp) damage.  If you target yourself you'll instead fire one Spatial Fragment at up to three targets within range.
		If Fractured Space is fully charged the projectiles will be able to pierce through targets.  This will consume your Fractured Space charges.
		The damage scales with your Spellpower.]])
		:format(damDesc(self, DamageType.PHYSICAL, damage), damDesc(self, DamageType.TEMPORAL, damage))
	end,
}

newTalent{
	name = "Discontinuity",
	type = {"chronomancy/spatial-tears", 2},
	require = chrono_req_high2,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 20) end,
	cooldown = 6,
	tactical = { ATTACK = { TEMPORAL = 1, PHYSICAL = 1 }, },
	range = 10,
	direct_hit = true,
	requires_target = true,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 10, 50) end,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(t, 6, 10)) end,
	getLength = function(self, t) return 1 + math.floor(self:combatTalentScale(t, 3, 7)/2)*2 end,
	target = function(self, t)
		local halflength = math.floor(t.getLength(self,t)/2)
		local block = function(_, lx, ly)
			return game.level.map:checkAllEntities(lx, ly, "block_move")
		end
		return {type="wall", range=self:getTalentRange(t), halflength=halflength, talent=t, halfmax_spots=halflength+1, block_radius=block}
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, _, _, x, y = self:canProject(tg, x, y)
		if game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move") then return nil end
		
		local damage = self:spellCrit(t.getDamage(self, t))
		local block = self:isTalentActive(self.T_FRACTURED_SPACE) and self:isTalentActive(self.T_FRACTURED_SPACE).charges >=6 or false
		if block then self:isTalentActive(self.T_FRACTURED_SPACE).charges = 0 end
		self:project(tg, x, y, function(px, py, tg, self)
			local oe = game.level.map(px, py, Map.TERRAIN)
			if not oe or oe.special then return end
			if not oe or oe:attr("temporary") or game.level.map:checkEntity(px, py, Map.TERRAIN, "block_move")  then return end
			local e = Object.new{
				old_feat = oe,
				type = "void", subtype = "void",
				name = "discontinuity",
				display = ' ', image = ("terrain/rift/rift_floor_0%d.png"):format(rng.avg(0, 4, 3)),
				_noalpha = false,
				always_remember = true,
				does_block_move = block,
				block_move = block,
				pass_projectile = true,
				is_void = true,
				can_pass = {pass_void=1},
				show_tooltip = true,
				temporary = t.getDuration(self, t),
				x = px, y = py,
				dam = damage,
				canAct = false,
				t = t.id,
				act = function(self)
					local tg = {type="ball", range=0, friendlyfire=false, radius = 1, talent=self.t, x=self.x, y=self.y,}
					self.summoner.__project_source = self
					local grids = self.summoner:project(tg, self.x, self.y, engine.DamageType.WARP, self.dam)
					if core.shader.active() then
						game.level.map:particleEmitter(self.x, self.y, tg.radius, "starfall", {radius=tg.radius, tx=self.x, ty=self.y})
					else
						game.level.map:particleEmitter(self.x, self.y, tg.radius, "shadow_flash", {radius=tg.radius, grids=grids, tx=self.x, ty=self.y})
					end
					self.summoner.__project_source = nil
					self:useEnergy()
					self.temporary = self.temporary - 1
					if self.temporary <= 0 then
						game.level.map(self.x, self.y, engine.Map.TERRAIN, self.old_feat)
						game.level:removeEntity(self)
						game.level.map:updateMap(self.x, self.y)
						game.nicer_tiles:updateAround(game.level, self.x, self.y)
					end
				end,
				dig = function(src, x, y, old)
					game.level:removeEntity(old)
					return nil, old.old_feat
				end,
				summoner_gain_exp = true,
				summoner = self,
			}
			e.tooltip = mod.class.Grid.tooltip
			game.level:addEntity(e)
			game.level.map(px, py, Map.TERRAIN, e)
			if not block then
				game.nicer_tiles:updateAround(game.level, px, py)
				game.level.map:updateMap(px, py)
			end
		end)
		
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)/2
		local length = t.getLength(self, t)
		local duration = t.getDuration(self, t)
		return ([[Create a void wall of length %d that lasts %d turns.  Each turn the wall deals %0.2f physical and %0.2f temporal (warp) damage to all enemies within a radius of 1.
		If Fractured Space is fully charged the wall will block movement, but not sight or projectiles.  This will consume your Fractured Space charges.
		The damage will scale with your Spellpower.]])
		:format(length, duration, damDesc(self, DamageType.PHYSICAL, damage), damDesc(self, DamageType.TEMPORAL, damage))
	end,
}

newTalent{
	name = "Fractured Space",
	type = {"chronomancy/spatial-tears",3},
	require = chrono_req_high3,
	mode = "sustained",
	sustain_paradox = 24,
	cooldown = 10,
	tactical = { BUFF = 2 },
	points = 5,
	getDamage = function(self, t) return self:combatTalentLimit(t, 100, 10, 75)/12 end,
	getChance = function(self, t) return self:combatTalentLimit(t, 100, 10, 75)/6 end,
	iconOverlay = function(self, t, p)
		local val = p.charges or 0
		if val <= 0 then return "" end
		local fnt = "buff_font"
		return tostring(math.ceil(val)), fnt
	end,
	callbackOnActBase = function(self, t)
		-- Charge decay
		local p = self:isTalentActive(self.T_FRACTURED_SPACE)
		p.decay = p.decay + 1
		if p.decay >=2 then
			p.decay = 0
			p.charges = math.max(p.charges - 1, 0)
		end
	end,
	activate = function(self, t)
		game:playSoundNear(self, "talents/heal")
		--local particle = Particles.new("ultrashield", 1, { rm=0, rM=176, gm=196, gM=255, bm=222, bM=255, am=25, aM=125, radius=0.2, density=30, life=28, instop=-40})
		return {
			charges = 0, decay = 0
		--	particle = self:addParticles(particle)
		}
	end,
	deactivate = function(self, t, p)
	--	self:removeParticles(p.particle)
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local chance = t.getChance(self, t)
		local charges = self:isTalentActive(self.T_FRACTURED_SPACE) and self:isTalentActive(self.T_FRACTURED_SPACE).charges or 0
		return ([[Each time you deal warp damage Fractured Space gains one charge, up to a maximum of six charges.  If you're not generating charges one charge will decay every other turn.
		Each charge increases warp damage by %d%% and gives your Warp damage a %d%% chance to stun, blind, pin, or confuse affected targets for 3 turns.
		If Fractured Space is fully charged, your Spatial Tears talents will consume them when cast and have bonus effects (see indvidual talent descriptions).
		
		Current damage bonus:   %d%%
		Current effect chance:  %d%%]]):format(damage, chance, damage * charges, chance * charges)
	end,
}

newTalent{
	name = "Sphere of Destruction",
	type = {"chronomancy/spatial-tears", 4},
	require = chrono_req_high4,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 18) end,
	cooldown = 18,
	tactical = { ATTACKAREA = {PHYSICAL = 2, TEMPORAL = 2} },
	range = function(self, t) return math.floor(self:combatTalentScale(t, 5, 9, 0.5, 0, 1)) end,
	radius = 3,
	proj_speed = 3,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), selffire=false, talent=t}
	end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 10, 100, getParadoxSpellpower(self, t)) end,
	action = function(self, t)
		local particle = {particle="icestorm"}
		if core.shader.active(4) then
			particle = {particle="volumetric", particle_args={kind="fast_sphere", shininess=60, density=80, scrollingSpeed=0.02, radius=1.2, img="moony_bright_01"}}
		end
		local tg = {type="beam", range=self:getTalentRange(t), talent=t, display=particle}
		local x, y = self:getTarget(tg)
		if not x or not y  then return nil end
		local _ _, _, _, x, y = self:canProject(tg, x, y)
		
		-- Store some values inside the target table so they're not lost when we reload
		tg.chrono_sphere = {}
		tg.chrono_sphere.dam = self:spellCrit(t.getDamage(self, t))
		tg.chrono_sphere.strip = self:isTalentActive(self.T_FRACTURED_SPACE) and self:isTalentActive(self.T_FRACTURED_SPACE).charges >=6 or false
		if tg.chrono_sphere.strip then self:isTalentActive(self.T_FRACTURED_SPACE).charges = 0; tg.chrono_sphere.power = getParadoxSpellpower(self, t) end
		
		-- A beam projectile
		self:projectile(tg, x, y, function(px, py, tg, self)
			-- That projects balls as it moves
			local tg2 = self:getTalentTarget(self:getTalentFromId(self.T_SPHERE_OF_DESTRUCTION))
			self:project(tg2, px, py, function(px2, py2)
				local DamageType = require "engine.DamageType"
				DamageType:get(DamageType.WARP).projector(self, px2, py2, DamageType.WARP, tg.chrono_sphere.dam)
				
				-- Do we strip a sustain?
				if tg.chrono_sphere.strip then
					local target = game.level.map(px2, py2, engine.Map.ACTOR)
					if not target then return end

					local effs = {}
					-- Go through all sustained spells
					for tid, act in pairs(target.sustain_talents) do
						if act then
							effs[#effs+1] = {"talent", tid}
						end
					end

					if #effs == 0 then return end
					local eff = rng.table(effs)

					if self:checkHit(tg.chrono_sphere.power, target:combatSpellResist(), 0, 95, 5) then
						target:crossTierEffect(target.EFF_SPELLSHOCKED, tg.chrono_sphere.power)
						target:forceUseTalent(eff[2], {ignore_energy=true})
					end
				end
			end)
		end)
		
		game:playSoundNear(self, "talents/icestorm")
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)/2
		return ([[Create a Sphere of Destruction that travels towards the target location, inflicting %0.2f physical and %0.2f temporal (warp) damage in a radius of three.
		If Fractured Space is fully charged the Sphere will remove a single sustain from targets it damages.  This will consume your Fractured Space charges.
		The sphere can hit a single target multiple times in one turn and the damage will scale with your Spellpower.]])
		:format(damDesc(self, DamageType.PHYSICAL, damage), damDesc(self, DamageType.TEMPORAL, damage))
	end,
}
