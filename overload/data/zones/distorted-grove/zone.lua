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


return {
	name = "Distorted Grove",
	level_range = {1, 3},
	level_scheme = "player",
	max_level = 3,
	decay = {300, 800},
	actor_adjust_level = function(zone, level, e) return zone.base_level + e:getRankLevelAdjust() + level.level-1 + rng.range(-1,2) end,
	width = 50, height = 50,
--	all_remembered = true,
	all_lited = true,
	day_night = true,
	persistent = "zone",
	color_shown =  {0.9, 0.9, 0.9, 1},
	color_obscure = {0.9*0.6, 0.9*0.6, 0.9*0.6, 0.6},
	ambient_music = {"Woods of Eremae.ogg", "weather/rain.ogg"},
	min_material_level = 1,
	max_material_level = 2,
	nicer_tiler_overlay = "DungeonWallsGrass",
	generator =  {
		map = {
			class = "engine.generator.map.Roomer",
			nb_rooms = 11,
			edge_entrances = {4,6},
			rooms = {"forest_clearing"},
			['.'] = "GRASS",
			['#'] = "TREE",
			up = "GRASS_UP4",
			down = "GRASS_DOWN6",
			door = "GRASS",
		},
		actor = {
			class = "mod.class.generator.actor.Random",
			nb_npc = {15, 20},
			-- guardian = "WRATHROOT", --replace with new boss
		},
		object = {
			class = "engine.generator.object.Random",
			class = "engine.generator.object.Random",
			nb_object = {6, 9},
			filters = { {} }
		},
		trap = {
			class = "engine.generator.trap.Random",
			nb_trap = {0, 0},
		},
	},
	levels =
	{
		[1] = {
			generator = { map = {
				up = "GRASS_UP_VILLAGE",
			}, },
		},
		[3] = {
			generator = {  map = {
				down = "DISTORTED_GLADE",
				force_last_stair = true,
			}, },

		},
	},

	post_process = function(level)
		-- Place a lore note on each level
		-- Since no lore has been written yet, this should not happen.
		-- game:placeRandomLoreObject("NOTE"..level.level) 

		if not config.settings.tome.weather_effects then return end

		local Map = require "engine.Map"
		level.foreground_particle = require("engine.Particles").new("raindrops", 1, {width=Map.viewport.width, height=Map.viewport.height})

		game.state:makeWeather(level, 6, {max_nb=3, chance=1, dir=110, speed={0.1, 0.6}, alpha={0.3, 0.5}, particle_name="weather/dark_cloud_%02d"})

		game.state:makeAmbientSounds(level, {
			wind={ chance=120, volume_mod=1.9, pitch=2, random_pos={rad=10}, files={"ambient/forest/wind1","ambient/forest/wind2","ambient/forest/wind3","ambient/forest/wind4"}},
			bird={ chance=1500, volume_mod=0.6, pitch=0.4, random_pos={rad=10}, files={"ambient/forest/bird1","ambient/forest/bird2","ambient/forest/bird3","ambient/forest/bird4","ambient/forest/bird5","ambient/forest/bird6","ambient/forest/bird7"}},
			creature={ chance=2500, volume_mod=0.6, pitch=0.5, random_pos={rad=10}, files={"creatures/bears/bear_growl_2", "creatures/bears/bear_growl_3", "creatures/bears/bear_moan_2"}},
		})
	end,

	foreground = function(level, x, y, nb_keyframes)
		if not config.settings.tome.weather_effects or not level.foreground_particle then return end
		level.foreground_particle.ps:toScreen(x, y, true, 1)
	end,
}
