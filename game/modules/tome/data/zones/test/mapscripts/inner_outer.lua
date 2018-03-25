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

local Tilemap = require "engine.tilemaps.Tilemap"
local WaveFunctionCollapse = require "engine.tilemaps.WaveFunctionCollapse"
local merge_order = {'.', '_', 'r', '+', '#', 'O', '=', ';', 'T'}

-- Water & trees layer
local wfcwater = WaveFunctionCollapse.new{
	mode="overlapping", async=true,
	sample=self:getFile("!wfctest2.tmx", "samples"),
	size={self.mapsize.w/3, self.mapsize.h},
	n=3, symmetry=8, periodic_out=true, periodic_in=true, has_foundation=false
}
-- Outer buildings
local wfcouter = WaveFunctionCollapse.new{
	mode="overlapping", async=true,
	sample=self:getFile("!wfctest.tmx", "samples"),
	size={self.mapsize.w/3, self.mapsize.h},
	n=3, symmetry=8, periodic_out=true, periodic_in=true, has_foundation=false
}
-- Inner buildings
local wfcinner = WaveFunctionCollapse.new{
	mode="overlapping", async=true,
	sample=self:getFile("!wfctest4.tmx", "samples"),
	size={self.mapsize.w*2/3, self.mapsize.h},
	n=3, symmetry=8, periodic_out=false, periodic_in=false, has_foundation=false
}

-- Wait for all generators to finish
if not WaveFunctionCollapse:waitAll(wfcinner, wfcwater, wfcouter) then print("[inner_outer] a WFC failed") return self:regenerate() end

-- Merge them all
local tm = Tilemap.new(self.mapsize)
wfcouter:merge(1, 1, wfcwater, merge_order)
if wfcouter:eliminateByFloodfill{'#', 'T'} < 400 then print("[inner_outer] outer is too small") return self:regenerate() end
if wfcinner:eliminateByFloodfill{'#', 'T'} < 400 then print("[inner_outer] inner is too small") return self:regenerate() end
tm:merge(1, 1, wfcouter, merge_order)
tm:merge(self.mapsize.w - wfcinner.data_w, 1, wfcinner, merge_order)

-- Find rooms
local rooms = tm:findGroupsOf{'r'}
tm:applyOnGroups(rooms, function(w, h, data, room, idx)
	print("ROOM", idx, "::" , unpack(tm:groupOuterRectangle(room)))
	for j = 1, #room.list do
		local jn = room.list[j]
		-- data[jn.y][jn.x] = tostring(idx)
	end
end)
tm:fillAll('.', 'r')
tm:fillAll()

-- Elimitate the rest
if tm:eliminateByFloodfill{'#', 'T'} < 400 then return self:regenerate() end
tm:printResult()
return tm:getResult(true)
