newEntity{
	define_as = "BASE_LONGSWORD",
	slot = "MAINHAND",
	type = "weapon", subtype="longsword",
	display = "/", color=colors.SLATE,
	encumber = 3,
	rarity = 3,
	combat = { talented = "sword", },
	desc = [[Sharp, long, and deadly.]],
--	egos = "/data/general/objects/egos/swords.lua", egos_chance = resolvers.mbonus(40, 5),
}

newEntity{ base = "BASE_LONGSWORD",
	name = "iron longsword",
	level_range = {1, 10},
	require = { stat = { str=11 }, },
	cost = 5,
	combat = {
		dam = resolvers.rngavg(7,11),
		apr = 2,
		physcrit = 2.5,
		dammod = {str=1},
	},
}

newEntity{ base = "BASE_LONGSWORD",
	name = "steel longsword",
	level_range = {10, 20},
	require = { stat = { str=16 }, },
	cost = 10,
	combat = {
		dam = resolvers.rngavg(10,20),
		apr = 3,
		physcrit = 3,
		dammod = {str=1},
	},
}

newEntity{ base = "BASE_LONGSWORD",
	name = "dwarven-steel longsword",
	level_range = {20, 30},
	require = { stat = { str=24 }, },
	cost = 15,
	combat = {
		dam = resolvers.rngavg(25,35),
		apr = 4,
		physcrit = 3.5,
		dammod = {str=1},
	},
}

newEntity{ base = "BASE_LONGSWORD",
	name = "galvorn longsword",
	level_range = {30, 40},
	require = { stat = { str=35 }, },
	cost = 25,
	combat = {
		dam = resolvers.rngavg(40,55),
		apr = 5,
		physcrit = 4.5,
		dammod = {str=1},
	},
}

newEntity{ base = "BASE_LONGSWORD",
	name = "mithril longsword",
	level_range = {40, 50},
	require = { stat = { str=48 }, },
	cost = 35,
	combat = {
		dam = resolvers.rngavg(60,75),
		apr = 6,
		physcrit = 5,
		dammod = {str=1},
	},
}
