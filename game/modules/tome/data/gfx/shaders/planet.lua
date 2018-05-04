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

return {
	frag = "planet",
	args = {
		vectors = { texture = 0 },
		planet_texture = { texture = 1 },
		clouds_texture = { texture = 2 },
		rotate_angle = rotate_angle or math.rad(22),
		light_angle = light_angle or math.rad(180),
		planet_time_scale = planet_time_scale or 100000,
		clouds_time_scale = clouds_time_scale or 70000,
	},
	clone = true,
}
