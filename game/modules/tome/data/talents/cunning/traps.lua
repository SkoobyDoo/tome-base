-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2016 Nicolas Casalini
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

local Chat = require "engine.Chat"
local Map = require "engine.Map"

summon_assassin = function(self, target, duration, x, y, scale )
	local m = mod.class.NPC.new{
			type = "humanoid", subtype = "human",
			display = "p", color=colors.BLUE, image = "npc/humanoid_human_assassin.png", shader = "shadow_simulacrum",
			name = "shadowy assassin", faction = self.faction,
			desc = [[A shadowy image of an assassin.]],
			autolevel = "rogue",
			ai = "dumb_talented_simple", ai_state = { ai_move="move_complex", talent_in=5, },
			stats = { str=8, dex=15, mag=6, cun=15, con=7 },
			infravision = 10,
			max_stamina = 100,
			rank = 2,
			size_category = 3,
			resolvers.racial(),
			resolvers.sustains_at_birth(),
			open_door = true,
			body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1 },
			resolvers.equip{
				{type="weapon", subtype="dagger", autoreq=true},
				{type="weapon", subtype="dagger", autoreq=true},
				{type="armor", subtype="light", autoreq=true}
			},
			resolvers.talents{
				[Talents.T_LETHALITY]={base=5, every=6, max=8},
				[Talents.T_KNIFE_MASTERY]={base=0, every=6, max=6},
				[Talents.T_WEAPON_COMBAT]={base=0, every=6, max=6},
			},
			infravision = 10,
			
			no_drops = 1,
			combat_armor = 3, combat_def = 10,
			summoner = self, summoner_gain_exp=true,
			summon_time = duration,
			ai_target = {actor=target},
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
	m:resolve() m:resolve(nil, true)
	m:forceLevelup(self.level)

	game.zone:addEntity(game.level, m, "actor", x, y)
	game.level.map:particleEmitter(x, y, 1, "summon")


	-- Summons never flee
	m.ai_tactic = m.ai_tactic or {}
	m.ai_tactic.escape = 0
	m.summon_time = duration


	mod.class.NPC.castAs(m)
	engine.interface.ActorAI.init(m, m)
	m.energy.value = 0

	return m
end

summon_bladestorm = function(self, target, duration, x, y, scale )
	local m = mod.class.NPC.new{
			type = "construct", subtype = "trap",
			display = "^", color=colors.BROWN, image = "npc/trap_bladestorm_swish_01.png",
			name = "bladestorm trap", faction = self.faction,
			desc = [[A lethal contraption of whirling blades.]],
			autolevel = "warrior",
			ai = "dumb_talented_simple", ai_state = { ai_move="move_complex", talent_in=5, },
			stats = { str=18, dex=15, mag=6, cun=6, con=7 },
			max_stamina = 100,
			rank = 2,
			size_category = 3,
			resolvers.sustains_at_birth(),
			body = { INVEN = 10, MAINHAND=1 },
			resolvers.equip{
				{type="weapon", subtype="greatsword", autoreq=true},
			},
			resolvers.talents{
				[Talents.T_WEAPONS_MASTERY]={base=1, every=6, max=5},
				[Talents.T_WEAPON_COMBAT]={base=1, every=6, max=5},
			},
			on_act = function(self)
				if self.turn_procs.bladestorm_trap then return end
				self.turn_procs.bladestorm_trap = true
		
				local showoff = false
				local tg = {type="ball", range=0, selffire=false, radius=1}

				self:project(tg, self.x, self.y, function(px, py, tg, self)
					local target = game.level.map(px, py, engine.Map.ACTOR)
					if target and self:reactionToward(target) < 0 then
						self:attackTarget(target, nil, 1.0, false)
					end
				end)
				self:addParticles(Particles.new("meleestorm", 1, {img="spinningwinds_red"}))
				self:addParticles(Particles.new("meleestorm", 1, {img="spinningwinds_red"}))
			end,

			life_rating = 12,
			never_move = 1,

			combat_armor = self.level * 2, combat_def = self.level * 2,
			resists = {all = 40},
			negative_status_immune = 1,
			
			no_drops = 1,
			summoner = self, summoner_gain_exp=true,
			summon_time = duration,
			ai_target = {actor=target},
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
	m:resolve() m:resolve(nil, true)
	m:forceLevelup(self.level)

	game.zone:addEntity(game.level, m, "actor", x, y)
	game.level.map:particleEmitter(x, y, 1, "summon")


	-- Summons never flee
	m.ai_tactic = m.ai_tactic or {}
	m.ai_tactic.escape = 0
	m.summon_time = duration


	mod.class.NPC.castAs(m)
	engine.interface.ActorAI.init(m, m)
	m.energy.value = 0

	return m
end

local trap_range = function(self, t)
	if not self:knowTalent(self.T_TRAP_LAUNCHER) then return 1 end
	return math.floor(self:combatTalentScale(self:getTalentLevel(self.T_TRAP_LAUNCHER), 2, 7, "log")) -- 2@1, 7@5
end
local trapPower = function(self,t) return math.max(1,self:combatScale(self:getTalentLevel(self.T_TRAP_MASTERY) * self:getCun(15, true), 0, 0, 75, 75)) end -- Used to determine detection and disarm power, about 75 at level 50

----------------------------------------------------------------
-- Trapping
----------------------------------------------------------------

newTalent{
	name = "Trap Mastery",
	type = {"cunning/trapping", 1},
	require = cuns_req1,
	points = 5,
	cooldown = 60,
	getTrapMastery = function(self, t) return self:combatTalentScale(t, 20, 100, 0.5, 0, 0, true) end,
	getPower = trapPower,
	getNbTraps = function(self, t)
		if self:getTalentLevel(t) >= 3 then
			return 3
		elseif self:getTalentLevel(t) >= 2 then
			return 2
		else 
			return 1
		end
	end,
	no_npc_use = true,  -- so rares don't learn useless talents
	no_unlearn_last = true,
	action = function(self, t)
		if self:knowTalent(self.T_SPRINGRAZOR_TRAP) then self:unlearnTalent(self.T_SPRINGRAZOR_TRAP) end
		if self:knowTalent(self.T_BEAR_TRAP) then self:unlearnTalent(self.T_BEAR_TRAP) end
		if self:knowTalent(self.T_PITFALL_TRAP) then self:unlearnTalent(self.T_PITFALL_TRAP) end
		if self:knowTalent(self.T_FLASH_BANG_TRAP) then self:unlearnTalent(self.T_FLASH_BANG_TRAP) end
		if self:knowTalent(self.T_BLADESTORM_TRAP) then self:unlearnTalent(self.T_BLADESTORM_TRAP) end
		if self:knowTalent(self.T_POISON_GAS_TRAP) then self:unlearnTalent(self.T_POISON_GAS_TRAP) end
		if self:knowTalent(self.T_AMBUSH_TRAP) then self:unlearnTalent(self.T_AMBUSH_TRAP) end
		if self:knowTalent(self.T_BEAM_TRAP) then self:unlearnTalent(self.T_BEAM_TRAP) end
		if self:knowTalent(self.T_PURGING_TRAP) then self:unlearnTalent(self.T_PURGING_TRAP) end
		if self:knowTalent(self.T_DRAGONSFIRE_TRAP) then self:unlearnTalent(self.T_DRAGONSFIRE_TRAP) end
		if self:knowTalent(self.T_FREEZING_TRAP) then self:unlearnTalent(self.T_FREEZING_TRAP) end

		local nb = t.getNbTraps(self,t)
		
		for i = 1, nb do
			local chat = Chat.new("trap-mastery", self, self, {player=self})
			self:talentDialog(chat:invoke())
		end


		return true
	end,
	info = function(self, t)
		local detect_power = t.getPower(self, t)
		local disarm_power = t.getPower(self, t)*1.25
		return ([[You learn how to prepare traps, having up to 3 prepared and available at one time. Using this ability allows you to change your trap setup.
		You will learn new traps as follows:
		Level 1: Springrazor Trap
		Level 2: Bear Trap
		Level 3: Pitfall Trap
		Level 4: Flashbang Trap
		Level 5: Bladestorm Trap
		New traps can also be learned from special teachers in the world.
		This talent also increases the effectiveness of your traps by %d%% (The effect varies for each trap.) and makes them more difficult to detect and disarm (%d detection 'power' and %d disarm 'power') based on your Cunning.
		If a trap is not triggered 80%% of its stamina cost will be refunded when it expires.
		You are immune to the negative effects and damage of your traps, and traps may critically strike based on your physical crit chance.]]):
		format(t.getTrapMastery(self,t), detect_power, disarm_power) --I5
	end,
}

newTalent{
	name = "Lure",
	type = {"cunning/trapping", 2},
	points = 5,
	cooldown = 15,
	stamina = 15,
	no_break_stealth = true,
	require = cuns_req2,
	no_npc_use = true,
	range = function(self, t) return math.floor(self:combatTalentScale(t, 6, 11)) end,
	getDuration = function(self,t) return math.floor(self:combatTalentScale(t, 5, 9, 0.5, 0, 0, true)) end,
	speed = "combat",
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local tx, ty, target = self:getTarget(tg)
		if not tx or not ty then return nil end
		local _ _, _, _, tx, ty = self:canProject(tg, tx, ty)
		target = game.level.map(tx, ty, Map.ACTOR)
		if target == self then target = nil end

		-- Find space
		local x, y = util.findFreeGrid(tx, ty, 5, true, {[Map.ACTOR]=true})
		if not x then
			game.logPlayer(self, "Not enough space to summon!")
			return
		end

		local NPC = require "mod.class.NPC"
		local m = NPC.new{
			type = "construct", subtype = "lure",
			display = "*", color=colors.UMBER,
			name = "lure", faction = self.faction, image = "npc/lure.png",
			desc = [[A noisy lure.]],
			autolevel = "none",
			ai = "summoned", ai_real = "dumb_talented", ai_state = { talent_in=1, },
			level_range = {1, 1}, exp_worth = 0,

			max_life = 2 * self.level,
			life_rating = 0,
			never_move = 1,

			-- Hard to kill at range
			combat_armor = 10, combat_def = 0, combat_def_ranged = self.level * 2.2,
			-- Hard to kill with spells
			resists = {[DamageType.PHYSICAL] = -90, all = 90},
			poison_immune = 1,

			talent_cd_reduction={[Talents.T_TAUNT]=2, },
			resolvers.talents{
				[self.T_TAUNT]=self:getTalentLevelRaw(t),
			},

			summoner = self, summoner_gain_exp=true,
			summon_time = t.getDuration(self,t),
		}
		if self:getTalentLevel(t) >= 5 then
			m.on_die = function(self, src)
				if not src or src == self then return end
				self:project({type="ball", range=0, radius=2}, self.x, self.y, function(px, py)
					local trap = game.level.map(px, py, engine.Map.TRAP)
					if not trap or not trap.lure_trigger then return end
					trap:trigger(px, py, src)
				end)
			end
		end

		m:resolve() m:resolve(nil, true)
		m:forceLevelup(self.level)
		game.zone:addEntity(game.level, m, "actor", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")
		return true
	end,
	info = function(self, t)
		local t2 = self:getTalentFromId(self.T_TAUNT)
		local rad = t2.radius(self, t)
		return ([[Project a noisy lure for %d turns that attracts all creatures in a radius %d to it.
		At level 5, when the lure is destroyed, it will trigger some traps in a radius of 2 around it (check individual traps to see if they are triggered).
		Use of this talent will not break stealth.]]):format(t.getDuration(self,t), rad)
	end,
}

newTalent{
	name = "Trap Launcher",
	type = {"cunning/trapping", 3},
	points = 5,
	mode = "passive",
	no_npc_use = true,
	require = cuns_req3,
	info = function(self, t)
		return ([[Allows you to create self deploying traps that you can launch up to %d grids away.
		At level 5 you learn to do this in total silence, letting you lay traps without breaking stealth.]]):format(trap_range(self, t))
	end,
}

newTalent{
	name = "Preparation",
	type = {"cunning/trapping", 4},
	require = cuns_req4,
	points = 5,
	cooldown = 60,
	no_npc_use = true,  -- so rares don't learn useless talents
	no_unlearn_last = true,
	getTrapMastery = function(self, t) return self:combatTalentScale(t, 20, 100, 0.5, 0, 0, true) end,
	getPower = trapPower,
	action = function(self, t)
		if self:knowTalent(self.T_SPRINGRAZOR_PREP) then self:unlearnTalent(self.T_SPRINGRAZOR_PREP) end
		if self:knowTalent(self.T_FLASH_BANG_PREP) then self:unlearnTalent(self.T_FLASH_BANG_PREP) end
		if self:knowTalent(self.T_POISON_GAS_PREP) then self:unlearnTalent(self.T_POISON_GAS_PREP) end
		if self:knowTalent(self.T_PURGING_PREP) then self:unlearnTalent(self.T_PURGING_PREP) end
		if self:knowTalent(self.T_DRAGONSFIRE_PREP) then self:unlearnTalent(self.T_DRAGONSFIRE_PREP) end
		if self:knowTalent(self.T_FREEZING_PREP) then self:unlearnTalent(self.T_FREEZING_PREP) end
		
		local chat = Chat.new("trap-preparation", self, self, {player=self})
		self:talentDialog(chat:invoke())
		return true
	end,
	info = function(self, t)
		local detect_power = t.getPower(self, t)
		local disarm_power = t.getPower(self, t)*1.25
		return ([[You learn how to create modified traps that activate immediately on being laid. 
You are unable to modify a trap you are already using with Trap Mastery, and only certain traps can be prepared in this way.
Modified traps do not benefit from trap mastery, and instead gain a %d%% bonus in effectiveness from this talent.]]):
		format(t.getTrapMastery(self,t)) --I5
	end,
}

----------------------------------------------------------------
-- Traps
----------------------------------------------------------------

local basetrap = function(self, t, x, y, dur, add)
	local Trap = require "mod.class.Trap"
	local trap = {
		id_by_type=true, unided_name = "trap",
		display = '^',
		faction = self.faction,
		summoner = self, summoner_gain_exp = true,
		temporary = dur,
		x = x, y = y,
		detect_power = math.floor(trapPower(self,t)),
		disarm_power = math.floor(trapPower(self,t)*1.25),
		canAct = false,
		energy = {value=0},
		inc_damage = table.clone(self.inc_damage or {}, true),
		resists_pen = table.clone(self.resists_pen or {}, true),
		act = function(self)
			if self.realact then self:realact() end
			self:useEnergy()
			self.temporary = self.temporary - 1
			if self.temporary <= 0 then
				if game.level.map(self.x, self.y, engine.Map.TRAP) == self then
					game.level.map:remove(self.x, self.y, engine.Map.TRAP)
					if self.summoner and self.stamina then -- Refund
						self.summoner:incStamina(self.stamina * 0.8)
					end
				end
				game.level:removeEntity(self)
			end
		end,
	}
	table.merge(trap, add)
	return Trap.new(trap)
end

function trap_stealth(self, t)
	if self:getTalentLevel(self.T_TRAP_LAUNCHER) >= 5 then
		return true
	end
	return false
end

newTalent{
	name = "Springrazor Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 8,
	stamina = 15,
	requires_target = true,
	range = trap_range,
	no_break_stealth = trap_stealth,
	tactical = { ATTACKAREA = { PHYSICAL = 2 } },
	no_unlearn_last = true,
	speed = "combat",
	getDamage = function(self, t) return 30 + self:combatStatScale("cun", 8, 80) * self:callTalent(self.T_TRAP_MASTERY, "getTrapMastery")/20 end,
	getPower = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(self.T_TRAP_MASTERY), 10, 25)) end,
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end

		local dam = self:physicalCrit(t.getDamage(self, t))
		local power = t.getPower(self,t)
		local t = basetrap(self, t, x, y, 8 + self:getTalentLevel(self.T_TRAP_MASTERY), {
			type = "physical", name = "springrazor trap", color=colors.LIGHT_RED, image = "trap/trap_springrazor.png",
			dam = dam,
			power = power,
			check_hit = self:combatAttack(),
			stamina = t.stamina,
			lure_trigger = true,
			triggered = function(self, x, y, who)
				self:project({type="ball", x=x,y=y, radius=2}, x, y, function(px, py)
					local who = game.level.map(px, py, engine.Map.ACTOR)
					if who == self.summoner then return end
					if who then
						who:setEffect(who.EFF_RAZORWIRE, 3, {power=self.power, apply_power=self.check_hit})
					end
					engine.DamageType:get(engine.DamageType.PHYSICAL).projector(self.summoner, px, py, engine.DamageType.PHYSICAL, self.dam)
				end)
				game.level.map:particleEmitter(x, y, 2, "meleestorm", {radius=2, tx=x, ty=y})
				return true, true
			end,
		})
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		local dam = t.getDamage(self, t)
		local power = t.getPower(self,t)
		return ([[Lay a trap that explodes into a radius 2 wave of razor sharp wire, doing %0.2f physical damage. Those struck by the wire have be shredded, reducing accuracy, armor and defence by %d.
		High level lure can trigger this trap, and this trap can be used with Preparation.]]):
		format(damDesc(self, DamageType.PHYSICAL, dam), power)
	end,
}

newTalent{
	name = "Bear Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 12,
	stamina = 10,
	requires_target = true,
	range = trap_range,
	tactical = { DISABLE = { pin = 2 } },
	no_break_stealth = trap_stealth,
	no_unlearn_last = true,
	getDamage = function(self, t) return (20 + self:combatStatScale("cun", 10, 75) * self:callTalent(self.T_TRAP_MASTERY, "getTrapMastery")/20)/5 end,
	speed = "combat",
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end

		local dam = self:physicalCrit(t.getDamage(self, t))
		local Trap = require "mod.class.Trap"
		local t = basetrap(self, t, x, y, 8 + self:getTalentLevel(self.T_TRAP_MASTERY), {
			type = "physical", name = "bear trap", color=colors.UMBER, image = "trap/beartrap01.png",
			dam = dam,
			stamina = t.stamina,
			check_hit = self:combatAttack(),
			triggered = function(self, x, y, who)
				self:project({type="hit", x=x,y=y}, x, y, engine.DamageType.PHYSICAL, self.dam*2)
				if who then
					if who:canBe("slow") and who:canBe("pin") then
						who:setEffect(who.EFF_BEAR_TRAP, 5, {src=self.summoner, power=0.3, dam=self.dam})
					elseif who:canBe("pin") then
						who:setEffect(who.EFF_BEAR_TRAP_PIN, 5, {src=self.summoner, dam=self.dam})
					elseif who:canBe("slow") then
						who:setEffect(who.EFF_BEAR_TRAP_SLOW, 5, {src=self.summoner, power=0.3, dam=self.dam})
					elseif who:canBe("cut") then who:setEffect(who.EFF_CUT, 5, {src=self.summoner, power=self.dam})
					else
						game.logSeen(who, "%s resists!", who.name:capitalize())
					end
				end
				return true, true
			end,
		})
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Lay a bear trap. The first creature passing by will be caught in the trap, taking %0.2f physical damage and pinning, slowing (30%%) and bleeding them for %0.2f physical damage each turn for 5 turns.]]):
		format(damDesc(self, DamageType.PHYSICAL, t.getDamage(self, t)*2), damDesc(self, DamageType.PHYSICAL, t.getDamage(self, t))) --I5
	end,
}

newTalent{
	name = "Pitfall Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 20,
	stamina = 10,
	requires_target = true,
	range = trap_range,
	tactical = { DISABLE = { pin = 2 } },
	no_break_stealth = trap_stealth,
	no_unlearn_last = true,
	getDamage = function(self, t) return (10 + self:combatStatScale("cun", 10, 50) * self:callTalent(self.T_TRAP_MASTERY, "getTrapMastery")/20) end,
	speed = "combat",
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end

		local dam = self:physicalCrit(t.getDamage(self, t))
		local Trap = require "mod.class.Trap"
		local t = basetrap(self, t, x, y, 8 + self:getTalentLevel(self.T_TRAP_MASTERY), {
			type = "physical", name = "pitfall trap", color=colors.UMBER, image = "trap/trap_pitfall_setup.png",
			dam = dam,
			stamina = t.stamina,
			check_hit = self:combatAttack(),
			triggered = function(self, x, y, who)

				self:project({type="hit", x=x,y=y}, x, y, engine.DamageType.PHYSICAL, self.dam )
				
				-- If they're dead don't remove them
				if who.dead or who.player then return true, true end
				
				-- Check hit
				local hit = self:checkHit(self.check_hit, who:combatPhysicalResist())
				if not hit then game.logSeen(who, "%s resists!", who.name:capitalize()) return true, true end
								
				-- Placeholder for the actor
				local oe = game.level.map(x, y, engine.Map.TERRAIN+1)
				if (oe and oe:attr("temporary")) or game.level.map:checkEntity(x, y, engine.Map.TERRAIN, "block_move") then game.logPlayer(self, "Something has prevented the pit.") return true end
				local e = mod.class.Object.new{
					old_feat = oe, type = "pit", subtype = "pit",
					name = "pit", image = "trap/trap_pitfall_pit.png",
					display = '&', color=colors.BROWN,
					temporary = 5,
					canAct = false,
					target = who,
					act = function(self)
						self:useEnergy()
						self.temporary = self.temporary - 1
						-- return the rifted actor
						if self.temporary <= 0 then
							-- remove ourselves
							if self.old_feat then game.level.map(self.target.x, self.target.y, engine.Map.TERRAIN+1, self.old_feat)
							else game.level.map:remove(self.target.x, self.target.y, engine.Map.TERRAIN+1) end
							game.nicer_tiles:updateAround(game.level, self.target.x, self.target.y)
							game.level:removeEntity(self)
							game.level.map:removeParticleEmitter(self.particles)
							
							-- return the actor and reset their values
							local mx, my = util.findFreeGrid(self.target.x, self.target.y, 20, true, {[engine.Map.ACTOR]=true})
							local old_levelup = self.target.forceLevelup
							local old_check = self.target.check
							self.target.forceLevelup = function() end
							self.target.check = function() end
							game.zone:addEntity(game.level, self.target, "actor", mx, my)
							self.target.forceLevelup = old_levelup
							self.target.check = old_check
						end
					end,
					summoner_gain_exp = true, summoner = self,
				}
				
				-- Remove the target
				game.logSeen(who, "The ground collapses under %s!", who.name:capitalize())
				game.level:removeEntity(who, true)
				game.level.map:particleEmitter(x, y, 1, "fireflash", {radius=2, tx=x, ty=y})
				
				local particle = Particles.new("wormhole", 1, {image="shockbolt/trap/trap_pitfall_pit", speed=0})
				particle.zdepth = 6
				e.particles = game.level.map:addParticleEmitter(particle, x, y)
						
				game.level:addEntity(e)
				game.level.map(x, y, engine.Map.TERRAIN+1, e)
				game.level.map:updateMap(x, y)
			
			
				return true, true
			end,
		})
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Lay a trap that collapses the ground under the target, dealing %0.2f physical damage and removing them from combat for 5 turns.]]):
		format(damDesc(self, DamageType.PHYSICAL, t.getDamage(self, t)))
	end,
}

newTalent{
	name = "Flash Bang Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 12,
	stamina = 12,
	tactical = { DISABLE = { blind = 1, stun = 1 } },
	requires_target = true,
	range = trap_range,
	no_break_stealth = trap_stealth,
	no_unlearn_last = true,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(self.T_TRAP_MASTERY), 2.5, 4.5)) end,
	getDamage = function(self, t) return 25 + self:combatStatScale("cun", 10, 70) * self:callTalent(self.T_TRAP_MASTERY,"getTrapMastery") / 20 end,
	speed = "combat",
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end

		local Trap = require "mod.class.Trap"
		local dam = self:physicalCrit(t.getDamage(self, t))
		local t = basetrap(self, t, x, y, 5 + self:getTalentLevel(self.T_TRAP_MASTERY), {
			type = "elemental", name = "flash bang trap", color=colors.YELLOW, image = "trap/trap_flashbang.png",
			dur = t.getDuration(self, t),
			check_hit = self:combatAttack(),
			lure_trigger = true,
			stamina = t.stamina,
			dam = dam,
			triggered = function(self, x, y, who)
				self:project({type="ball", x=x,y=y, radius=2}, x, y, function(px, py)
					local who = game.level.map(px, py, engine.Map.ACTOR)
					if who == self.summoner then return end
					if who and who:canBe("blind") then
						who:setEffect(who.EFF_BLINDED, self.dur, {apply_power=self.check_hit})
					elseif who and who:canBe("stun") then
						who:setEffect(who.EFF_DAZED, self.dur, {apply_power=self.check_hit})
					elseif who then
						game.logSeen(who, "%s resists the flash bang!", who.name:capitalize())
					end
					engine.DamageType:get(engine.DamageType.PHYSICAL).projector(self.summoner, px, py, engine.DamageType.PHYSICAL, self.dam)
				end)
				game.level.map:particleEmitter(x, y, 2, "sunburst", {radius=2, tx=x, ty=y})
				return true, true
			end,
		})
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Lay a trap that explodes in a radius of 2, dealing %0.2f physical damage and blinding or dazing anything caught inside for %d turns.
		High level lure can trigger this trap, and this trap can be used with Preparation.]]):
		format(damDesc(self, DamageType.PHYSICAL, t.getDamage(self, t)), t.getDuration(self, t))
	end,
}

newTalent{
	name = "Bladestorm Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 15,
	stamina = 20,
	requires_target = true,
	range = trap_range,
	tactical = { DISABLE = { pin = 2 } },
	no_break_stealth = trap_stealth,
	no_unlearn_last = true,
	getDuration = function(self, t) return 2 + self:getTalentLevel(self.T_TRAP_MASTERY) end,
	speed = "combat",
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end
		local dur = t.getDuration(self,t)
		local Trap = require "mod.class.Trap"
		local t = basetrap(self, t, x, y, 8 + self:getTalentLevel(self.T_TRAP_MASTERY), {
			type = "physical", name = "bladestorm trap", color=colors.BLACK, image = "trap/trap_bladestorm_01.png",
			dur = dur,
			triggered = function(self, x, y, who)
				local tx, ty = util.findFreeGrid(x, y, 10, true, {[engine.Map.ACTOR]=true})
				if not tx or not ty then return nil end
				local m = summon_bladestorm(self.summoner, who, self.dur, tx, ty)
				
				return true, true
			end,
		})
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Lay a trap that activates a whirling pillar of blades lasting %d turns. The pillar automatically attacks all adjacent targets, and is very durable.]]):
		format(t.getDuration(self,t)) --I5
	end,
}

newTalent{
	name = "Beam Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 15,
	stamina = 24,
	requires_target = true,
	tactical = { ATTACK = { ARCANE = 2 } },
	requires_target = true,
	range = trap_range,
	no_break_stealth = trap_stealth,
	no_unlearn_last = true,
	target = function(self, t) return {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t} end,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(self.T_TRAP_MASTERY), 3, 6)) end,
	getDamage = function(self, t) return (15 + self:combatStatScale("cun", 10, 60) * self:callTalent(self.T_TRAP_MASTERY,"getTrapMastery") / 20)/3 end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end
		if game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move") then game.logPlayer(self, "You somehow fail to set the trap.") return nil end
		local dam = self:physicalCrit(t.getDamage(self, t))

		local t = basetrap(self, t, x, y, t.getDuration(self,t), {
			type = "physical", name = "beam trap", color=colors.BLUE, image = "trap/trap_beam.png",
			dam = dam,
			proj_speed = 2,
			triggered = function(self, x, y, who) return true, true end,
			energy = {value=0, mod=1},
			disarmed = function(self, x, y, who)
				game.level:removeEntity(self, true)
			end,
			realact = function(self)
				
                local tgts = {}
                local grids = core.fov.circle_grids(self.x, self.y, 5, true)
                for x, yy in pairs(grids) do for y, _ in pairs(grids[x]) do
                local a = game.level.map(x, y, engine.Map.ACTOR)
                if a and self:reactionToward(a) < 0 then
                   tgts[#tgts+1] = a
                end
                end end
				
				if #tgts <= 0 then return end
				local a, id = rng.table(tgts)
				table.remove(tgts, id)
				self.summoner:project({type="beam", x=self.x, y=self.y}, a.x, a.y, DamageType.ARCANE, self.dam, nil)
				game.level.map:particleEmitter(self.x, self.y, math.max(math.abs(a.x-self.x), math.abs(a.y-self.y)), "mana_beam", {tx=a.x-self.x, ty=a.y-self.y})

				
			end
		})
	  
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		local dam = t.getDamage(self, t)
		local dur = t.getDuration(self,t)
		return ([[Lay a magical trap that fires beams of arcane energy at random targets in radius 5, inflicting %0.2f arcane damage each turn. This trap activates immediately on being placed, and lasts %d turns.]]):
		format(damDesc(self, DamageType.ARCANE, dam), dur)
	end,
}

newTalent{
	name = "Poison Gas Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 10,
	stamina = 12,
	tactical = { ATTACKAREA = { poison = 2 } },
	requires_target = true,
	range = trap_range,
	no_break_stealth = trap_stealth,
	no_unlearn_last = true,
	getDamage = function(self, t) return 20 + self:combatStatScale("cun", 5, 50) * self:callTalent(self.T_TRAP_MASTERY,"getTrapMastery")/20 end,
	getPower = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(self.T_TRAP_MASTERY), 10, 20)) end,
	speed = "combat",
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end

		local dam = self:physicalCrit(t.getDamage(self, t))
		local power = t.getPower(self,t)
		-- Need to pass the actor in to the triggered function for the apply_power to work correctly
		local t = basetrap(self, t, x, y, 8 + self:getTalentLevel(self.T_TRAP_MASTERY), {
			type = "nature", name = "poison gas trap", color=colors.LIGHT_RED, image = "trap/trap_poison_gas.png",
			dam = dam,
			power = power,
			check_hit = self:combatAttack(),
			stamina = t.stamina,
			lure_trigger = true,
			triggered = function(self, x, y, who)
				-- Add a lasting map effect
				game.level.map:addEffect(self,
					x, y, 4,
					engine.DamageType.RANDOM_POISON, {dam=self.dam, power=self.power, apply_power=self.check_hit},
					3,
					5, nil,
					{type="vapour"},
					nil, true
				)
				game:playSoundNear(self, "talents/cloud")
				return true, true
			end,
		})
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Lay a trap that explodes in a radius of 3, releasing a thick poisonous cloud lasting 4 turns.
		Each turn, the cloud infects all creatures with a poison that deals %0.2f nature damage over 5 turns, with a 25%% chance to inflict crippling, numbing or insidious poison instead.
		High level lure can trigger this trap, and this trap can be used with Preparation.]]):
		format(damDesc(self, DamageType.POISON, t.getDamage(self, t)))
	end,
}

newTalent{
	name = "Dragonsfire Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 10,
	stamina = 12,
	tactical = { ATTACKAREA = { fire = 2 } },
	requires_target = true,
	range = trap_range,
	no_break_stealth = trap_stealth,
	no_unlearn_last = true,
	getDamage = function(self, t) return 20 + self:combatStatScale("cun", 5, 50) * self:callTalent(self.T_TRAP_MASTERY,"getTrapMastery")/40 end,
	speed = "combat",
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end

		local dam = self:physicalCrit(t.getDamage(self, t))
		-- Need to pass the actor in to the triggered function for the apply_power to work correctly
		local t = basetrap(self, t, x, y, 8 + self:getTalentLevel(self.T_TRAP_MASTERY), {
			type = "fire", name = "dragonsfire trap", color=colors.RED, image = "trap/trap_dragonsfire.png",
			dam = dam,
			power = power,
			check_hit = self:combatAttack(),
			stamina = t.stamina,
			lure_trigger = true,
			triggered = function(self, x, y, who)
				self:project({type="ball", x=x,y=y, radius=2}, x, y, function(px, py)
					local who = game.level.map(px, py, engine.Map.ACTOR)
					if who == self.summoner then return end
					if who and who:canBe("stun") then
						who:setEffect(who.EFF_BURNING_SHOCK, 3, {src=self, power=self.dam/3, apply_power=self.check_hit})
					elseif who then
						who:setEffect(who.EFF_BURNING, 3, {src=self, power=self.dam/3})					
					end
				end)
				-- Add a lasting map effect
				game.level.map:addEffect(self,
					x, y, 5,
					engine.DamageType.FIRE, self.dam/2,
					2,
					5, nil,
					{type="inferno"},
					nil, false, false
				)
				game.level.map:particleEmitter(x, y, 2, "fireflash", {radius=2, proj_x=x, proj_y=y, src_x=self.x, src_y=self.y})
				game:playSoundNear(self, "talents/devouringflame")
				return true, true
			end,
		})
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Lay a trap that explodes into a radius 2 cloud of searing flames on contact, dealing %0.2f fire damage and stunning for 3 turns, as well as leaving behind a cloud of flames for 5 turns that inflicts %0.2f fire damage each turn.
		High level lure can trigger this trap, and this trap can be used with Preparation.]]):
		format(damDesc(self, DamageType.FIRE, t.getDamage(self, t)), damDesc(self, DamageType.FIRE, t.getDamage(self, t)/2))
	end,
}

newTalent{
	name = "Freezing Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 10,
	stamina = 12,
	tactical = { ATTACKAREA = { cold = 2 } },
	requires_target = true,
	range = trap_range,
	no_break_stealth = trap_stealth,
	no_unlearn_last = true,
	getDamage = function(self, t) return 20 + self:combatStatScale("cun", 5, 50) * self:callTalent(self.T_TRAP_MASTERY,"getTrapMastery")/40 end,
	speed = "combat",
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end

		local dam = self:physicalCrit(t.getDamage(self, t))
		-- Need to pass the actor in to the triggered function for the apply_power to work correctly
		local t = basetrap(self, t, x, y, 8 + self:getTalentLevel(self.T_TRAP_MASTERY), {
			type = "cold", name = "freezing trap", color=colors.BLUE, image = "trap/trap_freezing.png",
			dam = dam,
			power = power,
			check_hit = self:combatAttack(),
			stamina = t.stamina,
			lure_trigger = true,
			triggered = function(self, x, y, who)
				self:project({type="ball", x=x,y=y, radius=2}, x, y, function(px, py)
					local who = game.level.map(px, py, engine.Map.ACTOR)
					if who == self.summoner then return end
					if who and who:canBe("pin") then
						who:setEffect(who.EFF_FROZEN_FEET, 3, {apply_power=self.check_hit})
					end
					engine.DamageType:get(engine.DamageType.COLD).projector(self.summoner, px, py, engine.DamageType.COLD, self.dam)
				end)
				game.level.map:particleEmitter(x, y, 2, "circle", {oversize=1.1, a=255, limit_life=16, grow=true, speed=0, img="ice_nova", radius=2})
				-- Add a lasting map effect
				game.level.map:addEffect(self,
					x, y, 5,
					engine.DamageType.ICE, self.dam/2,
					2,
					5, nil,
					{type="ice_vapour"},
					nil, false, false
				)
				game:playSoundNear(self, "talents/cloud")
				return true, true
			end,
		})
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Lay a trap that explodes into a radius 2 cloud of freezing vapour on contact, dealing %0.2f cold damage, pinning for 3 turns and leaving behind a cloud of cold for 5 turns that inflicts %0.2f cold damage each turn with a 25%% chance to freeze.
		High level lure can trigger this trap, and this trap can be used with Preparation.]]):
		format(damDesc(self, DamageType.COLD, t.getDamage(self, t)), damDesc(self, DamageType.COLD, t.getDamage(self, t)/2))
	end,
}

newTalent{
	name = "Gravitic Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 15,
	stamina = 12,
	tactical = { ATTACKAREA = { temporal = 2 } },
	requires_target = true,
	is_spell = true,
	range = trap_range,
	no_break_stealth = trap_stealth,
	no_unlearn_last = true,
	getDamage = function(self, t) return 20 + self:combatStatScale("cun", 5, 50) * self:callTalent(self.T_TRAP_MASTERY,"getTrapMastery") / 40 end,
	getDuration = function(self,t) return 1 + math.floor(self:getTalentLevel(self.T_TRAP_MASTERY)) end,
	speed = "combat",
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end
		if game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move") then game.logPlayer(self, "You somehow fail to set the trap.") return nil end

		local dam = t.getDamage(self, t)
		-- Need to pass the actor in to the triggered function for the apply_power to work correctly
		local t = basetrap(self, t, x, y, t.getDuration(self,t), {
			type = "arcane", name = "gravitic trap", color=colors.LIGHT_RED, image = "invis.png",
			embed_particles = {{name="wormhole", rad=5, args={image="shockbolt/trap/trap_gravitic", speed=1}}},
			dam = dam,
			stamina = t.stamina,
			check_hit = self:combatAttack(),
			triggered = function(self, x, y, who)
				return true, true
			end,
			realact = function(self)
				local tgts = {}
				self:project({type="ball", range=0, friendlyfire=false, radius=5}, self.x, self.y, function(px, py)
					local target = game.level.map(px, py, engine.Map.ACTOR)
					if not target then return end
					if self:reactionToward(target) < 0 and not tgts[target] then
						tgts[target] = true
						local ox, oy = target.x, target.y
						engine.DamageType:get(engine.DamageType.TEMPORAL).projector(self.summoner, target.x, target.y, engine.DamageType.TEMPORAL, self.dam)
						if target:canBe("knockback") then
							target:pull(self.x, self.y, 1)
							if target.x ~= ox or target.y ~= oy then
								self.summoner:logCombat(target, "#Target# is pulled towards #Source#'s gravity trap!")
							end
						end
					end
				end)
				game.level.map:particleEmitter(self.x, self.y, 5, "gravity_spike", {radius=5, allow=core.shader.allow("distort")})
			end,
		})
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Lay a trap that creates a gravitic anomaly for %d turns, pulling in all foes around it in a radius of 5.
		All foes caught inside take %0.2f temporal damage per turn.]]):
		format(t.getDuration(self,t), damDesc(self, engine.DamageType.TEMPORAL, t.getDamage(self, t)))
	end,
}

newTalent{
	name = "Ambush Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 15,
	stamina = 20,
	requires_target = true,
	range = trap_range,
	is_spell = true,
	tactical = { DISABLE = { pin = 2 } },
	no_break_stealth = trap_stealth,
	no_unlearn_last = true,
	getDuration = function(self, t) return 2 + self:getTalentLevel(self.T_TRAP_MASTERY) end,
	speed = "combat",
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end
		local dur = t.getDuration(self,t)
		local Trap = require "mod.class.Trap"
		local t = basetrap(self, t, x, y, 8 + self:getTalentLevel(self.T_TRAP_MASTERY), {
			type = "darkness", name = "ambush trap", color=colors.BLACK, image = "trap/trap_ambush.png",
			dur = dur,
			triggered = function(self, x, y, who)
				for i = 1, 3 do
					local tx, ty = util.findFreeGrid(x, y, 10, true, {[engine.Map.ACTOR]=true})
					if not tx or not ty then return nil end
					local m = summon_assassin(self.summoner, who, self.dur, tx, ty)
				end
				
				return true, true
			end,
		})
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Lay a magical trap that summons a trio of shadowy rogues for %d turns that attack the target.]]):
		format(t.getDuration(self,t)) --I5
	end,
}

newTalent{
	name = "Purging Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 15,
	stamina = 20,
	tactical = { ATTACK = { ARCANE = 3 } },
	requires_target = true,
	range = trap_range,
	no_break_stealth = trap_stealth,
	no_unlearn_last = true,
	getNb = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(self.T_TRAP_MASTERY), 2, 4)) end,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(self.T_TRAP_MASTERY), 2.5, 4.5)) end,
	getDamage = function(self, t) return 25 + self:combatStatScale("cun", 10, 95) * self:callTalent(self.T_TRAP_MASTERY,"getTrapMastery") / 20 end,
	speed = "combat",
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end

		local Trap = require "mod.class.Trap"
		local dam = self:physicalCrit(t.getDamage(self, t))
		local dur = t.getDuration(self,t)
		local nb = t.getNb(self,t)
		local t = basetrap(self, t, x, y, 5 + self:getTalentLevel(self.T_TRAP_MASTERY), {
			type = "nature", name = "purging trap", color=colors.YELLOW, image = "trap/trap_purging.png",
			check_hit = self:combatAttack(),
			lure_trigger = true,
			stamina = t.stamina,
			dam = dam,
			dur = dur,
			nb = nb,
			triggered = function(self, x, y, who)
				self:project({type="ball", x=x,y=y, radius=2}, x, y, function(px, py)
					local who = game.level.map(px, py, engine.Map.ACTOR)
					if who == self.summoner then return end
					if who then
						who:setEffect(who.EFF_SILENCED, self.dur, {apply_power=self.check_hit})
						
						local effs = {}

						-- Go through all spell effects
						for eff_id, p in pairs(who.tmp) do
							local e = who.tempeffect_def[eff_id]
							if e.type == "magical" and e.status == "beneficial" then
								effs[#effs+1] = {"effect", eff_id}
							end
						end
				
						-- Go through all sustained spells
						for tid, act in pairs(who.sustain_talents) do
							if act then
								local talent = who:getTalentFromId(tid)
								if talent.is_spell then effs[#effs+1] = {"talent", tid} end
							end
						end

				
						for i = 1, self.nb do
							if #effs == 0 then break end
							local eff = rng.tableRemove(effs)
				
							if eff[1] == "effect" then
								who:removeEffect(eff[2])
							else
								who:forceUseTalent(eff[2], {ignore_energy=true})
							end
						end

						
					end
					engine.DamageType:get(engine.DamageType.MANABURN).projector(self.summoner, px, py, engine.DamageType.MANABURN, self.dam)
				end)
				game.level.map:particleEmitter(x, y, 2, "acidflash", {radius=2, tx=x, ty=y})
				return true, true
			end,
		})
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		local base = t.getDamage(self,t)
		local mana = base
		local vim = base / 2
		local positive = base / 4
		local negative = base / 4
		local dur = t.getDuration(self,t)
		local nb = t.getNb(self,t)
		return ([[Lay a trap that detonates in a radius 2 burst of antimagic, draining %d mana, %d vim, %d positive and %d negative energies from affected targets, dealing up to %0.2f arcane damage based on the resources drained, silencing for %d turns as well as removing up to %d beneficial magical effects or sustains.
		High level lure can trigger this trap, and this trap can be used with Preparation.]]):
		format(mana, vim, positive, negative, damDesc(self, DamageType.ARCANE, base), dur, nb)
	end,
}

newTalent{
	name = "Explosion Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 8,
	stamina = 15,
	requires_target = true,
	range = trap_range,
	no_break_stealth = trap_stealth,
	tactical = { ATTACKAREA = { FIRE = 2 } },
	no_unlearn_last = true,
	speed = "combat",
	getDamage = function(self, t) return 30 + self:combatStatScale("cun", 8, 80) * self:callTalent(self.T_TRAP_MASTERY, "getTrapMastery")/20 end,
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end

		local dam = t.getDamage(self, t)
		local t = basetrap(self, t, x, y, 8 + self:getTalentLevel(self.T_TRAP_MASTERY), {
			type = "elemental", name = "explosion trap", color=colors.LIGHT_RED, image = "trap/blast_fire01.png",
			dam = dam,
			stamina = t.stamina,
			lure_trigger = true,
			triggered = function(self, x, y, who)
				self:project({type="ball", x=x,y=y, radius=2}, x, y, engine.DamageType.FIREBURN, self.dam)
				game.level.map:particleEmitter(x, y, 2, "fireflash", {radius=2, tx=x, ty=y})
				return true, true
			end,
		})
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Lay a simple yet effective trap that explodes on contact, doing %0.2f fire damage over a few turns in a radius of 2.
		High level lure can trigger this trap.]]):
		format(damDesc(self, DamageType.FIRE, t.getDamage(self, t)))
	end,
}

newTalent{
	name = "Catapult Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 10,
	stamina = 15,
	requires_target = true,
	tactical = { DISABLE = { stun = 2 } },
	range = trap_range,
	no_break_stealth = trap_stealth,
	no_unlearn_last = true,
	getDistance = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(self.T_TRAP_MASTERY), 3, 7)) end,
	speed = "combat",
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end


		local Trap = require "mod.class.Trap"
		local t = basetrap(self, t, x, y, 8 + self:getTalentLevel(self.T_TRAP_MASTERY), {
			type = "physical", name = "catapult trap", color=colors.LIGHT_UMBER, image = "trap/trap_catapult_01_64.png",
			dist = t.getDistance(self, t),
			check_hit = self:combatAttack(),
			stamina = t.stamina,
			triggered = function(self, x, y, who)
				-- Try to knockback !
				local can = function(target)
					if target:checkHit(self.check_hit, target:combatPhysicalResist(), 0, 95, 15) and target:canBe("knockback") then
						return true
					else
						game.logSeen(target, "%s resists the knockback!", target.name:capitalize())
					end
				end

				if can(who) then
					who:knockback(self.summoner.x, self.summoner.y, self.dist, can)
					if who:canBe("stun") then who:setEffect(who.EFF_DAZED, 5, {}) end
				end
				return true, rng.chance(25)
			end,
		})
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Lay a catapult trap that knocks back any creature that steps over it up to %d grids away, dazing them.]]):
		format(t.getDistance(self, t))
	end,
}

newTalent{
	name = "Disarming Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 25,
	stamina = 25,
	requires_target = true,
	tactical = { DISABLE = { disarm = 2 } },
	range = trap_range,
	no_break_stealth = trap_stealth,
	no_unlearn_last = true,
	getDamage = function(self, t) return 60 + self:combatStatScale("cun", 9, 90) * self:callTalent(self.T_TRAP_MASTERY,"getTrapMastery")/20 end,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(self.T_TRAP_MASTERY), 2.1, 4.43)) end,
	speed = "combat",
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end

		local Trap = require "mod.class.Trap"
		local dam = t.getDamage(self, t)
		local t = basetrap(self, t, x, y, 8 + self:getTalentLevel(self.T_TRAP_MASTERY), {
			type = "physical", name = "disarming trap", color=colors.DARK_GREY, image = "trap/trap_magical_disarm_01_64.png",
			dur = t.getDuration(self, t),
			check_hit = self:combatAttack(),
			dam = dam,
			stamina = t.stamina,
			triggered = function(self, x, y, who)
				self:project({type="hit", x=x,y=y}, x, y, engine.DamageType.ACID, self.dam, {type="acid"})
				if who:canBe("disarm") then
					who:setEffect(who.EFF_DISARMED, self.dur, {apply_power=self.check_hit})
				else
					game.logSeen(who, "%s resists!", who.name:capitalize())
				end
				return true, true
			end,
		})
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Lay a tricky trap that maims the arms of creatures passing by with acid doing %0.2f damage and disarming them for %d turns.]]):
		format(damDesc(self, DamageType.ACID, t.getDamage(self, t)), t.getDuration(self, t))
	end,
}

newTalent{
	name = "Nightshade Trap",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 8,
	stamina = 15,
	tactical = { DISABLE = { stun = 2 } },
	requires_target = true,
	range = trap_range,
	no_break_stealth = trap_stealth,
	no_unlearn_last = true,
	getDamage = function(self, t) return 20 + self:combatStatScale("cun", 10, 100) * self:callTalent(self.T_TRAP_MASTERY,"getTrapMastery")/20 end,
	speed = "combat",
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, simple_dir_request=true, talent=t}
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if game.level.map(x, y, Map.TRAP) then game.logPlayer(self, "You somehow fail to set the trap.") return nil end

		local dam = t.getDamage(self, t)
		local Trap = require "mod.class.Trap"
		local t = basetrap(self, t, x, y, 5 + self:getTalentLevel(self.T_TRAP_MASTERY), {
			type = "nature", name = "nightshade trap", color=colors.LIGHT_BLUE, image = "trap/poison_vines01.png",
			dam = dam,
			stamina = t.stamina,
			check_hit = self:combatAttack(),
			triggered = function(self, x, y, who)
				self:project({type="hit", x=x,y=y}, x, y, engine.DamageType.NATURE, self.dam, {type="slime"})
				if who:canBe("stun") then
					who:setEffect(who.EFF_STUNNED, 4, {src=self.summoner, apply_power=self.check_hit})
				end
				return true, true
			end,
		})
		t:identify(true)

		t:resolve() t:resolve(nil, true)
		t:setKnown(self, true)
		game.level:addEntity(t)
		game.zone:addEntity(game.level, t, "trap", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Lay a trap coated with a potent venom, doing %0.2f nature damage to a creature passing by and stunning it for 4 turns.]]):
		format(damDesc(self, DamageType.NATURE, t.getDamage(self, t)))
	end,
}

newTalent{
	name = "Springrazor Trap", short_name = "SPRINGRAZOR_PREP", image = "talents/springrazor_trap.png",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 8,
	stamina = 15,
	requires_target = true,
	range = trap_range,
	tactical = { ATTACKAREA = { PHYSICAL = 2 } },
	no_unlearn_last = true,
	speed = "combat",
	getDamage = function(self, t) return 30 + self:combatStatScale("cun", 10, 90) * self:callTalent(self.T_PREPARATION, "getTrapMastery")/20 end,
	getPower = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(self.T_PREPARATION), 10, 25)) end,
	radius = function(self, t) return 2 end,
	target = function(self, t) return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), friendlyfire=false} end,
	requires_target = true,
	action = function(self, t)
		local tg = {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), friendlyfire=false}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local dam = self:physicalCrit(t.getDamage(self, t)/1.5)
		local power = t.getPower(self,t)
		local grids, px, py = self:project(tg, x, y, function(px, py)
			local target = game.level.map(px, py, Map.ACTOR)
			if target and self:reactionToward(target) < 0 then
				target:setEffect(target.EFF_RAZORWIRE, 3, {power=self.power, apply_power=self:combatAttack()})
				engine.DamageType:get(engine.DamageType.PHYSICALBLEED).projector(self, px, py, engine.DamageType.PHYSICALBLEED, dam)
			end
		end, 0)

		game.level.map:particleEmitter(px, py, 2, "meleestorm", {radius=2, tx=px, ty=py})
		return true
	end,
	info = function(self, t)
		local dam = t.getDamage(self, t)/1.5
		local power = t.getPower(self,t)
		return ([[Throw a device that explodes into a radius 2 wave of razor sharp wire, doing %0.2f physical damage and a further %0.2f physical damage over 5 turns. Those struck by the wire have their equipment shredded, reducing accuracy, armor and defence by %d.]]):
		format(damDesc(self, DamageType.PHYSICAL, dam), damDesc(self, DamageType.PHYSICAL, dam/2), power)
	end,
}

newTalent{
	name = "Flashbang Trap", short_name = "FLASH_BANG_PREP", image = "talents/flash_bang_trap.png",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 12,
	stamina = 12,
	requires_target = true,
	range = trap_range,
	tactical = { ATTACKAREA = { PHYSICAL = 2 } },
	no_unlearn_last = true,
	speed = "combat",
	getDuration = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(self.T_PREPARATION), 2.5, 4.5)) end,
	getDamage = function(self, t) return 25 + self:combatStatScale("cun", 10, 80) * self:callTalent(self.T_PREPARATION,"getTrapMastery") / 20 end,
	radius = function(self, t) return 2 end,
	target = function(self, t) return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), friendlyfire=false} end,
	requires_target = true,
	action = function(self, t)
		local tg = {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), friendlyfire=false}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local dam = self:physicalCrit(t.getDamage(self, t))
		local dur = t.getDuration(self,t)
		local grids, px, py = self:project(tg, x, y, function(px, py)
			local target = game.level.map(px, py, Map.ACTOR)
			if target and self:reactionToward(target) < 0 then
				if target and target:canBe("blind") then
					target:setEffect(target.EFF_BLINDED, dur, {apply_power=self:combatAttack()})
				elseif target and target:canBe("stun") then
					target:setEffect(target.EFF_DAZED, dur, {apply_power=self:combatAttack()})
				elseif target then
					game.logSeen(target, "%s resists the flash bang!", target.name:capitalize())
				end				
				engine.DamageType:get(engine.DamageType.PHYSICAL).projector(self, px, py, engine.DamageType.PHYSICAL, dam)
			end
		end, 0)

		game.level.map:particleEmitter(px, py, 2, "sunburst", {radius=2, tx=px, ty=py})
		return true
	end,
	info = function(self, t)
		return ([[Throw a device that explodes in a radius of 2, dealing %0.2f physical damage and blinding or dazing anything caught inside for %d turns.]]):
		format(damDesc(self, DamageType.PHYSICAL, t.getDamage(self, t)), t.getDuration(self, t))
	end,
}

newTalent{
	name = "Poison Gas Trap", short_name = "POISON_GAS_PREP", image = "talents/poison_gas_trap.png",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 10,
	stamina = 12,
	requires_target = true,
	range = trap_range,
	tactical = { ATTACKAREA = { poison = 2 } },
	no_unlearn_last = true,
	speed = "combat",
	getDamage = function(self, t) return 20 + self:combatStatScale("cun", 5, 50) * self:callTalent(self.T_PREPARATION,"getTrapMastery")/20 end,
	getPower = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(self.T_PREPARATION), 10, 20)) end,
	radius = function(self, t) return 3 end,
	target = function(self, t) return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), friendlyfire=false} end,
	requires_target = true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, _, _, x, y = self:canProject(tg, x, y)
		local dam = self:physicalCrit(t.getDamage(self, t))
		local power = t.getPower(self,t)

		-- Add a lasting map effect
		game.level.map:addEffect(self,
			x, y, 4,
			engine.DamageType.RANDOM_POISON, {dam=dam, power=power, apply_power=self:combatAttack()},
			3,
			5, nil,
			{type="vapour"},
			nil, true
		)
		game:playSoundNear(self, "talents/cloud")
		return true
	end,
	info = function(self, t)
		return ([[Throw a device that explodes in a radius of 3, releasing a thick poisonous cloud lasting 4 turns.
		Each turn, the cloud infects all creatures with a poison that deals %0.2f nature damage over 5 turns, with a 25%% chance to inflict crippling, numbing or insidious poison instead.]]):
		format(damDesc(self, DamageType.POISON, t.getDamage(self, t)))
	end,
}

newTalent{
	name = "Purging Trap", short_name = "PURGING_PREP", image = "talents/purging_trap.png",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 15,
	stamina = 20,
	requires_target = true,
	range = trap_range,
	tactical = { ATTACKAREA = { ARCANE = 2 } },
	no_unlearn_last = true,
	speed = "combat",
	getDuration = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(self.T_PREPARATION), 2.5, 4.5)) end,
	getNb = function(self, t) return math.floor(self:combatTalentScale(self:getTalentLevel(self.T_PREPARATION), 2, 4)) end,
	getDamage = function(self, t) return 25 + self:combatStatScale("cun", 10, 95) * self:callTalent(self.T_PREPARATION,"getTrapMastery") / 20 end,
	radius = function(self, t) return 2 end,
	target = function(self, t) return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), friendlyfire=false} end,
	requires_target = true,
	action = function(self, t)
		local tg = {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), friendlyfire=false}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local dam = self:physicalCrit(t.getDamage(self, t))
		local dur = t.getDuration(self,t)
		local nb = t.getNb(self,t)
		local grids, px, py = self:project(tg, x, y, function(px, py)
			local target = game.level.map(px, py, Map.ACTOR)
			if target and self:reactionToward(target) < 0 then
				
				local effs = {}

				-- Go through all spell effects
				for eff_id, p in pairs(target.tmp) do
					local e = target.tempeffect_def[eff_id]
					if e.type == "magical" and e.status == "beneficial" then
						effs[#effs+1] = {"effect", eff_id}
					end
				end
				
				-- Go through all sustained spells
				for tid, act in pairs(target.sustain_talents) do
					if act then
						local talent = target:getTalentFromId(tid)
						if talent.is_spell then effs[#effs+1] = {"talent", tid} end
					end
				end

				
				for i = 1, nb do
					if #effs == 0 then break end
					local eff = rng.tableRemove(effs)
				
					if eff[1] == "effect" then
						target:removeEffect(eff[2])
					else
						target:forceUseTalent(eff[2], {ignore_energy=true})
					end
				end
	
				if target and target:canBe("silence") then
					target:setEffect(target.EFF_SILENCED, dur, {apply_power=self:combatAttack()})
				elseif target then
					game.logSeen(target, "%s resists the purging trap!", target.name:capitalize())
				end				
				engine.DamageType:get(engine.DamageType.MANABURN).projector(self, px, py, engine.DamageType.MANABURN, dam)
			end
		end, 0)

		game.level.map:particleEmitter(px, py, 2, "acidflash", {radius=2, tx=px, ty=py})
		return true
	end,
	info = function(self, t)
		local base = t.getDamage(self,t)
		local mana = base
		local vim = base / 2
		local positive = base / 4
		local negative = base / 4
		local dur = t.getDuration(self,t)
		local nb = t.getNb(self,t)
		return ([[Throw a device that detonates in a radius 2 burst of antimagic, draining %d mana, %d vim, %d positive and %d negative energies from affected targets, dealing up to %0.2f arcane damage based on the resources drained, silencing for %d turns as well as removing up to %d beneficial magical effects or sustains.]]):
		format(mana, vim, positive, negative, damDesc(self, DamageType.ARCANE, base), dur, nb)
	end,
}

newTalent{
	name = "Dragonsfire Trap", short_name = "DRAGONSFIRE_PREP", image = "talents/dragonsfire_trap.png",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 10,
	stamina = 12,
	requires_target = true,
	range = trap_range,
	tactical = { ATTACKAREA = { fire = 2 } },
	no_unlearn_last = true,
	speed = "combat",
	getDamage = function(self, t) return 20 + self:combatStatScale("cun", 5, 50) * self:callTalent(self.T_TRAP_MASTERY,"getTrapMastery")/40 end,
	radius = function(self, t) return 2 end,
	target = function(self, t) return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), friendlyfire=false} end,
	requires_target = true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, _, _, x, y = self:canProject(tg, x, y)
		local dam = self:physicalCrit(t.getDamage(self, t))

		local grids, px, py = self:project(tg, x, y, function(px, py)
			local target = game.level.map(px, py, Map.ACTOR)
			if target and self:reactionToward(target) < 0 then
				if target:canBe("stun") then
					target:setEffect(target.EFF_BURNING_SHOCK, 3, {src=self, power=dam/3, apply_power=self:combatAttack()})
				else
					target:setEffect(target.EFF_BURNING, 3, {src=self, power=dam/3})
				end
			end
		end, 0)

		-- Add a lasting map effect
		game.level.map:addEffect(self,
			x, y, 5,
			engine.DamageType.FIRE, dam/2,
			2,
			5, nil,
			{type="inferno"},
			nil, false, false
		)
		
		game.level.map:particleEmitter(x, y, 2, "fireflash", {radius=2, proj_x=x, proj_y=y, src_x=self.x, src_y=self.y})
		game:playSoundNear(self, "talents/devouringflame")
		return true
	end,
	info = function(self, t)
		return ([[Throw a device that explodes into a radius 2 cloud of searing flames on contact, dealing %0.2f fire damage and stunning for 3 turns, as well as leaving behind a cloud of flames for 5 turns that inflicts %0.2f fire damage each turn.]]):
		format(damDesc(self, DamageType.FIRE, t.getDamage(self, t)), damDesc(self, DamageType.FIRE, t.getDamage(self, t)/2))
	end,
}

newTalent{
	name = "Freezing Trap", short_name = "FREEZING_PREP", image = "talents/dragonsfrost_trap.png",
	type = {"cunning/traps", 1},
	points = 1,
	cooldown = 10,
	stamina = 12,
	requires_target = true,
	range = trap_range,
	tactical = { ATTACKAREA = { cold = 2 } },
	no_unlearn_last = true,
	speed = "combat",
	getDamage = function(self, t) return 20 + self:combatStatScale("cun", 5, 50) * self:callTalent(self.T_TRAP_MASTERY,"getTrapMastery")/40 end,
	radius = function(self, t) return 2 end,
	target = function(self, t) return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), friendlyfire=false} end,
	requires_target = true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, _, _, x, y = self:canProject(tg, x, y)
		local dam = self:physicalCrit(t.getDamage(self, t))

		local grids, px, py = self:project(tg, x, y, function(px, py)
			local target = game.level.map(px, py, Map.ACTOR)
			if target and self:reactionToward(target) < 0 then
				if target:canBe("pin") then
					target:setEffect(target.EFF_FROZEN_FEET, 3, {src=self, apply_power=self:combatAttack()})
				end
				engine.DamageType:get(engine.DamageType.COLD).projector(self, px, py, engine.DamageType.COLD, dam)
			end
		end, 0)

		-- Add a lasting map effect
		game.level.map:addEffect(self,
			x, y, 5,
			engine.DamageType.ICE, dam/2,
			2,
			5, nil,
			{type="ice_vapour"},
			nil, false, false
		)
		
		game.level.map:particleEmitter(x, y, 2, "circle", {oversize=1.1, a=255, limit_life=16, grow=true, speed=0, img="ice_nova", radius=2})
		game:playSoundNear(self, "talents/cloud")
		return true
	end,
	info = function(self, t)
		return ([[Throw a device that explodes into a radius 2 cloud of freezing vapour on contact, dealing %0.2f cold damage, pinning for 3 turns and leaving behind a cloud of cold for 5 turns that inflicts %0.2f cold damage each turn with a 25%% chance to freeze.]]):
		format(damDesc(self, DamageType.COLD, t.getDamage(self, t)), damDesc(self, DamageType.COLD, t.getDamage(self, t)/2))
	end,
}