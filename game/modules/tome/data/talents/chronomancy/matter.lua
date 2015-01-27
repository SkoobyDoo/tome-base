-- ToME -  Tales of Maj'Eyal
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

local Object = require "mod.class.Object"

newTalent{
	name = "Dust to Dust",
	type = {"chronomancy/matter",1},
	require = chrono_req1,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 3,
	tactical = { ATTACKAREA = {TEMPORAL = 1, PHYSICAL = 1} },
	range = 6,
	direct_hit = true,
	reflectable = true,
	requires_target = true,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 1.25, 3.25)) end,
	target = function(self, t)
		return {type="beam", range=self:getTalentRange(t), talent=t, nowarning=true, selffire=false}
	end,
	getAshes = function(self, t) return {type="ball", range=0, radius=self:getTalentRadius(t), selffire=false} end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 230, getParadoxSpellpower(self, t)) end,
	action = function(self, t)
		-- Check for digs first
		local digs = self:isTalentActive(self.T_DISINTEGRATION) and self:callTalent(self.T_DISINTEGRATION, "getDigs")
		local tg = self:getTalentTarget(t)
		
		-- Just for targeting change to pass terrain
		if digs then tg.pass_terrain = true end
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		
		-- Change back pass terrain
		tg.pass_terrain = nil
		
		
		-- Ashes to Ashes
		if target and target == self then
			tg = t.getAshes(self, t)
			-- We do our digs seperatly and first so we can damage stuff on the other side
			if digs then
				game.level.map:addEffect(self,
					self.x, self.y, 3,
					DamageType.DIG, digs,
					tg.radius,
					5, nil,
					nil,
					function(e)
						e.x = e.src.x
						e.y = e.src.y
						return true
					end,
					tg.selffire
				)
			end
			game.level.map:addEffect(self,
				self.x, self.y, 3,
				DamageType.WARP, self:spellCrit(t.getDamage(self, t)/3),
				tg.radius,
				5, nil,
				engine.MapEffect.new{color_br=180, color_bg=100, color_bb=255, effect_shader="shader_images/magic_effect.png"},
				function(e)
					e.x = e.src.x
					e.y = e.src.y
					return true
				end,
				tg.selffire
			)
			
			game:playSoundNear(self, "talents/cloud")
		else
			-- and Dust to Dust
			if digs then for i = 1, digs do self:project(tg, x, y, DamageType.DIG, 1) end end
		
			self:project(tg, x, y, DamageType.WARP, self:spellCrit(t.getDamage(self, t)))
			local _ _, _, _, x, y = self:canProject(tg, x, y)
			game.level.map:particleEmitter(self.x, self.y, math.max(math.abs(x-self.x), math.abs(y-self.y)), "matter_beam", {tx=x-self.x, ty=y-self.y})
			game:playSoundNear(self, "talents/arcane")
		end
		
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local radius = self:getTalentRadius(t)
		return ([[Fires a beam that turns matter into dust, inflicting %0.2f temporal damage and %0.2f physical (warp) damage.
		Alternatively you may target yourself, creating a field of radius %d around you that will inflict the damage over three turns.
		The damage will scale with your Spellpower.]]):
		format(damDesc(self, DamageType.TEMPORAL, damage / 2), damDesc(self, DamageType.PHYSICAL, damage / 2), radius)
	end,
}

newTalent{
	name = "Matter Weaving",
	type = {"chronomancy/matter",2},
	require = chrono_req2,
	points = 5,
	sustain_paradox = 24,
	mode = "sustained",
	cooldown = 10,
	tactical = { BUFF = 2 },
	getStunResist = function(self, t) return self:combatTalentLimit(t, 1, 0.15, 0.50) end, -- Limit <100%
	getCutResist = function(self, t) return math.min(1, self:combatTalentScale(t, 0.2, 1)) end, -- Limit <100%
	getCap = function(self, t) return 100 - self:combatTalentLimit(t, 50, 10, 40) end, -- Limit < 50%
	activate = function(self, t)
		game:playSoundNear(self, "talents/earth")
		
		local ret = {
			stun = self:addTemporaryValue("stun_immune", t.getStunResist(self, t)),
			cut = self:addTemporaryValue("cut_immune", t.getCutResist(self, t)),
			cap = self:addTemporaryValue("flat_damage_cap", {all=t.getCap(self, t)}),
		}
		
		if not self.shader then
			ret.set_shader = true
			self.shader = "shadow_simulacrum"
			self.shader_args = { color = {0.3, 0.3, 0.3}, base = 0.8, time_factor = 4000 }
			self:removeAllMOs()
			game.level.map:updateMap(self.x, self.y)
		end
		return ret
	end,
	deactivate = function(self, t, p)
		self:removeShaderAura("stone_skin")
		self:removeTemporaryValue("stun_immune", p.stun)
		self:removeTemporaryValue("cut_immune", p.cut)
		self:removeTemporaryValue("flat_damage_cap", p.cap)
		
		self:removeParticles(p.particle)
		
		if p.set_shader then
			self.shader = nil
			self:removeAllMOs()
			game.level.map:updateMap(self.x, self.y)
		end
		return true
	end,
	info = function(self, t)
		local cap = t.getCap(self, t)
		local stun = t.getStunResist(self, t) * 100
		local cut = t.getCutResist(self, t) * 100
		return ([[Weave matter into your flesh, becoming incredibly resilient to damage.  While active you can never take a blow that deals more than %d%% of your maximum life.
		Additionally you gain %d%% resistance to stunning and %d%% resistance to cuts.]]):
		format(cap, stun, cut)
	end,
}

newTalent{
	name = "Materialize Barrier",
	type = {"chronomancy/matter",3},
	require = chrono_req3,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 15) end,
	cooldown = 10,
	tactical = { DISABLE = 2 },
	range = 6,
	direct_hit = true,
	requires_target = true,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 1.25, 3.25)) end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 220, getParadoxSpellpower(self, t)) end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 4, 6))) end,
	getLength = function(self, t) return 1 + math.floor(self:combatTalentScale(t, 3, 7)/2)*2 end,
	target = function(self, t)
		local halflength = math.floor(t.getLength(self,t)/2)
		local block = function(_, lx, ly)
			return game.level.map:checkAllEntities(lx, ly, "block_move")
		end
		return {type="wall", range=self:getTalentRange(t), nolock=true, halflength=halflength, talent=t, halfmax_spots=halflength+1, block_radius=block}
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, _, _, x, y = self:canProject(tg, x, y)
		if game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move") then return nil end

		self:project(tg, x, y, function(px, py, tg, self)
			local oe = game.level.map(px, py, Map.TERRAIN)
			if not oe or oe.special then return end
			if not oe or oe:attr("temporary") or game.level.map:checkAllEntities(px, py, "block_move") then return end
				local e = Object.new{
					old_feat = oe,
					name = "stone wall", image = "terrain/rocky_mountain.png",
					display = '#', color_r=255, color_g=255, color_b=255, back_color=colors.GREY,
					shader = "shadow_simulacrum",
					shader_args = { color = {0.6, 0.6, 0.2}, base = 0.9, time_factor = 1500 },
					desc = "a summoned wall of stone",
					type = "wall", --subtype = "floor",
					always_remember = true,
					can_pass = {pass_wall=1},
					does_block_move = true,
					show_tooltip = true,
					block_move = true,
					block_sight = true,
					temporary = t.getDuration(self, t),
					x = px, y = py,
					canAct = false,
					act = function(self)
						self:useEnergy()
						self.temporary = self.temporary - 1
						if self.temporary <= 0 then
							game.level.map(self.x, self.y, engine.Map.TERRAIN, self.old_feat)
							game.nicer_tiles:updateAround(game.level, self.x, self.y)
							game.level:removeEntity(self)
							game.level.map:scheduleRedisplay()
						end
					end,
					dig = function(src, x, y, old)
						-- Explode!
						local self = game.level.map(x, y, engine.Map.TERRAIN)
						local t = self.summoner:getTalentFromId(self.summoner.T_MATERIALIZE_BARRIER)
						local tg = {type="ball", range=0, radius = self.summoner:getTalentRadius(t), talent=t, x=self.x, y=self.y}
						self.summoner.__project_source = self
						self.summoner:project(tg, self.x, self.y, engine.DamageType.BLEED, self.summoner:spellCrit(t.getDamage(self.summoner, t)))
						self.summoner.__project_source = nil
						game.level.map:particleEmitter(x, y, tg.radius, "ball_earth", {radius=tg.radius})
						
						game.level:removeEntity(old)
						game.level.map:scheduleRedisplay()
						return nil, old.old_feat
					end,
					summoner_gain_exp = true,
					summoner = self,
				}
			e.tooltip = mod.class.Grid.tooltip
			game.level:addEntity(e)
			game.level.map(px, py, Map.TERRAIN, e)
		end)
		
		game:playSoundNear(self, "talents/earth")
		
		return true
	end,
	info = function(self, t)
		local length = t.getLength(self, t)
		local duration = t.getDuration(self, t)
		local damage = t.getDamage(self, t)
		local radius = self:getTalentRadius(t)
		return ([[Create a tightly bound matter wall of up to a length of %d that lasts %d turns.
		If any part of this wall is dug out it will explode, causing targets in a radius of %d to bleed for %0.2f physical damage over six turns.]])
		:format(length, duration, radius, damDesc(self, DamageType.PHYSICAL, damage))
	end,
}

newTalent{
	name = "Disintegration",
	type = {"chronomancy/matter",4},
	require = chrono_req4,
	points = 5,
	sustain_paradox = 24,
	mode = "sustained",
	cooldown = 10,
	tactical = { BUFF = 2 },
	getDigs = function(self, t) return math.floor(self:combatTalentScale(t, 1, 5, "log")) end,
	getChance = function(self, t) return self:combatTalentLimit(t, 50, 10, 40) end, -- Limit < 50%end,
	doStrip = function(self, t, target, type)
		local what = type == "PHYSICAL" and "physical" or "magical"
		local p = self:isTalentActive(self.T_DISINTEGRATION)
		
		if what == "physical" and p.physical[target] then return end
		if what == "magical" and p.magical[target] then return end
		
		if rng.percent(t.getChance(self, t)) then
			local effs = {}
			-- Go through all spell effects
			for eff_id, p in pairs(target.tmp) do
				local e = target.tempeffect_def[eff_id]
				if e.type == what and e.status == "beneficial" then
					effs[#effs+1] = {"effect", eff_id}
				end
			end
	
			if #effs > 0 then
				local eff = rng.tableRemove(effs)
				if eff[1] == "effect" then
					target:removeEffect(eff[2])
					game.logSeen(self, "#CRIMSON#%s's beneficial effect was stripped!#LAST#", target.name:capitalize())
					if what == "physical" then p.physical[target] = true end
					if what == "magical" then p.magical[target] = true end
				end
			end
		end
	end,
	callbackOnActBase = function(self, t)
		-- reset our targets
		local p = self:isTalentActive(self.T_DISINTEGRATION)
		if p then
			p.physical = {}
			p.magical = {}
		end
	end,
	activate = function(self, t)
		game:playSoundNear(self, "talents/earth")

		local particle
		local ret = { 
			physical = {}, magical ={}
		}
		if core.shader.active(4) then
			ret.particle1, ret.particle2 = self:addParticles3D("volumetric", {kind="vertical_and_awesome", radius=1.3, base_rotation=180, density=30, img="continuum_01_6"})
		else
			ret.particle1 = self:addParticles(Particles.new("ultrashield", 1, {rm=40, rM=40, gm=40, gM=40, bm=40, bM=40, am=120, aM=200, radius=0.4, density=50, life=8, instop=60}))
		end
		return ret
	end,
	deactivate = function(self, t, p)
		if p.particle1 then self:removeParticles(p.particle1) end
		if p.particle2 then self:removeParticles(p.particle2) end
		return true
	end,
	info = function(self, t)
		local digs = t.getDigs(self, t)
		local chance = t.getChance(self, t)
		return ([[While active your physical and temporal damage has a %d%% chance to remove one beneficial physical or magical effect (respectively) from targets you hit.
		Only one physical and one magical effect may be removed per turn from each target.
		Additionally your Dust to Dust spell now digs up to %d tiles into walls.]]):
		format(chance, digs)
	end,
}