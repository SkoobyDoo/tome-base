-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2018 Nicolas Casalini
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

if not currentZone.is_purified then
	load("/data/general/grids/underground_gloomy.lua")
else
	load("/data/general/grids/underground_dreamy.lua")
end

-- Define our own, to use old forest style trees
local treesdef = {
	{"oldforest_tree_01_trunk_01_foliage_summer_%02d", 1, 4, tall=-1},
	{"oldforest_tree_01_trunk_01_foliage_bare_%02d", 1, 4, tall=-1},
	{"oldforest_tree_01_trunk_02_foliage_summer_%02d", 1, 4, tall=-1},
	{"oldforest_tree_01_trunk_02_foliage_bare_%02d", 1, 4, tall=-1},
	{"oldforest_tree_01_trunk_03_foliage_summer_%02d", 1, 4, tall=-1},
	{"oldforest_tree_01_trunk_03_foliage_bare_%02d", 1, 4, tall=-1},
	{"oldforest_tree_02_trunk_01_foliage_summer_%02d", 1, 4, tall=-1},
	{"oldforest_tree_02_trunk_01_foliage_bare_%02d", 1, 4, tall=-1},
	{"oldforest_tree_02_trunk_02_foliage_summer_%02d", 1, 4, tall=-1},
	{"oldforest_tree_02_trunk_02_foliage_bare_%02d", 1, 4, tall=-1},
	{"oldforest_tree_02_trunk_03_foliage_summer_%02d", 1, 4, tall=-1},
	{"oldforest_tree_02_trunk_03_foliage_bare_%02d", 1, 4, tall=-1},
	{"oldforest_tree_03_trunk_01_foliage_summer_%02d", 1, 4, tall=-1},
	{"oldforest_tree_03_trunk_01_foliage_bare_%02d", 1, 4, tall=-1},
	{"oldforest_tree_03_trunk_02_foliage_summer_%02d", 1, 4, tall=-1},
	{"oldforest_tree_03_trunk_02_foliage_bare_%02d", 1, 4, tall=-1},
	{"oldforest_tree_03_trunk_03_foliage_summer_%02d", 1, 4, tall=-1},
	{"oldforest_tree_03_trunk_03_foliage_bare_%02d", 1, 4, tall=-1},
	{"small_oldforest_tree_02_trunk_01_foliage_summer_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_02_trunk_01_foliage_bare_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_02_trunk_02_foliage_summer_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_02_trunk_02_foliage_bare_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_02_trunk_03_foliage_summer_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_02_trunk_03_foliage_bare_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_01_trunk_01_foliage_summer_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_01_trunk_01_foliage_bare_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_01_trunk_02_foliage_summer_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_01_trunk_02_foliage_bare_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_01_trunk_03_foliage_summer_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_01_trunk_03_foliage_bare_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_03_trunk_01_foliage_summer_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_03_trunk_01_foliage_bare_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_03_trunk_02_foliage_summer_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_03_trunk_02_foliage_bare_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_03_trunk_03_foliage_summer_%02d", 1, 4, tall=0},
	{"small_oldforest_tree_03_trunk_03_foliage_bare_%02d", 1, 4, tall=0},
}

newEntity{
	define_as = "TREE",
	type = "wall", subtype = "dark_grass",
	name = "tree",
	image = "terrain/tree.png",
	display = '#', color=colors.LIGHT_GREEN, back_color={r=44,g=95,b=43},
	always_remember = true,
	can_pass = {pass_tree=1},
	does_block_move = true,
	block_sight = true,
	dig = "UNDERGROUND_FLOOR",
	nice_tiler = { method="replace", base={"TREE", 100, 1, 30}},
}
local base_image = loading_list.UNDERGROUND_FLOOR.image
for i = 1, 30 do
	newEntity(class:makeNewTrees({base="TREE", define_as = "TREE"..i, image = base_image}, treesdef, 3))
end

