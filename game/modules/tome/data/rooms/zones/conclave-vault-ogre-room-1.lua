-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2014 Nicolas Casalini
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

local def = {
[[#!!!!!!!!!!#]],
[[!..........!]],
[[!.#.#..#.#.!]],
[[!.#1#..#1#.!]],
[[!.###..###.!]],
[[!..........!]],
[[!.###..###.!]],
[[!.#1#..#1#.!]],
[[!.#.#..#.#.!]],
[[!..........!]],
[[#!!!!!!!!!!#]],
}

return function(gen, id)
	local room = gen:roomParse(def)
	return { name="conclave-ogre"..room.w.."x"..room.h, w=room.w, h=room.h, generator = function(self, x, y, is_lit)

		gen:roomFrom(id, x, y, is_lit, room)

		for _, spot in ipairs(room.spots[1]) do
			local e = gen.zone:makeEntity(gen.level, "actor", {type="giant", subtype="ogre"}, nil, true)
			if e then gen:roomMapAddEntity(x + spot.x, y + spot.y, "actor", e) end
		end
	end}
end
