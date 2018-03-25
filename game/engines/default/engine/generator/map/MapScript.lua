-- TE4 - T-Engine 4
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

require "engine.class"
local Map = require "engine.Map"
local RoomsLoader = require "engine.generator.map.RoomsLoader"
require "engine.Generator"

--- @classmod engine.generator.map.FromCustom
module(..., package.seeall, class.inherit(engine.Generator, RoomsLoader))

function _M:init(zone, map, level, data)
	engine.Generator.init(self, zone, map, level)
	self.data = data
	self.grid_list = zone.grid_list
	self.spots = {}
	self.mapsize = {self.map.w, self.map.h, w=self.map.w, h=self.map.h}

	RoomsLoader.init(self, data)
end


--- Resolve a filename, from /data/ /data-addon/ or subfodler of zonedir
function _M:getFile(file, folder)
	folder = folder or "maps"
	if file:prefix("/") then return file end
	-- Found in the zone itself ?
	if file:find("^!") then return self.zone:getBaseName().."/"..folder.."/"..file:sub(2) end

	local _, _, addon, rfile = file:find("^([^+]+)%+(.+)$")
	if addon and rfile then
		return "/data-"..addon.."/"..folder.."/"..rfile
	end
	return "/data/"..folder.."/"..file
end

function _M:regenerate()
	self.force_regen = true
end

function _M:custom(lev, old_lev)
	if self.data.mapscript then
		local file = self:getFile(self.data.mapscript..".lua", "mapscripts")
		local f, err = loadfile(file)
		if not f and err then error(err) end
		setfenv(f, setmetatable(env or {
			self = self,
			lev = lev,
			old_lev = old_lev,
			Tilemap = require "engine.tilemaps.Tilemap",
		}, {__index=_G}))
		return f()
	end
	if self.data.custom then
		return self.data.custom(self, lev, old_lev)
	end
	error("Generator FromCustom called without customization!")
end

function _M:generate(lev, old_lev)
	print("Generating FromCustom")
	self.force_regen = false
	local data = self:custom(lev, old_lev)
	if self.force_regen then return self:generate(lev, old_lev) end
	for i = 0, self.map.w - 1 do
		for j = 0, self.map.h - 1 do
			self.map(i, j, Map.TERRAIN, self:resolve(data[j+1][i+1] or '#'))
		end
	end

	return self:makeStairsInside(lev, old_lev, self.spots)
end

--- Create the stairs inside the level
function _M:makeStairsInside(lev, old_lev, spots)
	-- Put down stairs
	local dx, dy
	if lev < self.zone.max_level or self.data.force_last_stair then
		while true do
			dx, dy = rng.range(1, self.map.w - 1), rng.range(1, self.map.h - 1)
			if not self.map:checkEntity(dx, dy, Map.TERRAIN, "block_move") and not self.map.room_map[dx][dy].special then
				self.map(dx, dy, Map.TERRAIN, self:resolve(">"))
				self.map.room_map[dx][dy].special = "exit"
				break
			end
		end
	end

	-- Put up stairs
	local ux, uy
	while true do
		ux, uy = rng.range(1, self.map.w - 1), rng.range(1, self.map.h - 1)
		if not self.map:checkEntity(ux, uy, Map.TERRAIN, "block_move") and not self.map.room_map[ux][uy].special then
			self.map(ux, uy, Map.TERRAIN, self:resolve("<"))
			self.map.room_map[ux][uy].special = "exit"
			break
		end
	end

	return ux, uy, dx, dy, spots
end
