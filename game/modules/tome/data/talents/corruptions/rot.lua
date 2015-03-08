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

newTalent{
	name = "Infectious Bite",
	type = {"technique/other", 1},
	points = 5,
	message = "@Source@ bites blight poison into @target@.",
	cooldown = 3,
	tactical = { ATTACK = {BLIGHT = 2}, },
	requires_target = true,
	range = 1,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 1, 1.5) end,
	getPoisonDamage = function(self, t) return self:combatTalentSpellDamage(t, 22, 200) end,
	action = function(self, t)
		
		local tg = {type="hit", range=self:getTalentRange(t), talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if core.fov.distance(self.x, self.y, x, y) > 1 then return nil end
		
		local dam = t.getDamage(self,t)
		local poison = t.getPoisonDamage(self,t)
		
		-- Hit?
		local hitted = self:attackTarget(target, nil, dam, true)
		
		if hitted then
			self:project({type="hit"}, target.x, target.y, DamageType.BLIGHT_POISON, {dam=poison, power=0, poison=1, apply_power=self:combatSpellpower()})
		end
		
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t) * 100
		local poison = t.getPoisonDamage(self, t)
		return ([[Bite the target, dealing %d%% melee damage  
		If the attack hits you'll inject blight poison into the target, dealing %0.2f blight damage and a further %0.2f blight damage over 4 turns.
		The bonus damage improves with your Spellpower.]])
		:format(damage, damDesc(self, DamageType.BLIGHT, poison/4), damDesc(self, DamageType.BLIGHT, poison) )
	end
}


carrionworm = function(self, target, duration, x, y)
	local m = mod.class.NPC.new{
			type = "vermin", subtype = "worms",
			display = "w", color=colors.SANDY_BROWN, image = "npc/vermin_worms_carrion_worm_mass.png",
			name = "carrion worm mass", faction = self.faction,
			desc = [[]],
			autolevel = "none",
			ai = "summoned", ai_real = "dumb_talented_simple", ai_state = { talent_in=1, },
			stats = { str=10, dex=15, mag=3, con=3 },
			level_range = {self.level, self.level}, exp_worth = 0,
			global_speed_base = 1.0,

			max_life = resolvers.rngavg(5,9),
			size_category = 1,
			cut_immune = 1,
			blind_immune = 1,
			life_rating = 6,
			disease_immune = 1,
			melee_project={[DamageType.PESTILENT_BLIGHT] = self:getTalentLevel(self.T_PESTILENT_BLIGHT)*4,},
			resists = { [DamageType.PHYSICAL] = 50, [DamageType.ACID] = 100, [DamageType.BLIGHT] = 100, [DamageType.FIRE] = -50},
			
			combat_armor = 1, combat_def = 1,
			combat = { dam=1, atk=100, apr=100 },
			autolevel = "warriormage",
			resolvers.talents{ 
			[Talents.T_INFECTIOUS_BITE]=math.floor(self:getTalentLevelRaw(self.T_INFESTATION)),
			},

			
			combat_spellpower = self:combatSpellpower(),

			summoner = self, summoner_gain_exp=true,
			summon_time = 10,
			ai_target = {actor=target}
			


	}

	m.unused_stats = 0
	m.unused_talents = 0
	m.unused_generics = 0
	m.unused_talents_types = 0
	m.no_inventory_access = true
	m.no_points_on_levelup = true
	m.save_hotkeys = true
	m.ai_state = m.ai_state or {}
	m.ai_state.tactic_leash = 100
	-- Try to use stored AI talents to preserve tweaking over multiple summons
	m.ai_talents = self.stored_ai_talents and self.stored_ai_talents[m.name] or {}
	local damincrease = self:getTalentLevel(self.T_INFESTATION)*5
	m.inc_damage.all = 0 + (damincrease or 0)
	m.poolmult = (1 + self:getTalentLevel(self.T_WORM_WALK)*8/100 or 1)
	m.on_die = function(self, src)
				game.level.map:addEffect(self,
				self.x, self.y, 5,
				engine.DamageType.WORMBLIGHT, 0.6*self:combatSpellpower()*self.poolmult,
					2,
					5, nil,
					engine.MapEffect.new{color_br=150, color_bg=255, color_bb=150, effect_shader="shader_images/poison_effect.png"}
				)
				game.logSeen(self, "%s exudes a corrupted gas as it dies.", self.name:capitalize())
	end
			
	if game.party:hasMember(self) then
		m.remove_from_party_on_death = true
	end
	m:resolve() m:resolve(nil, true)
	m:forceLevelup(self.level)
	game.zone:addEntity(game.level, m, "actor", x, y)
	game.level.map:particleEmitter(x, y, 1, "summon")

	-- Summons never flee
	m.ai_tactic = m.ai_tactic or {}
	m.ai_tactic.escape = 0
	m.summon_time = 10

	mod.class.NPC.castAs(m)
	engine.interface.ActorAI.init(m, m)

	return m
end


newTalent{
	name = "Infestation",
	type = {"corruption/rot", 1},
	require = corrs_req_high1,
	points = 5,
	mode = "sustained",
	sustain_vim = 40,
	cooldown = 30,
	getDamageReduction = function(self, t) 
		return self:combatTalentLimit(t, 1, 0.1, 0.22)
	end,
	getDamagePct = function(self, t)
		return self:combatTalentLimit(t, 0.11, 0.3, 0.15)
	end,
	getResist = function(self, t) return 5 * self:getTalentLevel(t) end,
	getAffinity = function(self, t) return 4 * self:getTalentLevel(t) end,
	activate = function(self, t)
		local resist = t.getResist(self,t)
		local affinity = t.getAffinity(self,t)
		local ret = {
					res = self:addTemporaryValue("resists", {[DamageType.BLIGHT]=resist, [DamageType.ACID]=resist}),
					aff = self:addTemporaryValue("damage_affinity", {[DamageType.BLIGHT]=affinity}),
					worm = self:addTemporaryValue("worm", 1),
					}
		return ret
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("resists", p.res)
		self:removeTemporaryValue("damage_affinity", p.aff)
		self:removeTemporaryValue("worm", p.worm)
		return true
	end,
	callbackOnHit = function(self, t, cb)
		if ( cb.value > (t.getDamagePct(self, t) * self.max_life) ) then
			local damageReduction = cb.value * t.getDamageReduction(self, t)
			cb.value = cb.value - damageReduction
			game.logPlayer(self, "#GREEN#A carrion worm mass bursts forth from your wounds, softening the blow and reducing damage taken by #ORCHID#" .. math.ceil(damageReduction) .. "#LAST#.")
			local x, y = util.findFreeGrid(self.x, self.y, 10, true, {[Map.ACTOR]=true})
			if not x then return nil end
			
				local m = carrionworm(self, self, 10, x, y)

			end
			return cb.value
	end, 
	info = function(self, t)
	local resist = t.getResist(self,t)
	local affinity = t.getAffinity(self,t)
	local cap = t.getDamagePct(self,t)
	local damage = t.getDamageReduction(self,t)	
		return ([[Your body has become a mass of living corruption, increasing your blight and acid resistance by %d%%, blight affinity by %d%% and allowing you to heal from your carrion worm blight pools. On taking damage greater than %d%% of your maximum health, the damage will be reduced by %d%% and a carrion worm mass will burst forth onto an adjacent tile, attacking your foes for 10 turns.
Also increases the damage dealt by your carrion worms by %d%% and grants them the Infectious Bite spell at level %d. Carrion worms fully inherit your Spellpower.]]):
		format(resist, affinity, cap*100, damage*100, self:getTalentLevel(t)*5, self:getTalentLevelRaw(t))
	end,
}

newTalent{
	name = "Worm Walk",
	type = {"corruption/rot", 2},
	require = corrs_req_high2,
	points = 5,
	cooldown = function(self, t)
		return math.ceil(self:combatTalentLimit(t, 4, 20, 8)) -- Limit > 4
	end,
	requires_target = true,
	direct_hit = true,
	range = function(self, t) return math.floor(self:combatTalentScale(t, 4, 9)) end,
	getHeal = function(self, t) return self:combatTalentSpellDamage(t, 20, 100, 0.75)/100 end,
	getVim = function(self, t) return 5 * self:getTalentLevel(t) end,
	getDam = function(self, t) return self:combatTalentLimit(t, 4, 20, 10) end,
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t), talent=t}
		local tx, ty, target = self:getTarget(tg)
		if not tx or not ty then return nil end
		if target and target.summoner and target.summoner == self and target.name == "carrion worm mass" then
			local didcrit = self:spellCrit(1)
			self:incVim(didcrit * t.getVim(self, t))
			self:attr("allow_on_heal", 1)
			self:heal(didcrit * (t.getHeal(self, t)) * self.max_life, self)
			self:attr("allow_on_heal", -1)

			game.level.map:remove(self.x, self.y, Map.ACTOR)
			target:die()
			game.level.map(target.x, target.y, Map.ACTOR, self)
			self.x, self.y, target.x, target.y = target.x, target.y, self.x, self.y

			game.level.map:particleEmitter(tx, ty, 3, "circle", {empty_start=8, oversize=1, a=80, appear=8, limit_life=11, speed=5, img="green_demon_fire_circle", radius=3})
			game.level.map:particleEmitter(tx, ty, 3, "circle", {oversize=1, a=80, appear=8, limit_life=11, speed=5, img="demon_fire_circle", radius=3})

			game:playSoundNear(self, "talents/teleport")
		else
			local dam = t.getDam(self, t) * self.life / 100
			local x, y = util.findFreeGrid(tx, ty, 10, true, {[Map.ACTOR]=true})
			if not x then return nil end
			local m = carrionworm(self, self, 10, x, y)
			self:takeHit(dam, self, {source_talent=t})
		end
		return true
	end,
	info = function(self, t)
		local range = self:getTalentRange(t)
		local heal = t.getHeal(self, t) * 100
		local vim = t.getVim(self, t)
		local dam = t.getDam(self,t)
		return ([[Gain the ability to merge and seperate carrion worm masses.
If used on a worm mass, you merge with it, moving to it's location, healing you for %d%% of your maximum health, restoring %d vim, and destroying the mass.
If used on another target, you sacrifice %d%% of your current health to create a worm mass at their location.
Also increases the damage and healing of your carrion worm's blight pool by %d%%.]]):
format (heal, vim, dam, self:getTalentLevel(t)*8)
	end,
}


newTalent{
	name = "Pestilent Blight",
	type = {"corruption/rot",3},
	require = corrs_req_high3,
	points = 5,
	mode = "passive",
	cooldown = 6,
	radius = function(self, t) return self:getTalentLevel(t) >= 4 and 1 or 0 end,
	getChance = function(self, t) return self:combatTalentSpellDamage(t, 10, 60) end,
	getDuration = function(self, t)  return math.floor(self:combatTalentScale(t, 2, 4)) end,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), friendlyfire=false, talent=t}
	end,
	do_rot = function(self, t, target, dam)
		local chance = t.getChance(self,t)
		local dur = t.getDuration(self,t)
		if not dam or type(dam) ~= "number" then return end
		if rng.percent(chance) and not self:isTalentCoolingDown(t.id) then 
				local tg = self:getTalentTarget(t)
				self:project(tg, target.x, target.y, function(px, py, tg, self)
					local target = game.level.map(px, py, Map.ACTOR)
					if target then
						local eff = rng.table{"blind", "silence", "disarm", "pin", }
						if eff == "blind" and target:canBe("blind") then target:setEffect(target.EFF_BLINDED, dur, {apply_power=self:combatSpellpower(), no_ct_effect=true})
							elseif eff == "silence" and target:canBe("silence") then target:setEffect(target.EFF_SILENCED, dur, {apply_power=self:combatSpellpower(), no_ct_effect=true})
							elseif eff == "disarm" and target:canBe("disarm") then target:setEffect(target.EFF_DISARMED, dur, {apply_power=self:combatSpellpower(), no_ct_effect=true})
							elseif eff == "pin" and target:canBe("pin") then target:setEffect(target.EFF_PINNED, dur, {apply_power=self:combatSpellpower(), no_ct_effect=true})
						end
					end
				end)
				self:startTalentCooldown(t.id)
			end
	end,
info = function(self, t)
	local chance = t.getChance(self,t)
	local duration = t.getDuration(self,t)
		return ([[You have a %d%% chance on dealing blight damage to cause the target to rot away, silencing, disarming, blinding or pinning them for %d turns. This effect has a cooldown.
At talent level 4, this affects targets in a radius 1 ball.
Your worms also have a %d%% chance to blind, silence, disarm or pin with their melee attacks, lasting 2 turns.
The chance to apply this effect will increase with your Spellpower.]]):
		format(chance, duration, self:getTalentLevel(t)*4)
	end,
}

newTalent{
	name = "Worm Rot",
	type = {"corruption/rot", 4},
	require = corrs_req_high4,
	points = 5,
	cooldown = 8,
	vim = 10,
	range = 6,
	requires_target = true,
	tactical = { ATTACK = { ACID = 1, BLIGHT = 1 }, DISABLE = 4 },
	getBurstDamage = function(self, t) return self:combatTalentSpellDamage(t, 10, 150) end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 10, 55) end,
	proj_speed = 6,
	spawn_carrion_worm = function (self, target, t)
		local x, y = util.findFreeGrid(target.x, target.y, 10, true, {[Map.ACTOR]=true})
		if not x then return nil end
		local m = carrionworm(self, self, 10, x, y)
		
	end,
	action = function(self, t)
		local tg = {type="bolt", range=self:getTalentRange(t), talent=t, display={particle="bolt_slime"}}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end

		self:project(tg, x, y, function(px, py)
			local target = game.level.map(px, py, engine.Map.ACTOR)
			if not target then return end
			if target:canBe("disease") then
				target:setEffect(target.EFF_WORM_ROT, 5, {src=self, dam=t.getDamage(self, t), burst=t.getBurstDamage(self, t), rot_timer = 5, apply_power=self:combatSpellpower()})
			else
				game.logSeen(target, "%s resists the worm rot!", target.name:capitalize())
			end
			game.level.map:particleEmitter(px, py, 1, "slime")
		end)
		game:playSoundNear(self, "talents/slime")

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local burst = t.getBurstDamage(self, t)
		return ([[Infects the target with parasitic carrion worm larvae for 5 turns.  Each turn the disease will remove a beneficial physical effect and deal %0.2f acid and %0.2f blight damage.
If not cleared after five turns it will inflict %0.2f blight damage as the larvae hatch, removing the effect but spawning a full grown carrion worm mass near the target's location.
The damage dealt will increase with your Spellpower.]]):
		format(damDesc(self, DamageType.ACID, (damage/2)), damDesc(self, DamageType.BLIGHT, (damage/2)), damDesc(self, DamageType.ACID, (burst)))
	end,
}