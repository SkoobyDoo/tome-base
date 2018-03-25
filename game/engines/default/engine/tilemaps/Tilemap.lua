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
local lom = require "lxp.lom"
local mime = require "mime"

--- Base class to generate map-like
-- @classmod engine.tilemaps.Tilemap
module(..., package.seeall, class.make)

function _M:init(size, fill_with)
	if size then
		self.data_w = size[1]
		self.data_h = size[2]
		if self.data_w and self.data_h then
			self.data = self:makeData(self.data_w, self.data_h, fill_with or ' ')
		end
	end
end

function _M:makeData(w, h, fill_with)
	local data = {}
	for y = 1, h do
		data[y] = {}
		for x = 1, w do
			data[y][x] = fill_with
		end
	end
	return data
end

--- Find all empty spaces (defaults to ' ') and fill them with a give char
function _M:fillAll(fill_with, empty_char)
	if not self.data then return end
	empty_char = empty_char or ' '
	fill_with = fill_with or '#'
	for y = 1, self.data_h do
		for x = 1, self.data_w do
			if self.data[y][x] == empty_char then
				self.data[y][x] = fill_with
			end
		end
	end
end

--- Used internally to load a tilemap from a tmx file
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
	return data, w, h
end

function _M:collapseToLineFormat(data)
	if not data then return nil end
	local ndata = {}
	for y = 1, #data do ndata[y] = table.concat(data[y]) end
	return ndata
end

--- Do we have results, or did we fail?
function _M:hasResult()
	return self.data and true or false
end

--- Return a list of groups of tiles that matches the given cond function
function _M:findGroups(cond)
	if not self.data then return {} end

	local fills = {}
	local opens = {}
	local list = {}
	for i = 1, self.data_w do
		opens[i] = {}
		for j = 1, self.data_h do
			if cond(self.data[j][i]) then
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
		print("[Tilemap] Floodfill group", i, #closed)
	end

	return groups
end

--- Return a list of groups of tiles representing each of the connected areas
function _M:findGroupsNotOf(wall)
	wall = table.reverse(wall)
	return self:findGroups(function(c) return not wall[c] end)
end

--- Return a list of groups of tiles representing each of the connected areas
function _M:findGroupsOf(floor)
	floor = table.reverse(floor)
	return self:findGroups(function(c) return floor[c] end)
end

--- Apply a custom method over the given groups, sorting them from bigger to smaller
-- It gives the groups in order of bigger to smaller
function _M:applyOnGroups(groups, fct)
	if not self.data then return end
	table.sort(groups, function(a,b) return #a.list > #b.list end)
	for id, group in ipairs(groups) do
		fct(self.data_w, self.data_h, self.data, group, id)
	end
end

--- Given a list of groups, eliminate them all
function _M:eliminateGroups(wall, groups)
	if not self.data then return end
	print("[Tilemap] Eleminating groups", #groups)
	for i = 1, #groups do
		print("[Tilemap] Eleminating group "..i.." of", #groups[i].list)
		for j = 1, #groups[i].list do
			local jn = groups[i].list[j]
			self.data[jn.y][jn.x] = wall
		end
	end
end

--- Simply destroy all connected groups except the biggest one
function _M:eliminateByFloodfill(walls)
	if not self.data then return 0 end
	local groups = self:findGroupsNotOf(walls)

	-- If nothing exists, regen
	if #groups == 0 then
		print("[Tilemap] Floodfill found nothing")
		return 0
	end

	-- Sort to find the biggest group
	table.sort(groups, function(a,b) return #a.list < #b.list end)
	local g = table.remove(groups)
	if g and #g.list > 0 then
		print("[Tilemap] Ok floodfill with main group size", #g.list)
		self:eliminateGroups(walls[1], groups)
		return #g.list
	else
		print("[Tilemap] Floodfill left nothing")
		return 0
	end
end

function _M:isInGroup(group, x, y)
	if not group.reverse then
		group.reverse = {}
		for j = 1, #group.list do
			local jn = group.list[j]
			group.reverse[jn.x] = group.reverse[jn.x] or {}
			group.reverse[jn.x][jn.y] = true
		end
	end
	return group.reverse[x] and group.reverse[x][y]
end
--[=[
--- Find the biggest rectangle that can fit fully in the given group
function _M:groupInnerRectangle(group)
	if #group.list == 0 then return nil end

	-- Make a matrix to work on
	local outrect = self:groupOuterRectangle(group)
	local m = self:makeData(outrect.w, outrect.h, 0)
	local matrix = self:makeData(outrect.w, outrect.h, false)
	for j = 1, #group.list do
		local jn = group.list[j]
		matrix[jn.y - outrect.y1 + 1][jn.x - outrect.x1 + 1] = true
	end

        for i = 1, outrect.w do
        	for j = 1, outrect.h do
        		m[j][i] = matrix[j][i] and (1 + m[j+1][i]) or 0
        	end
        end
                m[i][j]=matrix[i][j]=='1'?1+m[i][j+1]:0;
end

public int maximalRectangle(char[][] matrix) {
	int m = matrix.length;
	int n = m == 0 ? 0 : matrix[0].length;
	int[][] height = new int[m][n + 1];
 
	int maxArea = 0;
	for (int i = 0; i < m; i++) {
		for (int j = 0; j < n; j++) {
			if (matrix[i][j] == '0') {
				height[i][j] = 0;
			} else {
				height[i][j] = i == 0 ? 1 : height[i - 1][j] + 1;
			}
		}
	}
 
	for (int i = 0; i < m; i++) {
		int area = maxAreaInHist(height[i]);
		if (area > maxArea) {
			maxArea = area;
		}
	}
 
	return maxArea;
}
 
private int maxAreaInHist(int[] height) {
	Stack<Integer> stack = new Stack<Integer>();
 
	int i = 0;
	int max = 0;
 
	while (i < height.length) {
		if (stack.isEmpty() || height[stack.peek()] <= height[i]) {
			stack.push(i++);
		} else {
			int t = stack.pop();
			max = Math.max(max, height[t]
					* (stack.isEmpty() ? i : i - stack.peek() - 1));
		}
	}
 
	return max;
}

-- int maximalRectangle(vector<vector<char> > &matrix) {
--         if(matrix.size()==0 || matrix[0].size()==0)return 0;
--         vector<vector<int>>m(matrix.size()+1,vector<int>(matrix[0].size()+1,0));
--         for(int i=0;i<matrix.size();i++)
--             for(int j=matrix[0].size()-1;j>=0;j--)
--                 m[i][j]=matrix[i][j]=='1'?1+m[i][j+1]:0;
--         int max=0;
--         for(int i=0;i<matrix[0].size();i++){
--             int p=0;
--             vector<int>s;
--             while(p!=m.size()){
--                 if(s.empty() || m[p][i]>=m[s.back()][i])
--                     s.push_back(p++);
--                 else{
--                     int t=s.back();
--                     s.pop_back();
--                     max=std::max(max,m[t][i]*(s.empty()?p:p-s.back()-1));
--                 }
--             }
--         }
--         return max;
-- }
--]=]

--- Find the smallest rectangle that can fit around in the given group
function _M:groupOuterRectangle(group)
	local n = group.list[1]
	if not n then return end -- wtf?
	local x1, x2 = n.x, n.x
	local y1, y2 = n.y, n.y

	for j = 1, #group.list do
		local jn = group.list[j]
		if jn.x < x1 then x1 = jn.x end
		if jn.x > x2 then x2 = jn.x end
		if jn.y < y1 then y1 = jn.y end
		if jn.y > y2 then y2 = jn.y end
	end

	-- Debug
	-- for i = x1, x2 do for j = y1, y2 do
	-- 	if not self:isInGroup(group, i, j) then
	-- 		if self.data[j][i] == '#' then
	-- 			self.data[j][i] = 'T'
	-- 		end
	-- 	end
	-- end end

	return {x1=x1, y1=y1, x2=x2, y2=y2, w=x2 - x1 + 1, h=y2 - y1 + 1}
end

--- Get the results
-- @param is_array if true returns a table[][] of characters, if false a table[] of string lines
function _M:getResult(is_array)
	if not self.data then return nil end
	if is_array then return self.data end
	local data = {}
	for y = 1, self.data_h do data[y] = table.concat(self.data[y]) end
	return data
end

--- Debug function to print the result to the log
function _M:printResult()
	if not self.data then
		print("-------------")
		print("------------- Tilemap result")		
		return
	end
	print("------------- Tilemap result --[[")
	for _, line in ipairs(self:getResult()) do
		print(line)
	end
	print("]]-----------")
end

--- Merge and other Tilemap's data
function _M:merge(x, y, tm, char_order, empty_char)
	if not self.data or not tm.data then return end
	x = math.floor(x)
	y = math.floor(y)
	char_order = table.reverse(char_order or {})
	empty_char = empty_char or ' '
	if not tm.data then return end

	for i = 1, tm.data_w do
		for j = 1, tm.data_h do
			local si, sj = i + x - 1, j + y - 1
			if si >= 1 and si <= self.data_w and sj >= 1 and sj <= self.data_h then
				local c = tm.data[j][i]
				if c ~= empty_char then
					local sc = self.data[sj][si]
					local sc_o = char_order[sc] or 0
					local c_o = char_order[c] or 0

					if c_o >= sc_o then
						self.data[sj][si] = tm.data[j][i]
					end
				end
			end
		end
	end
end
