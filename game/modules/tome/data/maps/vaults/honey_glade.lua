-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2017 Nicolas Casalini
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

setStatusAll{no_teleport=true, vault_only_door_open=true}
roomCheck(function(room, zone, level, map)
	return resolvers.current_level <= 25 and zone.npc_list.__loaded_files["/data/general/npcs/swarm.lua"] -- make sure the honey trees can summon
end)
specialList("actor", {
	"/data/general/npcs/bear.lua",
	"/data/general/npcs/plant.lua",
})
specialList("terrain", {
	"/data/general/grids/forest.lua",
}, true)
local Floor = data.floor or "GRASS"
defineTile('!', "ROCK_VAULT", nil, nil, nil, {room_map={special=false, room=false, can_open=true}})
defineTile(' ', Floor)
defineTile('+', "DOOR")
defineTile('X', "HARDTREE")
defineTile('^', Floor, nil, nil, {random_filter={add_levels=5}})
defineTile('#', Floor, nil, {random_filter={name="honey tree"}})
defineTile('q', Floor, {random_filter={add_levels=10, tome_mod="vault"}}, {random_filter={name="brown bear", add_levels=10}})
defineTile('Q', Floor, {random_filter={add_levels=20, tome_mod="vault"}}, {random_filter={name="grizzly bear", add_levels=20}})

startx = 2
starty = 10

rotates = {"default", "90", "180", "270", "flipx", "flipy"}

return {
[[XXXXXXXXXX]],
[[XXX   XXXX]],
[[XX #q# XXX]],
[[XX qQq XXX]],
[[XX #q# XXX]],
[[XXX   XXXX]],
[[XXXX XXXXX]],
[[XXXX   XXX]],
[[XXXXXX!XXX]],
[[XX^^^^ XXX]],
[[XX XXXXXXX]],
}
