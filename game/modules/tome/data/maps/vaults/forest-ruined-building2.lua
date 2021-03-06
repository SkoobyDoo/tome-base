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

setStatusAll{no_teleport=true, room_map = {can_open=true}}
roomCheck(function(room, zone, level, map)
	return zone.npc_list.__loaded_files["/data/general/npcs/plant.lua"] and zone.npc_list.__loaded_files["/data/general/npcs/swarm.lua"] --make sure the honey tree can summon
end)
border = 0
rotates = {"default", "90", "180", "270", "flipx", "flipy"}

defineTile('.', "FLOOR")
defineTile(',', "GRASS")
defineTile('#', "WALL")
defineTile('X', "TREE")
--defineTile('+', "DOOR")
defineTile('+', "DOOR", nil, nil, nil, {room_map = {can_open=true}})
defineTile('T', "GRASS", nil, {random_filter={name="honey tree", add_levels=4}})

return {
[[,,,,,,,,,,,,,,,,,,,,,]],
[[,#################X,,]],
[[,#....#.,..,..#.X.,X,]],
[[,#....+..,,,..+..,.#,]],
[[,######..,T,,.######,]],
[[,#....+.,,,,..+....#,]],
[[,#....#....,,.#....#,]],
[[,########+#+########,]],
[[,,,,,,,,,,,,,,,,,,,,,]],
}
