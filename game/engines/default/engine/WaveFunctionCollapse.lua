-- TE4 - T-Engine 4
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

require "engine.class"
local lom = require "lxp.lom"
local mime = require "mime"

--- Generate map-like data from samples using the WaveFunctionCollapse algorithm (in C++)
-- @classmod engine.WaveFunctionCollapse
module(..., package.seeall, class.make)

--- Run the algorithm
-- It will produce internal results which this class can then manipulate
-- If async is true in the parameters the generator will run in an asynchronous thread and you must call :waitCompute()
-- before using the results, this allows you to run multiple WFCs for later merging wihtout taking more time (if the user have enoguh CPUs obviously)
function _M:init(t)
	assert(t.mode == "overlapping", "bad WaveFunctionCollapse mode")
	assert(t.size, "WaveFunctionCollapse has no size")
	self.data_w = t.size[1]
	self.data_h = t.size[2]
	if t.mode == "overlapping" then
		if type(t.sample) == "string" then
			t.sample = self:tmxLoad(t.sample)
		end
		self:run(t)
	end
end

--- Used internally to load a sample from a tmx file
function _M:tmxLoad(file)
	local f = fs.open(file, "r") local data = f:read(10485760) f:close()
	local map = lom.parse(data)
	local mapprops = {}
	if map:findOne("properties") then mapprops = map:findOne("properties"):findAllAttrs("property", "name", "value") end
	self.props = mapprops

	local w, h = tonumber(map.attr.width), tonumber(map.attr.height)
	if mapprops.map_data then
		local params = self:loadLuaInEnv(g, nil, "return "..mapprops.map_data)
		table.merge(self.data, params, true)
	end

	local gids = {}

	for _, tileset in ipairs(map:findAll("tileset")) do
		local firstgid = tonumber(tileset.attr.firstgid)
		local has_tile = tileset:findOne("tile")
		for _, tile in ipairs(tileset:findAll("tile")) do
			local tileprops = {}
			if tile:findOne("properties") then tileprops = tile:findOne("properties"):findAllAttrs("property", "name", "value") end
			local gid = tonumber(tile.attr.id)
			gids[firstgid + gid] = {tid=tileprops.id or ' '}
		end
	end

	local data = {}
	for y = 1, h do
		data[y] = {}
		for x = 1, w do data[y][x] = ' ' end
	end

	local function populate(x, y, gid)
		if not gids[gid] then return end
		local g = gids[gid]
		data[y][x] = g.tid
	end

	for _, layer in ipairs(map:findAll("layer")) do
		local mapdata = layer:findOne("data")
		if mapdata.attr.encoding == "base64" then
			local b64 = mime.unb64(mapdata[1]:trim())
			local data
			if mapdata.attr.compression == "zlib" then data = zlib.decompress(b64)
			elseif not mapdata.attr.compression then data = b64
			else error("tmx map compression unsupported: "..mapdata.attr.compression)
			end
			local gid, i = nil, 1
			local x, y = 1, 1
			while i <= #data do
				gid, i = struct.unpack("<I4", data, i)				
				populate(x, y, gid)
				x = x + 1
				if x > w then x = 1 y = y + 1 end
			end
		elseif mapdata.attr.encoding == "csv" then
			local data = mapdata[1]:gsub("[^,0-9]", ""):split(",")
			local x, y = 1, 1
			for i, gid in ipairs(data) do
				gid = tonumber(gid)
				populate(x, y, gid)
				x = x + 1
				if x > w then x = 1 y = y + 1 end
			end
		elseif not mapdata.attr.encoding then
			local data = mapdata:findAll("tile")
			local x, y = 1, 1
			for i, tile in ipairs(data) do
				local gid = tonumber(tile.attr.gid)
				populate(x, y, gid)
				x = x + 1
				if x > w then x = 1 y = y + 1 end
			end
		end
	end
	for y = 1, h do	data[y] = table.concat(data[y]) end
	return data
end

--- Used internally to parse the results
function _M:parseResult(data)
	if not data then return end
	self.data = {}
	for y = 1, #data do
		local x = 1
		self.data[y] = {}
		for c in data[y]:gmatch('.') do
			self.data[y][x] = c
			x = x + 1
		end
	end
end

--- Called by the constructor to actaully start doing stuff
function _M:run(t)
	print("[WaveFunctionCollapse] running with parameter table:")
	table.print(t)
	if not t.async then
		local data = core.generator.wfc.overlapping(t.sample, t.size[1], t.size[2], t.n, t.symmetry, t.periodic_out, t.periodic_in, t.has_foundation)
		self:parseResult(data)
		return false
	else
		self.async_data = core.generator.wfc.asyncOverlapping(t.sample, t.size[1], t.size[2], t.n, t.symmetry, t.periodic_out, t.periodic_in, t.has_foundation)
		return true
	end
end

--- Do we have results, or did we fail?
function _M:hasResult()
	return self.data and true or false
end

--- Wait for computation to finish if in async mode, if not it just returns immediately
function _M:waitCompute()
	if not self.async_data then return end
	local data = self.async_data:wait()
	self.async_data = nil

	self:parseResult(data)
	return self:hasResult()
end

--- Wait for multiple WaveFunctionCollapse at once
-- Static
function _M:waitAll(...)
	local all_have_data = true
	for _, wfcasync in ipairs{...} do
		wfcasync:waitCompute()
		if not wfcasync:hasResult() then all_have_data = false end -- We cant break, we need to wait all the threads to not leave them dangling in the wind
	end
	return all_have_data
end

--- Return a list of groups of tiles representing each of the connected areas
function _M:findFloodfillGroups(wall)
	if type(wall) == "table" then local first = wall[1] wall = table.reverse(wall) wall.__first = first
	else wall = {[wall] = true, __first=wall} end

	local fills = {}
	local opens = {}
	local list = {}
	for i = 1, self.data_w do
		opens[i] = {}
		for j = 1, self.data_h do
			if not wall[self.data[j][i]] then
				opens[i][j] = #list+1
				list[#list+1] = {x=i, y=j}
			end
		end
	end

	local nbg = 0
	local function floodFill(x, y)
		nbg=nbg+1
		local q = {{x=x,y=y}}
		local closed = {}
		while #q > 0 do
			local n = table.remove(q, 1)
			if opens[n.x] and opens[n.x][n.y] then
				-- self.data[n.y][n.x] = string.char(string.byte('0') + nbg) -- Debug to visualize floodfill groups
				closed[#closed+1] = n
				list[opens[n.x][n.y]] = nil
				opens[n.x][n.y] = nil
				q[#q+1] = {x=n.x-1, y=n.y}
				q[#q+1] = {x=n.x, y=n.y+1}
				q[#q+1] = {x=n.x+1, y=n.y}
				q[#q+1] = {x=n.x, y=n.y-1}

				q[#q+1] = {x=n.x+1, y=n.y-1}
				q[#q+1] = {x=n.x+1, y=n.y+1}
				q[#q+1] = {x=n.x-1, y=n.y-1}
				q[#q+1] = {x=n.x-1, y=n.y+1}
			end
		end
		return closed
	end

	-- Process all open spaces
	local groups = {}
	while next(list) do
		local i, l = next(list)
		local closed = floodFill(l.x, l.y)
		groups[#groups+1] = {id=id, list=closed}
		print("[WaveFunctionCollapse] Floodfill group", i, #closed)
	end

	return groups, wall
end

--- Find groups by floodfill and apply a custom function over them
-- It gives the groups in order of bigger to smaller
function _M:applyOnFloodfillGroups(wall, fct)
	if not self.data then return end
	local groups = self:findFloodfillGroups(wall)
	table.sort(groups, function(a,b) return #a.list > #b.list end)
	for _, group in ipairs(groups) do
		fct(self.data_w, self.data_h, self.data, group)
	end
end

--- Given a list of groups, eliminate them all
function _M:eliminateGroups(wall, groups)
	print("[WaveFunctionCollapse] Eleminating groups", #groups)
	for i = 1, #groups do
		print("[WaveFunctionCollapse] Eleminating group "..i.." of", #groups[i].list)
		for j = 1, #groups[i].list do
			local jn = groups[i].list[j]
			self.data[jn.y][jn.x] = wall
		end
	end
end

--- Simply destroy all connected groups except the biggest one
function _M:eliminateByFloodfill(wall)
	local groups, wall = self:findFloodfillGroups(wall)

	-- If nothing exists, regen
	if #groups == 0 then
		print("[WaveFunctionCollapse] Floodfill found nothing")
		return 0
	end

	-- Sort to find the biggest group
	table.sort(groups, function(a,b) return #a.list < #b.list end)
	local g = table.remove(groups)
	if g and #g.list > 0 then
		print("[WaveFunctionCollapse] Ok floodfill with main group size", #g.list)
		self:eliminateGroups(wall.__first, groups)
		return #g.list
	else
		print("[WaveFunctionCollapse] Floodfill left nothing")
		return 0
	end
end

--- Get the results
-- @param is_array if true returns a table[][] of characters, if false a table[] of string lines
function _M:getResult(is_array)
	if is_array then return self.data end
	if not self.data then return nil end
	local data = {}
	for y = 1, self.data_h do data[y] = table.concat(self.data[y]) end
	return data
end

--- Debug function to print the result to the log
function _M:printResult()
	print("-------------")
	print("------------- WaveFunctionCollapse result")
	print("-----------[[")
	for _, line in ipairs(self:getResult()) do
		print(line)
	end
	print("]]-----------")
	print("-------------")
	print("-------------")
end

--- Merge and other WaveFunctionCollapse's data
function _M:merge(wfc, empty_char, char_order)
	char_order = table.reverse(char_order or {})
	empty_char = empty_char or ' '
	if not wfc.data then return end

	for i = 1, math.min(self.data_w, wfc.data_w) do
		for j = 1, math.min(self.data_h, wfc.data_h) do
			local c = wfc.data[j][i]
			if c ~= empty_char then
				local sc = self.data[j][i]
				local sc_o = char_order[sc] or 0
				local c_o = char_order[c] or 0

				if c_o >= sc_o then
					self.data[j][i] = wfc.data[j][i]
				end
			end
		end
	end
end
