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

require "engine.class"
local Map = require "engine.Map"
require "engine.Generator"
local RoomsLoader = require "engine.generator.map.RoomsLoader"

--- @classmod engine.generator.map.Roomer
module(..., package.seeall, class.inherit(engine.Generator, RoomsLoader))

function _M:init(zone, map, level, data)
	engine.Generator.init(self, zone, map, level)
	data.rooms = {"greater_vault"}
	self.data = data
	self.grid_list = zone.grid_list
	RoomsLoader.init(self, data)
end

function _M:generate(lev, old_lev)
	self.spots = {}

	local room = self:roomGen(self.rooms[1], 1, lev, old_lev)
	self:roomPlace(room, 1, 2, 2)

	for i = 0, self.map.w - 1 do for j = 0, self.map.h - 1 do
		if i < 2 or i >= 2 + room.w or j < 2 or j >= 2 + room.h then
			local g
			if self.level.data.subvaults_surroundings then g = self:resolve(self.level.data.subvaults_surroundings, nil, true)
			else g = self:resolve("subvault_wall") end
			self.map(i, j, Map.TERRAIN, g)
		end
	end end

	local possible_entrances = {}
	for i = 2, 2 + room.w do
		if self.map:checkEntity(i, 2, Map.TERRAIN, "is_door") then possible_entrances[#possible_entrances+1] = {x=i, y=1} end
		if self.map:checkEntity(i, 2 + room.h - 1, Map.TERRAIN, "is_door") then possible_entrances[#possible_entrances+1] = {x=i, y=2 + room.h} end
	end
	for j = 2, 2 + room.h do
		if self.map:checkEntity(2, j, Map.TERRAIN, "is_door") then possible_entrances[#possible_entrances+1] = {x=1, y=j} end
		if self.map:checkEntity(2 + room.w - 1, j, Map.TERRAIN, "is_door") then possible_entrances[#possible_entrances+1] = {x=2 + room.w, y=j} end
	end

	local sx, sy, ex, ey = 1, 2, 1, 2

	if #possible_entrances > 0 then
		local e = rng.table(possible_entrances)
		sx, sy = e.x, e.y
		ex, ey = e.x, e.y
	end

	self.map(sx, sy, Map.TERRAIN, self:resolve("subvault_up"))

	return sx, sy, ex, ey, spots
end
