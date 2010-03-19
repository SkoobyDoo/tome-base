newTalent{
	name = "War Hound",
	type = {"gift/summon-melee", 1},
	require = gifts_req1,
	points = 5,
	message = "@Source@ summons a War Hound!",
	equilibrium = 3,
	cooldown = 15,
	range = 20,
	action = function(self, t)
		local tg = {type="bolt", range=self:getTalentRange(t), nolock=true, talent=t}
		local tx, ty, target = self:getTarget(tg)
		if not tx or not ty then return nil end
		tx, ty = game.target:pointAtRange(self.x, self.y, tx, ty, self:getTalentRange(t))
		if target == self then target = nil end

		-- Find space
		local x, y = util.findFreeGrid(tx, ty, 5, true, {[Map.ACTOR]=true})
		if not x then
			game.logPlayer(self, "Not enough space to summon!")
			return
		end

		local NPC = require "mod.class.NPC"
		local m = NPC.new{
			type = "animal", subtype = "canine",
			display = "C", color=colors.LIGHT_DARK,
			name = "war hound", faction = self.faction,
			desc = [[]],
			autolevel = "warrior",
			ai = "summoned", ai_real = "dumb_talented_simple", ai_state = { talent_in=5, },
			stats = { str=10 + self:getWil() * self:getTalentLevel(t) / 5, dex=10 + self:getTalentLevel(t) * 2, mag=5, con=15 },
			level_range = {self.level, self.level}, exp_worth = 0,

			max_life = resolvers.rngavg(25,50),
			life_rating = 4,

			combat_armor = 2, combat_def = 4,
			combat = { dam=resolvers.rngavg(12,25), atk=10, apr=10, dammod={str=0.8} },

			summoner = self, summoner_gain_exp=true,
			summon_time = math.ceil(self:getTalentLevel(t)) + 5,
			ai_target = {actor=target}
		}

		m:resolve() m:resolve(nil, true)
		m:forceLevelup(self.level)
		game.zone:addEntity(game.level, m, "actor", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Summon a War Hound to attack your foes. War hounds are good basic melee attackers.
		It will get %d strength and %d dexterity.]]):format(10 + self:getWil() * self:getTalentLevel(t) / 5, 10 + self:getTalentLevel(t) * 2)
	end,
}

newTalent{
	name = "Jelly",
	type = {"gift/summon-melee", 2},
	require = gifts_req2,
	points = 5,
	message = "@Source@ summons a Jelly!",
	equilibrium = 5,
	cooldown = 10,
	range = 20,
	action = function(self, t)
		local tg = {type="bolt", range=self:getTalentRange(t), nolock=true, talent=t}
		local tx, ty, target = self:getTarget(tg)
		if not tx or not ty then return nil end
		tx, ty = game.target:pointAtRange(self.x, self.y, tx, ty, self:getTalentRange(t))
		if target == self then target = nil end

		-- Find space
		local x, y = util.findFreeGrid(tx, ty, 5, true, {[Map.ACTOR]=true})
		if not x then
			game.logPlayer(self, "Not enough space to summon!")
			return
		end

		local NPC = require "mod.class.NPC"
		local m = NPC.new{
			type = "immovable", subtype = "jelly",
			display = "j", color=colors.BLACK,
			desc = "A strange blob on the dungeon floor.",
			name = "black jelly",
			autolevel = "none", faction=self.faction,
			stats = { con=10 + self:getWil() * self:getTalentLevel(t) / 5, str=10 + self:getTalentLevel(t) * 2 },
			resists = { [DamageType.LIGHT] = -50 },
			ai = "summoned", ai_real = "dumb_talented_simple", ai_state = { talent_in=5, },
			level_range = {self.level, self.level}, exp_worth = 0,

			max_life = resolvers.rngavg(25,50),
			life_rating = 10,

			combat_armor = 1, combat_def = 1,
			never_move = 1,

			combat = { dam=8, atk=15, apr=5, damtype=DamageType.ACID, dammod={str=0.7} },

			summoner = self, summoner_gain_exp=true,
			summon_time = math.ceil(self:getTalentLevel(t)) + 5,
			ai_target = {actor=target}
		}

		m:resolve() m:resolve(nil, true)
		m:forceLevelup(self.level)
		game.zone:addEntity(game.level, m, "actor", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Summon a Jelly to attack your foes. Jellies do not move, but are great to block a passage.
		It will get %d constitution and %d strength.]]):format(10 + self:getWil() * self:getTalentLevel(t) / 5, 10 + self:getTalentLevel(t) * 2)
       end,
}

newTalent{
	name = "Minotaur",
	type = {"gift/summon-melee", 3},
	require = gifts_req3,
	points = 5,
	message = "@Source@ summons a Minotaur!",
	equilibrium = 10,
	cooldown = 10,
	range = 20,
	action = function(self, t)
		local tg = {type="bolt", range=self:getTalentRange(t), nolock=true, talent=t}
		local tx, ty, target = self:getTarget(tg)
		if not tx or not ty then return nil end
		tx, ty = game.target:pointAtRange(self.x, self.y, tx, ty, self:getTalentRange(t))
		if target == self then target = nil end

		-- Find space
		local x, y = util.findFreeGrid(tx, ty, 5, true, {[Map.ACTOR]=true})
		if not x then
			game.logPlayer(self, "Not enough space to summon!")
			return
		end

		local NPC = require "mod.class.NPC"
		local m = NPC.new{
			type = "giant", subtype = "minotaur",
			display = "H",
			name = "minotaur", color=colors.UMBER,

			body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1 },

			max_stamina = 100,
			life_rating = 13,
			max_life = resolvers.rngavg(50,80),

			autolevel = "none",
			ai = "summoned", ai_real = "dumb_talented_simple", ai_state = { talent_in=5, },
			energy = { mod=1.2 },
			stats = { str=25 + self:getWil() * self:getTalentLevel(t) / 5, dex=18, con=10 + self:getTalentLevel(t) * 2, },

			resolvers.tmasteries{ ["technique/2hweapon-offense"]=0.3, ["technique/2hweapon-cripple"]=0.3, ["technique/combat-training"]=0.3, },
			desc = [[It is a cross between a human and a bull.]],
			equipment = resolvers.equip{ {type="weapon", subtype="battleaxe", auto_req=true}, },
			level_range = {self.level, self.level}, exp_worth = 0,

			combat_armor = 13, combat_def = 8,
			resolvers.talents{ [Talents.T_WARSHOUT]=3, [Talents.T_STUNNING_BLOW]=3, [Talents.T_SUNDER_ARMOUR]=2, [Talents.T_SUNDER_ARMS]=2, },

			faction = self.faction,
			summoner = self, summoner_gain_exp=true,
			summon_time = math.ceil(self:getTalentLevel(t)) + 2,
			ai_target = {actor=target}
		}

		m:resolve() m:resolve(nil, true)
		m:forceLevelup(self.level)
		game.zone:addEntity(game.level, m, "actor", x, y)
		game.level.map:particleEmitter(x, y, 1, "summon")

		return true
	end,
	info = function(self, t)
		return ([[Summon a Minotaur to attack your foes. Minotaurs can not stay summoned for long but they deal lots of damage.
		It will get %d strength and %d constitution.]]):format(25 + self:getWil() * self:getTalentLevel(t) / 5, 10 + self:getTalentLevel(t) * 2)
	end,
}
