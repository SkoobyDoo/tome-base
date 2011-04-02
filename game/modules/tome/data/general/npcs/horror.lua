-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009, 2010, 2011 Nicolas Casalini
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

-- last updated:  10:46 AM 2/3/2010

local Talents = require("engine.interface.ActorTalents")

newEntity{
	define_as = "BASE_NPC_HORROR",
	type = "horror", subtype = "eldritch",
	display = "h", color=colors.WHITE,
	blood_color = colors.BLUE,
	body = { INVEN = 10 },
	autolevel = "warrior",
	ai = "dumb_talented_simple", ai_state = { ai_move="move_dmap", talent_in=3, },

	stats = { str=22, dex=20, wil=15, con=15 },
	combat_armor = 0, combat_def = 0,
	combat = { dam=5, atk=15, apr=7, dammod={str=0.6} },
	infravision = 20,
	max_life = resolvers.rngavg(10,20),
	rank = 2,
	size_category = 3,

	no_breath = 1,
}

newEntity{ base = "BASE_NPC_HORROR",
	name = "worm that walks", color=colors.SANDY_BROWN,
	desc = [[A maggot-filled robe with a vaguely humanoid shape.]],
	level_range = {15, nil}, exp_worth = 1,
	rarity = 5,
	max_life = 120,
	life_rating = 16,
	rank = 3,

	ai = "tactical", ai_state = { ai_move="move_dmap", talent_in=1, },
	ai_tactic = resolvers.tactic "melee",

	see_invisible = 100,
	instakill_immune = 1,
	stun_immune = 1,
	blind_immune = 1,

	resists = { [DamageType.PHYSICAL] = 50, [DamageType.FIRE] = -50},

	body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1 },
	resolvers.drops{chance=20, nb=1, {} },
	resolvers.equip{
		{type="weapon", subtype="sword", autoreq=true},
		{type="weapon", subtype="waraxe", autoreq=true},
		{type="armor", subtype="robe", autoreq=true}
	},

	resolvers.talents{
		[Talents.T_BONE_GRAB]={base=4, every=10},
		[Talents.T_DRAIN]={base=5, every=12},
		[Talents.T_CORRUPTED_STRENGTH]={base=3, every=15},
		[Talents.T_VIRULENT_DISEASE]={base=3, every=12},
		[Talents.T_CURSE_OF_DEATH]={base=5, every=15},
		[Talents.T_REND]={base=4, every=12},
		[Talents.T_BLOODLUST]={base=3, every=12},
		[Talents.T_RUIN]={base=2, every=12},

		[Talents.T_WEAPON_COMBAT]={base=5, every=10, max=10},
		[Talents.T_WEAPONS_MASTERY]={base=3, every=10, max=10},
	},
	resolvers.sustains_at_birth(),

	summon = {
		{type="vermin", subtype="worms", name="carrion worm mass", number=2, hasxp=false},
	},
	make_escort = {
		{type="vermin", subtype="worms", name="carrion worm mass", number=2},
	},
}

newEntity{ base = "BASE_NPC_HORROR",
	name = "bloated horror", color=colors.WHITE,
	desc ="A bulbous humanoid form floats here. Its bald, child-like head is disproportionately large compared to its body, and its skin is pock-marked in nasty red sores.",
	level_range = {10, nil}, exp_worth = 1,
	rarity = 1,
	rank = 2,
	size_category = 4,
	autolevel = "caster",
	combat_armor = 1, combat_def = 0,
	combat = {dam=resolvers.levelup(resolvers.mbonus(25, 15), 1, 1.1), apr=0, atk=resolvers.mbonus(30, 15), dammod={mag=0.6}},

	never_move = 1,

	resists = {all = 35, [DamageType.LIGHT] = -30},

	resolvers.talents{
		[Talents.T_FEATHER_WIND]={base=5, every=10, max=10},
		[Talents.T_PHASE_DOOR]=2,
		[Talents.T_MIND_DISRUPTION]={base=4, every=14, max=7},
		[Talents.T_MIND_SEAR]={base=4, every=14, max=7},
		[Talents.T_TELEKINETIC_BLAST]={base=4, every=14, max=7},
	},

	resolvers.sustains_at_birth(),
	on_die = function(self, who)
		local part = "BLOATED_HORROR_HEART"
		if game.player:hasQuest("brotherhood-of-alchemists") then
			game.player:hasQuest("brotherhood-of-alchemists"):need_part(who, part, self)
		end
	end,
}

newEntity{ base = "BASE_NPC_HORROR",
	name = "nightmare horror", color=colors.DARK_GREY,
	desc ="A shifting form of darkest night that seems to reflect your deepest fears.",
	level_range = {30, nil}, exp_worth = 1,
	negative_regen = 10,
	rarity = 7,
	rank = 3,
	life_rating = 7,
	autolevel = "warriormage",
	stats = { str=15, dex=20, mag=20, wil=20, con=15 },
	combat_armor = 1, combat_def = 10,
	combat = { dam=resolvers.levelup(20, 1, 1.1), atk=20, apr=50, dammod={str=0.6}, damtype=DamageType.DARKNESS},

	ai = "tactical", ai_state = { ai_target="target_player_radius", sense_radius=40, talent_in=2, },

	can_pass = {pass_wall=70},
	resists = {all = 35, [DamageType.LIGHT] = -50, [DamageType.DARKNESS] = 100},

	blind_immune = 1,
	see_invisible = 80,
	no_breath = 1,

	resolvers.talents{
		[Talents.T_STALK]={base=5, every=12, max=8},
		[Talents.T_GLOOM]={base=3, every=12, max=8},
		[Talents.T_WEAKNESS]={base=3, every=12, max=8},
		[Talents.T_TORMENT]={base=3, every=12, max=8},
		[Talents.T_DOMINATE]={base=3, every=12, max=8},
		[Talents.T_BLINDSIDE]={base=3, every=12, max=8},
		[Talents.T_LIFE_LEECH]={base=5, every=12, max=9},
		[Talents.T_SHADOW_BLAST]={base=4, every=8, max=8},
		[Talents.T_HYMN_OF_SHADOWS]={base=3, every=9, max=8},
	},

	resolvers.sustains_at_birth(),
}


------------------------------------------------------------------------
-- Headless horror and its eyes
------------------------------------------------------------------------
newEntity{ base = "BASE_NPC_HORROR",
	name = "headless horror", color=colors.TAN,
	desc ="A headless gangly humanoid with a large distended stomach.",
	level_range = {30, nil}, exp_worth = 1,
	rarity = 3,
	rank = 3,
	autolevel = "warrior",
	ai = "tactical", ai_state = { ai_move="move_dmap", talent_in=1, },
	combat = { dam=20, atk=20, apr=10, dammod={str=1} },
	combat = {damtype=DamageType.PHYSICAL},
	no_auto_resists = true,

	-- Should get resists based on eyes generated, 30% all per eye and 100% to the eyes element.  Should lose said resists when the eyes die.

	-- Should be blind but see through the eye escorts
	--blind= 1,

	resolvers.talents{
		[Talents.T_MANA_CLASH]={base=4, every=5, max=8},
		[Talents.T_GRAB]={base=4, every=6, max=8},
	},

	-- Add eyes
	on_added_to_level = function(self)
		local eyes = {}
		for i = 1, 3 do
			local x, y = util.findFreeGrid(self.x, self.y, 15, true, {[engine.Map.ACTOR]=true})
			if x and y then
				local m = game.zone:makeEntity(game.level, "actor", {properties={"is_eldritch_eye"}, special_rarity="_eldritch_eye_rarity"}, nil, true)
				if m then
					m.summoner = self
					game.zone:addEntity(game.level, m, "actor", x, y)
					eyes[m] = true

					-- Grant resist
					local damtype = next(m.resists)
					self.resists[damtype] = 100
					self.resists.all = (self.resists.all or 0) + 30
				end
			end
		end
		self.eyes = eyes
	end,

	-- Needs an on death affect that kills off any remaining eyes.
	on_die = function(self, src)
		local nb = 0
		for eye, _ in pairs(self.eyes) do
			if not eye.dead then eye:die(src) nb = nb + 1 end
		end
		if nb > 0 then
			game.logSeen(self, "#AQUAMARINE#As %s falls all its eyes fall to the ground!", self.name)
		end
	end,
}

newEntity{ base = "BASE_NPC_HORROR", define_as = "BASE_NPC_ELDRICTH_EYE",
	name = "eldritch eye", color=colors.SLATE, is_eldritch_eye=true,
	desc ="A small bloodshot eye floats here.",
	level_range = {30, nil}, exp_worth = 1,
	life_rating = 7,
	rank = 2,
	size_category = 1,
	autolevel = "caster",
	ai = "dumb_talented_simple", ai_state = { ai_move="move_dmap", talent_in=1, },
	combat_armor = 1, combat_def = 0,
	levitation = 1,
	no_auto_resists = true,
	talent_cd_reduction = {all=100},

	on_die = function(self, src)
		if not self.summoner then return end
		game.logSeen(self, "#AQUAMARINE#As %s falls %s seems to weaken!", self.name, self.summoner.name)
		local damtype = next(self.resists)
		self.summoner.resists.all = (self.summoner.resists.all or 0) - 30
		self.summoner[damtype] = nil

		-- Blind the main horror if no more eyes
		local nb = 0
		for eye, _ in pairs(self.summoner.eyes) do
			if not eye.dead then nb = nb + 1 end
		end
		if nb == 0 then
			local sx, sy = game.level.map:getTileToScreen(self.summoner.x, self.summoner.y)
			game.flyers:add(sx, sy, 20, (rng.range(0,2)-1) * 0.5, -3, "+Blind", {255,100,80})
			self.summoner.blind = 1
			game.logSeen(self.summoner, "%s is blinded by the loss of all its eyes.", self.summoner.name:capitalize())
		end
	end,
}

newEntity{ base = "BASE_NPC_ELDRICTH_EYE",
	--fire
	_eldritch_eye_rarity = 1,
	vim_regen = 100,
	resists = {[DamageType.FIRE] = 80},
	resolvers.talents{
		[Talents.T_BURNING_HEX]=3,
	},
}

newEntity{ base = "BASE_NPC_ELDRICTH_EYE",
	--cold
	_eldritch_eye_rarity = 1,
	mana_regen = 100,
	resists = {[DamageType.COLD] = 80},
	resolvers.talents{
		[Talents.T_ICE_SHARDS]=3,
	},
}

newEntity{ base = "BASE_NPC_ELDRICTH_EYE",
	--earth
	_eldritch_eye_rarity = 1,
	mana_regen = 100,
	resists = {[DamageType.PHYSICAL] = 80},
	resolvers.talents{
		[Talents.T_STRIKE]=3,
	},
}

newEntity{ base = "BASE_NPC_ELDRICTH_EYE",
	--arcane
	_eldritch_eye_rarity = 1,
	mana_regen = 100,
	resists = {[DamageType.ARCANE] = 80},
	resolvers.talents{
		[Talents.T_MANATHRUST]=3,
	},
}

newEntity{ base = "BASE_NPC_ELDRICTH_EYE",
	--acid
	_eldritch_eye_rarity = 1,
	equilibrium_regen = -100,
	resists = {[DamageType.ACID] = 80},
	resolvers.talents{
		[Talents.T_HYDRA]=3,
	},
}

newEntity{ base = "BASE_NPC_ELDRICTH_EYE",
	--dark
	_eldritch_eye_rarity = 1,
	vim_regen = 100,
	resists = {[DamageType.DARKNESS] = 80},
	resolvers.talents{
		[Talents.T_CURSE_OF_DEATH]=3,
	},
}

newEntity{ base = "BASE_NPC_ELDRICTH_EYE",
	--light
	_eldritch_eye_rarity = 1,
	resists = {[DamageType.LIGHT] = 80},
	resolvers.talents{
		[Talents.T_SEARING_LIGHT]=3,
	},
}

newEntity{ base = "BASE_NPC_ELDRICTH_EYE",
	--lightning
	_eldritch_eye_rarity = 1,
	mana_regen = 100,
	resists = {[DamageType.LIGHTNING] = 80},
	resolvers.talents{
		[Talents.T_LIGHTNING]=3,
	},
}

newEntity{ base = "BASE_NPC_ELDRICTH_EYE",
	--blight
	_eldritch_eye_rarity = 1,
	vim_regen = 100,
	resists = {[DamageType.BLIGHT] = 80},
	resolvers.talents{
		[Talents.T_VIRULENT_DISEASE]=3,
	},
}

newEntity{ base = "BASE_NPC_ELDRICTH_EYE",
	--nature
	_eldritch_eye_rarity = 1,
	equilibrium_regen = -100,
	resists = {[DamageType.NATURE] = 80},
	resolvers.talents{
		[Talents.T_SPIT_POISON]=3,
	},
}

newEntity{ base = "BASE_NPC_ELDRICTH_EYE",
	--mind
	_eldritch_eye_rarity = 1,
	mana_regen = 100,
	resists = {[DamageType.MIND] = 80},
	resolvers.talents{
		[Talents.T_MIND_DISRUPTION]=3,
	},
}

newEntity{ base = "BASE_NPC_HORROR",
	name = "luminous horror", color=colors.YELLOW,
	desc ="A lanky humanoid shape composed of yellow light.",
	level_range = {20, nil}, exp_worth = 1,
	rarity = 2,
	autolevel = "caster",
	combat_armor = 1, combat_def = 10,
	combat = { dam=5, atk=15, apr=20, dammod={wil=0.6}, damtype=DamageType.LIGHT},
	ai = "dumb_talented_simple", ai_state = { ai_move="move_dmap", talent_in=1, },
	lite = 1,

	resists = {all = 35, [DamageType.DARKNESS] = -50, [DamageType.LIGHT] = 100, [DamageType.FIRE] = 100},

	blind_immune = 1,
	see_invisible = 10,

	resolvers.talents{
		[Talents.T_CHANT_OF_FORTITUDE]={base=3, every=10, max=6},
		[Talents.T_SEARING_LIGHT]={base=3, every=10, max=6},
		[Talents.T_FIREBEAM]={base=3, every=10, max=6},
		[Talents.T_PROVIDENCE]={base=3, every=10, max=6},
		[Talents.T_HEALING_LIGHT]={base=3, every=10, max=6},
		[Talents.T_BARRIER]={base=3, every=10, max=6},
	},

	resolvers.sustains_at_birth(),

	make_escort = {
		{type="horror", subtype="eldritch", name="luminous horror", number=2, no_subescort=true},
	},
	on_die = function(self, who)
		local part = "LUMINOUS_HORROR_DUST"
		if game.player:hasQuest("brotherhood-of-alchemists") then
			game.player:hasQuest("brotherhood-of-alchemists"):need_part(who, part, self)
		end
	end,
}

newEntity{ base = "BASE_NPC_HORROR",
	name = "radiant horror", color=colors.GOLD,
	desc ="A lanky four-armed humanoid shape composed of bright golden light.  It's so bright it's hard to look at and you can feel heat radiating outward from it.",
	level_range = {35, nil}, exp_worth = 1,
	rarity = 8,
	rank = 3,
	autolevel = "caster",
	max_life = resolvers.rngavg(220,250),
	combat_armor = 1, combat_def = 10,
	combat = { dam=20, atk=30, apr=40, dammod={wil=1}, damtype=DamageType.LIGHT},
	ai = "tactical", ai_state = { ai_move="move_dmap", talent_in=1, },
	lite = 1,

	resists = {all = 40, [DamageType.DARKNESS] = -50, [DamageType.LIGHT] = 100, [DamageType.FIRE] = 100},

	blind_immune = 1,
	see_invisible = 20,

	resolvers.talents{
		[Talents.T_CHANT_OF_FORTITUDE]={base=10, every=15},
		[Talents.T_CIRCLE_OF_BLAZING_LIGHT]={base=10, every=15},
		[Talents.T_SEARING_LIGHT]={base=10, every=15},
		[Talents.T_FIREBEAM]={base=10, every=15},
		[Talents.T_SUNBURST]={base=10, every=15},
		[Talents.T_SUN_FLARE]={base=10, every=15},
		[Talents.T_PROVIDENCE]={base=10, every=15},
		[Talents.T_HEALING_LIGHT]={base=10, every=15},
		[Talents.T_BARRIER]={base=10, every=15},
	},

	resolvers.sustains_at_birth(),

	make_escort = {
		{type="horror", subtype="eldritch", name="luminous horror", number=1, no_subescort=true},
	},
}

-- Temporal Horrors

newEntity{ base = "BASE_NPC_HORROR",
	subtype = "temporal",
	name = "temporal devourer", color=colors.CRIMSON,
	desc = "A headless round creature with stubbly legs and arms.  Its body seems to be all teeth.",
	level_range = {10, nil}, exp_worth = 1,
	rarity = 1,
	rank = 2,
	size_category = 2,
	autolevel = "warrior",
	max_life = resolvers.rngavg(50, 80),
	combat_armor = 1, combat_def = 10,
	combat = { dam=resolvers.levelup(resolvers.rngavg(20,30), 1, 1.2), atk=resolvers.rngavg(10,20), apr=5, dammod={str=1} },

	resists = { [DamageType.TEMPORAL] = 5},
}

newEntity{ base = "BASE_NPC_HORROR",
	subtype = "temporal",
	dredge = 1,
	name = "dredgling", color=colors.TAN,
	desc = "A small pink-skinned humanoid with large bulbous eyes.",
	level_range = {10, nil}, exp_worth = 1,
	rarity = 1,
	rank = 2,
	size_category = 2,
	autolevel = "warriormage",
	max_life = resolvers.rngavg(50, 80),
	combat_armor = 1, combat_def = 10,
	combat = { dam=resolvers.levelup(resolvers.rngavg(15,20), 1, 1.1), atk=resolvers.rngavg(5,15), apr=5, dammod={str=1} },

	resists = { [DamageType.TEMPORAL] = 5},

	resolvers.talents{
		[Talents.T_DUST_TO_DUST]={base=1, every=7, max=5},
	},

	resolvers.sustains_at_birth(),
}

newEntity{ base = "BASE_NPC_HORROR",
	subtype = "temporal",
	dredge = 1,
	name = "temporal dredge", color=colors.PINK,
	desc = "A hulking pink-skinned creature with long arms as thick as tree trunks.  It drags its knuckles on the ground as it lumbers towards you.",
	level_range = {15, nil}, exp_worth = 1,
	rarity = 4,
	rank = 2,
	size_category = 4,
	autolevel = "warrior",
	max_life = resolvers.rngavg(120, 150),
	global_speed = 0.7,
	combat_armor = 1, combat_def = 0,
	combat = { dam=resolvers.levelup(resolvers.rngavg(25,150), 1, 1.2), atk=resolvers.rngavg(25,130), apr=1, dammod={str=1.1} },

	resists = {all = 10, [DamageType.TEMPORAL] = 50, [DamageType.PHYSICAL] = 25},

	resolvers.talents{
		[Talents.T_STUN]={base=3, every=7, max=7},
		[Talents.T_SPEED_SAP]={base=2, every=7, max=6},
	},

	resolvers.sustains_at_birth(),
}

newEntity{ base = "BASE_NPC_HORROR",
	subtype = "temporal",
	dredge = 1,
	name = "dredge captain", color=colors.SALMON,
	desc = "A thin pink-skinned creature with long spindly arms.  Half its body is old and wrinkly and the other half appears quite young.",
	level_range = {20, nil}, exp_worth = 1,
	rarity = 6,
	rank = 3,
	size_category = 3,
	max_life = resolvers.rngavg(60,80),
	autolevel = "warriormage",
	ai = "dumb_talented_simple", ai_state = { ai_move="move_dmap", talent_in=1, },
	combat_armor = 1, combat_def = 0,

	resists = {all = 10, [DamageType.TEMPORAL] = 50},

	make_escort = {
		{type="horror", subtype="temporal", name="temporal dredge", number=3, no_subescort=true},
	},

	resolvers.talents{
		[Talents.T_DREDGE_FRENZY]={base=5, every=7, max=9},
		[Talents.T_SPEED_SAP]={base=3, every=7, max=9},
	},

	resolvers.sustains_at_birth(),
}

newEntity{ base = "BASE_NPC_HORROR",
	subtype = "temporal",
	name = "temporal stalker", color=colors.STEEL_BLUE,
	desc = "A slender metallic monstrosity with long claws in place of fingers and razor sharp teeth.",
	level_range = {20, nil}, exp_worth = 1,
	rarity = 6,
	size_category = 3,
	max_life = resolvers.rngavg(50,70),
	global_speed = 1.2,
	autolevel = "rogue",
	ai = "dumb_talented_simple", ai_state = { ai_move="move_dmap", talent_in=2, },
	combat_armor = 10, combat_def = 10,
	combat = { dam=resolvers.levelup(resolvers.rngavg(25,100), 1, 1.2), atk=resolvers.rngavg(25,100), apr=25, dammod={dex=1.1} },

	resists = {all = 10, [DamageType.TEMPORAL] = 50},

	resolvers.talents{
		[Talents.T_PERFECT_AIM]={base=3, every=7, max=5},
		[Talents.T_FORESIGHT]={base=5, every=7, max=8},
		[Talents.T_STEALTH]={base=3, every=7, max=5},
		[Talents.T_SHADOWSTRIKE]={base=3, every=7, max=5},
		[Talents.T_UNSEEN_ACTIONS]={base=3, every=7, max=5},
	},

	resolvers.sustains_at_birth(),
}

newEntity{ base = "BASE_NPC_HORROR",
	subtype = "temporal",
	name = "void horror", color=colors.GREY,
	desc = "It looks like a hole in spacetime, but you get the impression it's somehow more than that.",
	level_range = {20, nil}, exp_worth = 1,
	rarity = 4,
	rank = 2,
	size_category = 2,
	max_life = resolvers.rngavg(20,50),
	autolevel = "warriormage",
	ai = "dumb_talented_simple", ai_state = { ai_move="move_dmap", talent_in=2, },
	combat_armor = 1, combat_def = 10,
	on_melee_hit = { [DamageType.TEMPORAL] = resolvers.mbonus(20, 10), },

	resists = {[DamageType.TEMPORAL] = 50},

	resolvers.talents{
		[Talents.T_DISPERSE_MAGIC]={base=3, every=7, max=5},
		[Talents.T_ENTROPIC_FIELD]={base=3, every=7, max=5},
	},
	-- Random Anomaly on Death
	on_die = function(self, who)
		local ts = {}
		for id, t in pairs(self.talents_def) do
			if t.type[1] == "chronomancy/anomalies" then ts[#ts+1] = id end
		end
		self:forceUseTalent(rng.table(ts), {ignore_energy=true})
		game.logSeen(self, "%s has collapsed in upon itself.", self.name)
	end,

	resolvers.sustains_at_birth(),
}
------------------------------------------------------------------------
-- Uniques
------------------------------------------------------------------------

newEntity{ base="BASE_NPC_HORROR",
	name = "Grgglck the Devouring Darkness", unique = true,
	color = colors.DARK_GREY,
	rarity = 50,
	desc = [[A horror from the deepest pits of the earth. It looks like a huge pile of tentacles all trying to reach for you.
You can discern a huge round mouth covered in razor-sharp teeth.]],
	level_range = {20, nil}, exp_worth = 2,
	max_life = 300, life_rating = 25, fixed_rating = true,
	equilibrium_regen = -20,
	negative_regen = 20,
	rank = 3.5,
	no_breath = 1,
	size_category = 4,
	movement_speed = 0.8,

	stun_immune = 1,
	knockback_immune = 1,

	combat = { dam=resolvers.levelup(resolvers.mbonus(100, 15), 1, 1), atk=500, apr=0, dammod={str=1.2} },

	body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1 },
		  resolvers.drops{chance=100, nb=1, {unique=true} },
	resolvers.drops{chance=100, nb=5, {ego_chance=100} },

	resists = { all=500 },

	resolvers.talents{
		[Talents.T_STARFALL]={base=4, every=7},
		[Talents.T_MOONLIGHT_RAY]={base=4, every=7},
		[Talents.T_PACIFICATION_HEX]={base=4, every=7},
		[Talents.T_BURNING_HEX]={base=4, every=7},
	},
	resolvers.sustains_at_birth(),

	-- Invoke tentacles every few turns
	on_act = function(self)
		if not self.ai_target.actor or self.ai_target.actor.dead then return end
		if not self:hasLOS(self.ai_target.actor.x, self.ai_target.actor.y) then return end

		self.last_tentacle = self.last_tentacle or (game.turn - 60)
		if game.turn - self.last_tentacle >= 60 then -- Summon a tentacle every 6 turns
			self:forceUseTalent(self.T_INVOKE_TENTACLE, {no_energy=true})
			self.last_tentacle = game.turn
		end
	end,

	autolevel = "warriormage",
	ai = "tactical", ai_state = { talent_in=1, ai_move="move_astar" },
}

newEntity{ base="BASE_NPC_HORROR", define_as = "GRGGLCK_TENTACLE",
	name = "Grgglck's Tentacle",
	color = colors.GREY,
	desc = [[This is one of Grgglck's tentacles. It looks more vulnerable than the main body.]],
	level_range = {20, nil}, exp_worth = 0,
	max_life = 100, life_rating = 3, fixed_rating = true,
	equilibrium_regen = -20,
	rank = 3,
	no_breath = 1,
	size_category = 2,

	stun_immune = 1,
	knockback_immune = 1,
	teleport_immune = 1,

	resists = { all=50, [DamageType.DARKNESS] = 100 },

	combat = { dam=resolvers.mbonus(25, 15), atk=500, apr=500, dammod={str=1} },

	autolevel = "warrior",
	ai = "dumb_talented_simple", ai_state = { talent_in=3, ai_move="move_astar" },

	on_act = function(self)
		if self.summoner.dead then
			self:die()
			game.logSeen(self, "#AQUAMARINE#With Grgglck's death its tentacle also falls lifeless on the ground!")
		end
	end,

	on_die = function(self, who)
		if self.summoner and not self.summoner.dead then
			game.logSeen(self, "#AQUAMARINE#As %s falls you notice that %s seems to shudder in pain!", self.name, self.summoner.name)
			self.summoner:takeHit(self.max_life, who)
		end
	end,
}


