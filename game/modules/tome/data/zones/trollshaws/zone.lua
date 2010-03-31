return {
	name = "Trollshaws",
	level_range = {1, 5},
	level_scheme = "player",
	max_level = 5,
	actor_adjust_level = function(zone, level, e) return zone.base_level + level.level-1 + rng.range(-1,2) end,
	width = 50, height = 50,
--	all_remembered = true,
	all_lited = true,
	persistant = "zone",
	generator =  {
		map = {
			class = "engine.generator.map.Roomer",
			nb_rooms = 10,
			edge_entrances = {4,6},
			rooms = {"forest_clearing"},
			['.'] = function() if rng.chance(20) then return "FLOWER" else return "GRASS" end end,
			['#'] = "TREE",
			up = "UP",
			down = "DOWN",
			door = "GRASS",
		},
		actor = {
			class = "engine.generator.actor.Random",
			nb_npc = {20, 30},
			guardian = "TROLL_BILL",
		},
		object = {
			class = "engine.generator.object.Random",
			nb_object = {6, 9},
			filters = { {type="potion" }, {type="potion" }, {type="potion" }, {type="scroll" }, {}, {} }
		},
		trap = {
			class = "engine.generator.trap.Random",
			nb_trap = {6, 9},
		},
	},
	levels =
	{
		[1] = {
			generator = { map = {
				up = "UP_WILDERNESS",
			}, },
		},
	},
}
