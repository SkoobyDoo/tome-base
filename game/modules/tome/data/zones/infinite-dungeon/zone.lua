

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

local rooms = {"random_room", {"pit",3}, {"greater_vault",7}}
if game:isAddonActive("items-vault") then table.insert(rooms, {"!items-vault",5}) end

return {
	name = "Infinite Dungeon",
	level_range = {1, 1},
	level_scheme = "player",
	max_level = 1000000000,
	actor_adjust_level = function(zone, level, e) return math.floor((zone.base_level + level.level-1) * 1.2) + e:getRankLevelAdjust() + rng.range(-1,2) end,
	width = 70, height = 70,
--	all_remembered = true,
--	all_lited = true,
	no_worldport = true,
	infinite_dungeon = true,
	events_by_level = true,
	ambient_music = function() return rng.table{
		"Battle Against Time.ogg",
		"Breaking the siege.ogg",
		"Broken.ogg",
		"Challenge.ogg",
		"Driving the Top Down.ogg",
		"Enemy at the gates.ogg",
		"Hold the Line.ogg",
		"Kneel.ogg",
		"March.ogg",
		"Mystery.ogg",
		"Rain of Blood.ogg",
		"Sinestra.ogg",
		"Straight Into Ambush.ogg",
		"Suspicion.ogg",
		"Swashing the buck.ogg",
		"Taking flight.ogg",
		"Thrall's Theme.ogg",
		"Through the Dark Portal.ogg",
		"Together We Are Strong.ogg",
		"Treason.ogg",
		"Valve.ogg",
		"Zangarang.ogg",
	} end,
	generator =  {
		map = {
			class = "engine.generator.map.Roomer",
			nb_rooms = 14,
			rooms = rooms,
			rooms_config = {pit={filters={}}},
			lite_room_chance = 50,
			['.'] = "FLOOR",
			['#'] = "WALL",
			['+'] = "DOOR",
			I = "ITEMS_VAULT",
			up = "FLOOR",
			down = "DOWN",
			door = "DOOR",
		},
		actor = {
			class = "mod.class.generator.actor.RandomStairGuard",
			guard_test = function(level)
				local allow = {[5]=true, [8]=true, [11]=true, [14]=true, [16]=true, [18]=true, [20]=true, [22]=true, [24]=true, [26]=true, [28]=true }
				if level.level >= 30 then return true end
				return allow[level.level]
			end,
			guard = {
				{random_boss={rank = 3.5, loot_quantity = 3,}},
			},
			nb_npc = {29, 39},
			filters = { {max_ood=6}, },
		},
		object = {
			class = "engine.generator.object.Random",
			nb_object = {6, 9},
		},
		trap = {
			class = "engine.generator.trap.Random",
			nb_trap = {0, 0},
		},
	},
	alter_level_data = function(zone, lev, data)
		if lev < 3 or rng.percent(30) then game.state:infiniteDungeonChallenge(zone, lev, data, "default", "default") return end

		-- Randomize the size of the dungeon, increasing it slightly as the game progresses.
		-- Also change enemy count to fit with the new size.		
		local size = 50
		local vx = math.ceil(math.random(0.75, 1.25) * size)
		local vy = math.ceil(math.random(0.75, 1.25) * size)
		
		-- Takent from random zone generation, modified slightly for use here.
		-- Grab a random layout for the floor.		
		local layouts = {
			{
				id_layout_name = "forest",
				class = "engine.generator.map.Forest",
				edge_entrances = rng.table{{2,8}, {4,6}, {6,4}, {8,2}},
				zoom = rng.range(2,6),
				sqrt_percent = rng.range(30, 50),
				sqrt_percent = rng.range(5, 10),
				noise = "fbm_perlin",
			},
			{
				id_layout_name = "cavern",
				class = "engine.generator.map.Cavern",
				zoom = math.random(10, 20),
				min_floor = math.floor(rng.range(vx * vy * 0.4 / 2, vx * vy * 0.4)),
			},
			{
				id_layout_name = "default",
				class = "engine.generator.map.Roomer",
				nb_rooms = 14,
				rooms = {"random_room", {"pit",3}, {"greater_vault",7}},
				rooms_config = {pit={filters={}}},
				lite_room_chance = 50,
			},
			{
				id_layout_name = "maze",
				class = "engine.generator.map.Maze",
				widen_w = math.random(1,7), widen_h = math.random(1,7),
			},
			{
				id_layout_name = "town",
				class = "engine.generator.map.Town",
				building_chance = math.random(50,90),
				max_building_w = math.random(5,11), max_building_h = math.random(5,11),
				edge_entrances = {6,4},
				nb_rooms = math.random(1,2),
				rooms = {{"greater_vault",2}},
			},
			{
				id_layout_name = "building",
				class = "engine.generator.map.Building",
				lite_room_chance = rng.range(0, 100),
				max_block_w = rng.range(7, 20), max_block_h = rng.range(7, 20),
				max_building_w = rng.range(2, 8), max_building_h = rng.range(2, 8),
			},
			{
				id_layout_name = "octopus",
				class = "engine.generator.map.Octopus",
				main_radius = {0.3, 0.4},
				arms_radius = {0.1, 0.2},
				arms_range = {0.7, 0.8},
				nb_rooms = {3, 9},
			},
			{
				id_layout_name = "hexa",
				class = "engine.generator.map.Hexacle",
				segment_wide_chance = 70,
				nb_segments = 8,
				nb_layers = 6,
				segment_miss_percent = 10,
				force_square_size = true,
			},
		}
		zone:triggerHook{"InfiniteDungeon:getLayouts", layouts=layouts}
		
		local layout = rng.table(layouts)
		local layout = layouts[4]
		data.generator.map = layout
		
		local vgrids = {
			{id_grids_name="tree", floor="GRASS", wall="TREE", door="GRASS_ROCK", down="GRASS_DOWN2"},
			{id_grids_name="wall", floor="FLOOR", wall="WALL", door="DOOR", down="DOWN"},
			{id_grids_name="underground", floor="UNDERGROUND_FLOOR", wall="UNDERGROUND_TREE", door="UNDERGROUND_ROCK", down="UNDERGROUND_LADDER_DOWN"},
			{id_grids_name="crystals", floor="CRYSTAL_FLOOR", wall={"CRYSTAL_WALL","CRYSTAL_WALL2","CRYSTAL_WALL3","CRYSTAL_WALL4","CRYSTAL_WALL5","CRYSTAL_WALL6","CRYSTAL_WALL7","CRYSTAL_WALL8","CRYSTAL_WALL9","CRYSTAL_WALL10","CRYSTAL_WALL11","CRYSTAL_WALL12","CRYSTAL_WALL13","CRYSTAL_WALL14","CRYSTAL_WALL15","CRYSTAL_WALL16","CRYSTAL_WALL17","CRYSTAL_WALL18","CRYSTAL_WALL19","CRYSTAL_WALL20",}, door="CRYSTAL_ROCK", down="CRYSTAL_LADDER_DOWN"},
			{id_grids_name="sand", floor="UNDERGROUND_SAND", wall="SANDWALL", door="UNDERGROUND_SAND", down="SAND_LADDER_DOWN"},
			{id_grids_name="desert", floor="SAND", wall="PALMTREE", door="DESERT_ROCK", down="SAND_DOWN2"},
			{id_grids_name="slime", floor="SLIME_FLOOR", wall="SLIME_WALL", door="SLIME_DOOR", down="SLIME_DOWN"},
			{id_grids_name="jungle", floor="JUNGLE_GRASS", wall="JUNGLE_TREE", door="JUNGLE_ROCK", down="JUNGLE_GRASS_DOWN2"},
			{id_grids_name="cave", floor="CAVEFLOOR", wall="CAVEWALL", door="CAVE_ROCK", down="CAVE_LADDER_DOWN"},
			{id_grids_name="burntland", floor="BURNT_GROUND", wall="BURNT_TREE", door="BURNT_GROUND", down="BURNT_DOWN6"},
			{id_grids_name="mountain", floor="ROCKY_GROUND", wall="MOUNTAIN_WALL", door="ROCKY_GROUND", down="ROCKY_DOWN2"},
			{id_grids_name="mountain_forest", floor="ROCKY_GROUND", wall="ROCKY_SNOWY_TREE", door="ROCKY_GROUND", down="ROCKY_DOWN2"},
			{id_grids_name="snowy_forest", floor="SNOWY_GRASS_2", wall="SNOWY_TREE_2", door="SNOWY_GRASS_2", down="snowy_DOWN2"},
			{id_grids_name="temporal_void", floor="VOID", wall="SPACETIME_RIFT2", door="VOID", down="RIFT2"},
			{id_grids_name="water", floor="WATER_FLOOR_FAKE", wall="WATER_WALL_FAKE", door="WATER_DOOR_FAKE", down="WATER_DOWN_FAKE"},
			{id_grids_name="lava", floor="LAVA_FLOOR_FAKE", wall="LAVA_WALL_FAKE", door="LAVA_FLOOR_FAKE", down="LAVA_DOWN_FAKE"},
			{id_grids_name="autumn_forest", floor="AUTUMN_GRASS", wall="AUTUMN_TREE", door="AUTUMN_GRASS", down="AUTUMN_GRASS_DOWN2"},
		}
		zone:triggerHook{"InfiniteDungeon:getGrids", grids=vgrids}
		local vgrid = rng.table(vgrids)
		-- local vgrid = vgrids[#vgrids]
		
		data.generator.map.floor = vgrid.floor
		data.generator.map['.'] = vgrid.floor
		data.generator.map.external_floor = vgrid.floor
		data.generator.map.wall = vgrid.wall
		data.generator.map['#'] = vgrid.wall
		data.generator.map.up = vgrid.floor
		data.generator.map.down = vgrid.down
		data.generator.map.door = vgrid.door
		data.generator.map["'"] = vgrid.door

		data.width = vx
		data.height = vy
		if data.generator.map.widen_w then
			-- Special sanity check. Maze generation tends to... mess up if their height/width values aren't multiplies of the tunnel sizes.
			while data.width % data.generator.map.widen_w ~= 0 do data.width = data.width + 1 end
			while data.height % data.generator.map.widen_h ~= 0 do data.height = data.height + 1 end
		end

		if layout.force_square_size then
			data.width = math.max(vx, vy)
			data.height = data.width
		end

		local enemy_count = math.ceil((vx + vy) * 0.35)
		data.generator.actor.nb_npc = {enemy_count-5, enemy_count+5}

		game.state:infiniteDungeonChallenge(zone, lev, data, data.generator.map.id_layout_name, vgrid.id_grids_name)
	end,
	post_process = function(level)
		-- Provide some achievements
		if level.level == 10 then world:gainAchievement("INFINITE_X10", game.player)
		elseif level.level == 20 then world:gainAchievement("INFINITE_X20", game.player)
		elseif level.level == 30 then world:gainAchievement("INFINITE_X30", game.player)
		elseif level.level == 40 then world:gainAchievement("INFINITE_X40", game.player)
		elseif level.level == 50 then world:gainAchievement("INFINITE_X50", game.player)
		elseif level.level == 60 then world:gainAchievement("INFINITE_X60", game.player)
		elseif level.level == 70 then world:gainAchievement("INFINITE_X70", game.player)
		elseif level.level == 80 then world:gainAchievement("INFINITE_X80", game.player)
		elseif level.level == 90 then world:gainAchievement("INFINITE_X90", game.player)
		elseif level.level == 100 then world:gainAchievement("INFINITE_X100", game.player)
		elseif level.level == 150 then world:gainAchievement("INFINITE_X150", game.player)
		elseif level.level == 200 then world:gainAchievement("INFINITE_X200", game.player)
		elseif level.level == 300 then world:gainAchievement("INFINITE_X300", game.player)
		elseif level.level == 400 then world:gainAchievement("INFINITE_X400", game.player)
		elseif level.level == 500 then world:gainAchievement("INFINITE_X500", game.player)
		end

		-- Everything hates you in the infinite dungeon!
		for uid, e in pairs(level.entities) do e.faction = e.hard_faction or "enemies" end

		-- Some lore
		if level.level == 1 or level.level == 10 or level.level == 20 or level.level == 30 or level.level == 40 then
			local l = game.zone:makeEntityByName(level, "object", "ID_HISTORY"..level.level)
			if not l then return end
			for _, coord in pairs(util.adjacentCoords(level.default_up.x, level.default_up.y)) do
				if game.level.map:isBound(coord[1], coord[2]) and (i ~= 0 or j ~= 0) and not game.level.map:checkEntity(coord[1], coord[2], engine.Map.TERRAIN, "block_move") then
					game.zone:addEntity(level, l, "object", coord[1], coord[2])
					return
				end
			end
		end

		game.state:infiniteDungeonChallengeFinish(game.zone, level)
	end,
}

