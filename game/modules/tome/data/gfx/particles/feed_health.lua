-- ToME - Tales of Middle-Earth
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

base_size = 32

local tiles = math.ceil(math.sqrt(tx*tx+ty*ty))
local tx = tx * engine.Map.tile_w
local ty = ty * engine.Map.tile_h
local length = math.sqrt(tx*tx+ty*ty)
local direction = math.atan2(ty, tx)
local offsetLength = engine.Map.tile_w * 0.3

-- Populate the beam based on the forks
return { generator = function()
	local angle = direction
	local rightAngle = direction + math.rad(90)
	local offset = rng.range(-offsetLength, offsetLength)
	local r = rng.range(2, length)

	return {
		life = 5,
		size = rng.range(3, 5), sizev = -0.4, sizea = 0,

		x = r * math.cos(angle) + math.cos(rightAngle) * offset, xv = 0, xa = 0,
		y = r * math.sin(angle) + math.sin(rightAngle) * offset, yv = 0, ya = 0,
		dir = angle + math.rad(180), dirv = 0, dira = 0,
		vel = rng.range(0.3, 0.6), velv = 0, vela = 0,

		r = 196 / 255, rv = 0, ra = 0,
		g = 64 / 255, gv = 0, ga = 0,
		b = 64 / 255, bv = 0, ba = 0,
		a = rng.range(60, 120) / 255, av = 0, aa = 0,
	}
end, },
function(self)
	self.ps:emit(5*tiles)
end,
5*5*tiles
