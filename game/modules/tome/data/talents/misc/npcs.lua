-- ToME - Tales of Middle-Earth
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

-- race & classes
newTalentType{ type="technique/other", name = "other", hide = true, description = "Talents of the various entities of the world." }
newTalentType{ type="spell/other", name = "other", hide = true, description = "Talents of the various entities of the world." }
newTalentType{ type="wild-gift/other", name = "other", hide = true, description = "Talents of the various entities of the world." }
newTalentType{ type="other/other", name = "other", hide = true, description = "Talents of the various entities of the world." }

-- Multiply!!!
newTalent{
	name = "Multiply",
	type = {"other/other", 1},
	cooldown = 3,
	range = 20,
	action = function(self, t)
		if not self.can_multiply or self.can_multiply <= 0 then print("no more multiply")  return nil end

		-- Find space
		local x, y = util.findFreeGrid(self.x, self.y, 1, true, {[Map.ACTOR]=true})
		if not x then print("no free space") return nil end

		-- Find a place around to clone
		self.can_multiply = self.can_multiply - 1
		local a = self:clone()
		a.energy.val = 0
		a.exp_worth = 0.1
		a.inven = {}
		a.x, a.y = nil, nil
		if a.can_multiply <= 0 then a:unlearnTalent(t.id) end

		print("[MULTIPLY]", x, y, "::", game.level.map(x,y,Map.ACTOR))
		print("[MULTIPLY]", a.can_multiply, "uids", self.uid,"=>",a.uid, "::", self.player, a.player)
		game.zone:addEntity(game.level, a, "actor", x, y)
		return true
	end,
	info = function(self)
		return ([[Multiply yourself!]])
	end,
}

newTalent{
	short_name = "CRAWL_POISON",
	name = "Poisonous Crawl",
	type = {"technique/other", 1},
	points = 5,
	message = "@Source@ crawls poison onto @target@.",
	cooldown = 5,
	range = 1,
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if math.floor(core.fov.distance(self.x, self.y, x, y)) > 1 then return nil end
		self.combat_apr = self.combat_apr + 1000
		self:attackTarget(target, DamageType.POISON, 2 + self:getTalentLevel(t), true)
		self.combat_apr = self.combat_apr - 1000
		return true
	end,
	info = function(self)
		return ([[Crawl onto the target, convering it in poison.]])
	end,
}

newTalent{
	short_name = "CRAWL_ACID",
	name = "Acidic Crawl",
	points = 5,
	type = {"technique/other", 1},
	message = "@Source@ crawls acid onto @target@.",
	cooldown = 2,
	range = 1,
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if math.floor(core.fov.distance(self.x, self.y, x, y)) > 1 then return nil end
		self.combat_apr = self.combat_apr + 1000
		self:attackTarget(target, DamageType.ACID, 1 + self:getTalentLevel(t) / 3, true)
		self.combat_apr = self.combat_apr - 1000
		return true
	end,
	info = function(self)
		return ([[Crawl onto the target, convering it in acid.]])
	end,
}

newTalent{
	short_name = "SPORE_BLIND",
	name = "Blinding Spores",
	type = {"technique/other", 1},
	points = 5,
	message = "@Source@ releases blinding spores at @target@.",
	cooldown = 2,
	range = 1,
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if math.floor(core.fov.distance(self.x, self.y, x, y)) > 1 then return nil end
		self.combat_apr = self.combat_apr + 1000
		self:attackTarget(target, DamageType.BLIND, 0.8 + self:getTalentLevel(t) / 10, true)
		self.combat_apr = self.combat_apr - 1000
		return true
	end,
	info = function(self)
		return ([[Releases blinding spores at the target.]])
	end,
}

newTalent{
	short_name = "SPORE_POISON",
	name = "Poisonous Spores",
	type = {"technique/other", 1},
	points = 5,
	message = "@Source@ releases poisonous spores at @target@.",
	cooldown = 2,
	range = 1,
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if math.floor(core.fov.distance(self.x, self.y, x, y)) > 1 then return nil end
		self.combat_apr = self.combat_apr + 1000
		self:attackTarget(target, DamageType.POISON, 2 + self:getTalentLevel(t), true)
		self.combat_apr = self.combat_apr - 1000
		return true
	end,
	info = function(self)
		return ([[Releases poisonous spores at the target.]])
	end,
}

newTalent{
	name = "Stun",
	type = {"technique/other", 1},
	points = 5,
	cooldown = 6,
	stamina = 8,
	require = { stat = { str=12 }, },
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if math.floor(core.fov.distance(self.x, self.y, x, y)) > 1 then return nil end
		local hit = self:attackTarget(target, nil, 0.5 + self:getTalentLevel(t) / 10, true)

		-- Try to stun !
		if hit then
			if target:checkHit(self:combatAttackStr(), target:combatPhysicalResist(), 0, 95, 5 - self:getTalentLevel(t) / 2) and target:canBe("stun") then
				target:setEffect(target.EFF_STUNNED, 2 + self:getTalentLevel(t), {})
			else
				game.logSeen(target, "%s resists the stunning blow!", target.name:capitalize())
			end
		end

		return true
	end,
	info = function(self, t)
		return ([[Hits the target with your weapon doing %d%% damage, if the attack hits, the target is stunned.]]):format(100 * (0.5 + self:getTalentLevel(t) / 10))
	end,
}

newTalent{
	name = "Knockback",
	type = {"technique/other", 1},
	points = 5,
	cooldown = 6,
	stamina = 8,
	require = { stat = { str=12 }, },
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if math.floor(core.fov.distance(self.x, self.y, x, y)) > 1 then return nil end
		local hit = self:attackTarget(target, nil, 1.5 + self:getTalentLevel(t) / 10, true)

		-- Try to knockback !
		if hit then
			if target:checkHit(self:combatAttackStr(), target:combatPhysicalResist(), 0, 95, 5 - self:getTalentLevel(t) / 2) and target:canBe("knockback") then
				target:knockback(4)
			else
				game.logSeen(target, "%s resists the knockback!", target.name:capitalize())
			end
		end

		return true
	end,
	info = function(self, t)
		return ([[Hits the target with your weapon doing %d%% damage, if the attack hits, the target is knocked back.]]):format(100 * (1.5 + self:getTalentLevel(t) / 10))
	end,
}

newTalent{
	short_name = "BITE_POISON",
	name = "Poisonous Bite",
	type = {"technique/other", 1},
	points = 5,
	message = "@Source@ bites poison into @target@.",
	cooldown = 5,
	range = 1,
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if math.floor(core.fov.distance(self.x, self.y, x, y)) > 1 then return nil end
		self:attackTarget(target, DamageType.POISON, 2 + self:getTalentLevel(t), true)
		return true
	end,
	info = function(self)
		return ([[Bites the target, infecting ti with poison.]])
	end,
}

newTalent{
	name = "Summon",
	type = {"other/other", 1},
	cooldown = 4,
	range = 20,
	action = function(self, t)
		local filters = self.summon or {{type=self.type, subtype=self.subtype, number=1, hasxp=true, lastfor=20}}
		if #filters == 0 then return end
		local filter = rng.table(filters)

		for i = 1, filter.number do
			-- Find space
			local x, y = util.findFreeGrid(self.x, self.y, 10, true, {[Map.ACTOR]=true})
			if not x then
				game.logPlayer(self, "Not enough space to summon!")
				break
			end

			-- Find an actor with that filter
			local m = game.zone:makeEntity(game.level, "actor", filter)
			if m then
				if not filter.hasxp then m.exp_worth = 0 end
				m:resolve()

				m.summoner = self
				m.summon_time = filter.lastfor

				game.zone:addEntity(game.level, m, "actor", x, y)

				game.logSeen(self, "%s summons %s!", self.name:capitalize(), m.name)

				-- Learn about summoners
				if game.level.map.seens(self.x, self.y) then
					game:setAllowedBuild("wilder_summoner", true)
				end
			end
		end
		return true
	end,
	info = function(self)
		return ([[Summon allies.]])
	end,
}

newTalent{
	name = "Rotting Disease",
	type = {"technique/other", 1},
	points = 5,
	cooldown = 8,
	message = "@Source@ diseases @target@.",
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if math.floor(core.fov.distance(self.x, self.y, x, y)) > 1 then return nil end
		local hit = self:attackTarget(target, nil, 0.5 + self:getTalentLevel(t) / 10, true)

		-- Try to rot !
		if hit then
			if target:checkHit(self:combatAttackStr(), target:combatPhysicalResist(), 0, 95, 5 - self:getTalentLevel(t) / 2) then
				target:setEffect(target.EFF_ROTTING_DISEASE, 10 + self:getTalentLevel(t) * 3, {src=self, dam=self:getStr() / 3 + self:getTalentLevel(t) * 2, con=math.floor(4 + target:getCon() * 0.1)})
			else
				game.logSeen(target, "%s resists the disease!", target.name:capitalize())
			end
		end

		return true
	end,
	info = function(self, t)
		return ([[Hits the target doing %d%% damage, if the attack hits, the target is diseased.]]):format(100 * (0.5 + self:getTalentLevel(t) / 10))
	end,
}

newTalent{
	name = "Decrepitude Disease",
	type = {"technique/other", 1},
	points = 5,
	cooldown = 8,
	message = "@Source@ diseases @target@.",
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if math.floor(core.fov.distance(self.x, self.y, x, y)) > 1 then return nil end
		local hit = self:attackTarget(target, nil, 0.5 + self:getTalentLevel(t) / 10, true)

		-- Try to rot !
		if hit then
			if target:checkHit(self:combatAttackStr(), target:combatPhysicalResist(), 0, 95, 5 - self:getTalentLevel(t) / 2) then
				target:setEffect(target.EFF_DECREPITUDE_DISEASE, 10 + self:getTalentLevel(t) * 3, {src=self, dam=self:getStr() / 3 + self:getTalentLevel(t) * 2, dex=math.floor(4 + target:getDex() * 0.1)})
			else
				game.logSeen(target, "%s resists the disease!", target.name:capitalize())
			end
		end

		return true
	end,
	info = function(self, t)
		return ([[Hits the target doing %d%% damage, if the attack hits, the target is diseased.]]):format(100 * (0.5 + self:getTalentLevel(t) / 10))
	end,
}

newTalent{
	name = "Weakness Disease",
	type = {"technique/other", 1},
	points = 5,
	cooldown = 8,
	message = "@Source@ diseases @target@.",
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if math.floor(core.fov.distance(self.x, self.y, x, y)) > 1 then return nil end
		local hit = self:attackTarget(target, nil, 0.5 + self:getTalentLevel(t) / 10, true)

		-- Try to rot !
		if hit then
			if target:checkHit(self:combatAttackStr(), target:combatPhysicalResist(), 0, 95, 5 - self:getTalentLevel(t) / 2) then
				target:setEffect(target.EFF_WEAKNESS_DISEASE, 10 + self:getTalentLevel(t) * 3, {src=self, dam=self:getStr() / 3 + self:getTalentLevel(t) * 2, str=math.floor(4 + target:getStr() * 0.1)})
			else
				game.logSeen(target, "%s resists the disease!", target.name:capitalize())
			end
		end

		return true
	end,
	info = function(self, t)
		return ([[Hits the target doing %d%% damage, if the attack hits, the target is diseased.]]):format(100 * (0.5 + self:getTalentLevel(t) / 10))
	end,
}

newTalent{
	name = "Mind Disruption",
	type = {"spell/other", 1},
	points = 5,
	cooldown = 10,
	mana = 16,
	range = 20,
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t), talent=t}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		self:project(tg, x, y, DamageType.CONFUSION, {dur=2+self:getTalentLevel(t), dam=50+self:getTalentLevelRaw(t)*10}, {type="manathrust"})
		return true
	end,
	info = function(self)
		return ([[Try to confuse the target's mind fr a while.]])
	end,
}

newTalent{
	name = "Water Bolt",
	type = {"spell/other", },
	points = 5,
	mana = 10,
	cooldown = 3,
	tactical = {
		ATTACK = 10,
	},
	range = 20,
	reflectable = true,
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t), talent=t}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		self:project(tg, x, y, DamageType.COLD, self:spellCrit(12 + self:combatSpellpower(0.25) * self:getTalentLevel(t)), {type="freeze"})
		game:playSoundNear(self, "talents/ice")
		return true
	end,
	info = function(self, t)
		return ([[Condenses ambient water on a target, damaging it for %0.2f.
		The damage will increase with the Magic stat]]):format(12 + self:combatSpellpower(0.25) * self:getTalentLevel(t))
	end,
}

newTalent{
	name = "Grab",
	type = {"technique/other", 1},
	points = 5,
	cooldown = 6,
	stamina = 8,
	require = { stat = { str=12 }, },
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if math.floor(core.fov.distance(self.x, self.y, x, y)) > 1 then return nil end
		local hit = self:attackTarget(target, nil, 0.8 + self:getTalentLevel(t) / 7, true)

		-- Try to stun !
		if hit then
			if target:checkHit(self:combatAttackStr(), target:combatPhysicalResist(), 0, 95, 5 - self:getTalentLevel(t) / 2) and target:canBe("stun") then
				target:setEffect(target.EFF_PINNED, 1 + self:getTalentLevel(t), {})
			else
				game.logSeen(target, "%s resists the grab!", target.name:capitalize())
			end
		end

		return true
	end,
	info = function(self, t)
		return ([[Hits the target doing %d%% damage, if the attack hits, the target is pinned tp the ground.]]):format(100 * (0.8 + self:getTalentLevel(t) / 7))
	end,
}

newTalent{
	name = "Blinding Ink",
	type = {"wild-gift/other", 1},
	points = 5,
	equilibrium = 12,
	cooldown = 12,
	message = "@Source@ projects ink!",
	tactical = {
		ATTACKAREA = 10,
		DEFEND = 5,
	},
	range = 4,
	action = function(self, t)
		local tg = {type="cone", range=0, radius=4 + self:getTalentLevelRaw(t), friendlyfire=false, talent=t}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		self:project(tg, x, y, DamageType.BLINDING_INK, 2+self:getTalentLevelRaw(t), {type="dark"})
		game:playSoundNear(self, "talents/breath")
		return true
	end,
	info = function(self, t)
		return ([[You project thick black ink, blinding your targets for %d turns.]]):format(2+self:getTalentLevelRaw(t))
	end,
}
