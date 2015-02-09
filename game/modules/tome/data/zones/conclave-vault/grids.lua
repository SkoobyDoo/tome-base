-- ToME - Tales of Maj'Eyal
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

load("/data/general/grids/basic.lua")
load("/data/general/grids/forest.lua")
load("/data/general/grids/water.lua")

newEntity{
	define_as = "WALL",
	type = "wall", subtype = "floor",
	name = "wall", image = "terrain/granite_wall1.png",
	display = '#', color_r=255, color_g=255, color_b=255, back_color=colors.GREY,
	z = 3,
	nice_tiler = { method="wall3d", inner={"WALL", 100, 1, 5}, north={"WALL_NORTH", 100, 1, 5}, south={"WALL_SOUTH", 10, 1, 15}, north_south="WALL_NORTH_SOUTH", small_pillar="WALL_SMALL_PILLAR", pillar_2="WALL_PILLAR_2", pillar_8={"WALL_PILLAR_8", 100, 1, 5}, pillar_4="WALL_PILLAR_4", pillar_6="WALL_PILLAR_6" },
	always_remember = true,
	does_block_move = true,
	can_pass = {pass_wall=1},
	block_sight = true,
	air_level = -20,
	dig = "FLOOR",
}
for i = 1, 5 do
	newEntity{ base = "WALL", define_as = "WALL"..i, image = "terrain/granite_wall1_"..i..".png", z = 3}
	newEntity{ base = "WALL", define_as = "WALL_NORTH"..i, image = "terrain/granite_wall1_"..i..".png", z = 3, add_displays = {class.new{image="terrain/granite_wall3.png", z=18, display_y=-1}}}
	newEntity{ base = "WALL", define_as = "WALL_PILLAR_8"..i, image = "terrain/granite_wall1_"..i..".png", z = 3, add_displays = {class.new{image="terrain/granite_wall_pillar_8.png", z=18, display_y=-1}}}
end
newEntity{ base = "WALL", define_as = "WALL_NORTH_SOUTH", image = "terrain/granite_wall2.png", z = 3, add_displays = {class.new{image="terrain/granite_wall3.png", z=18, display_y=-1}}}
newEntity{ base = "WALL", define_as = "WALL_SOUTH", image = "terrain/granite_wall2.png", z = 3}
for i = 1, 15 do newEntity{ base = "WALL", define_as = "WALL_SOUTH"..i, image = ("terrain/ruins/wall_%02d.png"):format(i), z = 3} end
newEntity{ base = "WALL", define_as = "WALL_SMALL_PILLAR", image = "terrain/marble_floor.png", z=1, add_displays = {class.new{image="terrain/granite_wall_pillar_small.png",z=3}, class.new{image="terrain/granite_wall_pillar_small_top.png", z=18, display_y=-1}}}
newEntity{ base = "WALL", define_as = "WALL_PILLAR_6", image = "terrain/marble_floor.png", z=1, add_displays = {class.new{image="terrain/granite_wall_pillar_3.png",z=3}, class.new{image="terrain/granite_wall_pillar_9.png", z=18, display_y=-1}}}
newEntity{ base = "WALL", define_as = "WALL_PILLAR_4", image = "terrain/marble_floor.png", z=1, add_displays = {class.new{image="terrain/granite_wall_pillar_1.png",z=3}, class.new{image="terrain/granite_wall_pillar_7.png", z=18, display_y=-1}}}
newEntity{ base = "WALL", define_as = "WALL_PILLAR_2", image = "terrain/marble_floor.png", z=1, add_displays = {class.new{image="terrain/granite_wall_pillar_2.png",z=3}}}


newEntity { base = "FLOOR", define_as = "RUNE_FLOOR1",
	add_displays = {class.new{z=3, image="terrain/ruins/floor_128_01.png", display_y = -0.5, display_x = -0.5, display_w=2, display_h=2}},
}
newEntity { base = "FLOOR", define_as = "RUNE_FLOOR2",
	add_displays = {class.new{z=3, image="terrain/ruins/floor_128_02.png", display_y = -0.5, display_x = -0.5, display_w=2, display_h=2}},
}
newEntity { base = "FLOOR", define_as = "RUNE_FLOOR3",
	add_displays = {class.new{z=3, image="terrain/ruins/floor_128_03.png", display_y = -0.5, display_x = -0.5, display_w=2, display_h=2}},
}
