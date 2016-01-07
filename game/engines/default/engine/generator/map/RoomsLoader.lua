-- TE4 - T-Engine 4
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
local lom = require "lxp.lom"

--- Generator interface that can use rooms
-- @classmod engine.generator.map.RoomsLoader
module(..., package.seeall, class.make)

function _M:init(data)
	self.rooms = {}
	self.required_rooms = {}

	data.tunnel_change = data.tunnel_change or 30
	data.tunnel_random = data.tunnel_random or 10

	if data.rooms then for i, file in ipairs(data.rooms) do
		if type(file) == "table" then
			table.insert(self.rooms, {self:loadRoom(file[1]), chance_room=file[2]})
		else
			table.insert(self.rooms, self:loadRoom(file))
		end
	end end

	if data.required_rooms then for i, file in ipairs(data.required_rooms) do
		if type(file) == "table" then
			table.insert(self.required_rooms, {self:loadRoom(file[1]), chance_room=file[2]})
		else
			table.insert(self.required_rooms, self:loadRoom(file))
		end
	end end
end

local rooms_cache = {}
local tmxid = 1

function _M:loadLuaInEnv(g, file, code)
	local f, err
	if file then f, err = loadfile(file)
	else f, err = loadstring(code) end
	if not f and err then error(err) end
	setfenv(f, setmetatable(g, {__index=_G}))
	return f()
end

function _M:tmxLoadRoom(file, basefile)
	file = file:gsub("%.lua$", ".tmx")
	if not fs.exists(file) then return end
	print("Room generator using file", file)
	local f = fs.open(file, "r")
	local data = f:read(10485760)
	f:close()

	local g = {}
	local t = {}
	local openids, starts, ends = {}, {}, {}
	local map = lom.parse(data)
	local mapprops = {}
	if map:findOne("properties") then mapprops = map:findOne("properties"):findAllAttrs("property", "name", "value") end
	local w, h = tonumber(map.attr.width), tonumber(map.attr.height)
	local tw, th = tonumber(map.attr.tilewidth), tonumber(map.attr.tileheight)
	for _, tileset in ipairs(map:findAll("tileset")) do
		-- if tileset:findOne("properties") then for name, value in pairs(tileset:findOne("properties"):findAllAttrs("property", "name", "value")) do
		-- 	if name == "load_terrains" then
		-- 		local list = self:loadLuaInEnv(g, nil, "return "..value) or {}
		-- 		self.zone.grid_class:loadList(list, nil, self.grid_list, nil, self.grid_list.__loaded_files)
		-- 	elseif name == "load_traps" then
		-- 		local list = self:loadLuaInEnv(g, nil, "return "..value) or {}
		-- 		self.zone.trap_class:loadList(list, nil, self.trap_list, nil, self.trap_list.__loaded_files)
		-- 	elseif name == "load_objects" then
		-- 		local list = self:loadLuaInEnv(g, nil, "return "..value) or {}
		-- 		self.zone.object_class:loadList(list, nil, self.object_list, nil, self.object_list.__loaded_files)
		-- 	elseif name == "load_actors" then
		-- 		local list = self:loadLuaInEnv(g, nil, "return "..value) or {}
		-- 		self.zone.npc_class:loadList(list, nil, self.npc_list, nil, self.npc_list.__loaded_files)
		-- 	end
		-- end end

		local firstgid = tonumber(tileset.attr.firstgid)
		for _, tile in ipairs(tileset:findAll("tile")) do
			local tid = tonumber(tile.attr.id + firstgid)
			local id = tile:findOne("property", "name", "id")
			local data_id = tile:findOne("property", "name", "data_id")
			local custom = tile:findOne("property", "name", "custom")
			local open = tile:findOne("property", "name", "open")
			local is_start = tile:findOne("property", "name", "start")
			local is_end = tile:findOne("property", "name", "stop") or tile:findOne("property", "name", "end")
			if id then
				t[tid] = id.attr.value
			elseif data_id then
				t[tid] = self.data[data_id.attr.value]
			elseif custom then
				local ret = self:loadLuaInEnv(g, nil, "return "..custom.attr.value)
				t[tid] = ret
			end
			openids[tid] = open
			starts[tid] = is_start
			ends[tid] = is_end
		end
	end

	if mapprops.status_all then
		self.status_all = self:loadLuaInEnv(g, nil, "return "..mapprops.status_all) or {}
	end

	if mapprops.add_data then
		table.merge(self.level.data, self:loadLuaInEnv(g, nil, "return "..mapprops.add_data) or {}, true)
	end

	if mapprops.lua then
		self:loadLuaInEnv(g, nil, "return "..mapprops.lua)
	end

	local m = { w=w, h=h, room_map={} }

	if mapprops.prefered_location then
		m.prefered_location = self:loadLuaInEnv(g, nil, "return "..mapprops.prefered_location)
	end

	local function populate(i, j, c, tid)
		local ii, jj = i, j

		m[ii] = m[ii] or {}
		if type(c) == "string" then
			m[ii][jj] = c
		else
			m[ii][jj] = m[ii][jj] or {}
			table.update(m[ii][jj], c)
		end
	end

	for _, layer in ipairs(map:findAll("layer")) do
		local mapdata = layer:findOne("data")
		local layername = layer.attr.name:lower()
		if layername == "terrain" then layername = "grid" end

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
				populate(x, y, {[layername] = gid, can_open=openids[gid], is_start=starts[gid], is_end=ends[gid]}, gid)
				x = x + 1
				if x > w then x = 1 y = y + 1 end
			end
		elseif mapdata.attr.encoding == "csv" then
			local data = mapdata[1]:gsub("[^,0-9]", ""):split(",")
			local x, y = 1, 1
			for i, gid in ipairs(data) do
				gid = tonumber(gid)
				populate(x, y, {[layername] = gid, can_open=openids[gid], is_start=starts[gid], is_end=ends[gid]}, gid)
				x = x + 1
				if x > w then x = 1 y = y + 1 end
			end
		elseif not mapdata.attr.encoding then
			local data = mapdata:findAll("tile")
			local x, y = 1, 1
			for i, tile in ipairs(data) do
				local gid = tonumber(tile.attr.gid)
				populate(x, y, {[layername] = gid, can_open=openids[gid], is_start=starts[gid], is_end=ends[gid]}, gid)
				x = x + 1
				if x > w then x = 1 y = y + 1 end
			end
		end
	end

	for _, og in ipairs(map:findAll("objectgroup")) do
		for _, o in ipairs(map:findAll("object")) do
			local props = o:findOne("properties"):findAllAttrs("property", "name", "value")

			-- if og.attr.name:find("^addSpot") then
			-- 	local x, y, w, h = math.floor(tonumber(o.attr.x) / tw), math.floor(tonumber(o.attr.y) / th), math.floor(tonumber(o.attr.width) / tw), math.floor(tonumber(o.attr.height) / th)
			-- 	if props.start then m.startx = x m.starty = y end
			-- 	if props['end'] then m.endx = x m.endy = y end
			-- 	if props.type and props.subtype then
			-- 		for i = x, x + w do for j = y, y + h do
			-- 			local i, j = rotate_coords(i, j)
			-- 			g.addSpot({i, j}, props.type, props.subtype)
			-- 		end end
			-- 	end
			-- elseif og.attr.name:find("^addZone") then
			-- 	local x, y, w, h = math.floor(tonumber(o.attr.x) / tw), math.floor(tonumber(o.attr.y) / th), math.floor(tonumber(o.attr.width) / tw), math.floor(tonumber(o.attr.height) / th)
			-- 	if props.type and props.subtype then
			-- 		local i1, j2 = rotate_coords(x, y)
			-- 		local i2, j2 = rotate_coords(x + w, y + h)
			-- 		g.addZone({x, y, x + w, y + h}, props.type, props.subtype)
			-- 	end
			-- elseif og.attr.name:find("^attrs") then
			-- 	local x, y, w, h = math.floor(tonumber(o.attr.x) / tw), math.floor(tonumber(o.attr.y) / th), math.floor(tonumber(o.attr.width) / tw), math.floor(tonumber(o.attr.height) / th)
			-- 	for k, v in pairs(props) do
			-- 		for i = x, x + w do for j = y, y + h do
			-- 			local i, j = rotate_coords(i, j)
			-- 			self.add_attrs_later[#self.add_attrs_later+1] = {x=i, y=j, key=k, value=self:loadLuaInEnv(g, nil, "return "..v)}
			-- 			print("====", i, j, k)
			-- 		end end
			-- 	end
			-- end
			if og.attr.name:find("^room_map") then
				local x, y, w, h = math.floor(tonumber(o.attr.x) / tw), math.floor(tonumber(o.attr.y) / th), math.floor(tonumber(o.attr.width) / tw), math.floor(tonumber(o.attr.height) / th)
				for k, v in pairs(props) do
					for i = x, x + w do for j = y, y + h do
						m.room_map[i] = m.room_map[i] or {}
						m.room_map[i][j] = m.room_map[i][j] or {}
						table.merge(m.room_map[i][j], {[k]=self:loadLuaInEnv(g, nil, "return "..v)})
					end end
				end
			end
		end
	end

	print("[ROOM TMX MAP] size", m.w, m.h)

	local gen = function(gen, id)
		return { name="tmxroom"..tmxid.."-"..m.w.."x"..m.h, w=m.w, h=m.h, prefered_location=m.prefered_location, generator = function(self, x, y, is_lit)
			for i = 1, m.w do for j = 1, m.h do
				gen.map.room_map[i-1+x][j-1+y].room = id
				if is_lit then gen.map.lites(i-1+x, j-1+y, true) end

				local c = m[i][j]
				if c.can_open then
					gen.map.room_map[i-1+x][j-1+y].room = nil
					gen.map.room_map[i-1+x][j-1+y].can_open = true
				end
				if c.is_start then
					gen.forced_up = {x=i-1+x, y=j-1+y}
					gen.map.forced_up = {x=i-1+x, y=j-1+y}
					gen.map.room_map[i-1+x][j-1+y].special = "exit"
				end
				if c.is_end then
					gen.forced_down = {x=i-1+x, y=j-1+y}
					gen.map.forced_down = {x=i-1+x, y=j-1+y}
					gen.map.room_map[i-1+x][j-1+y].special = "exit"
				end
				print("===room", i,j, "::", c.grid, c.grid and t[c.grid])

				if c.grid then
					local g = gen:resolve(t[c.grid], nil, true)
					if g then
						if g.force_clone then g = g:clone() end
						g:resolve()
						g:resolve(nil, true)
						gen.map(i-1+x, j-1+y, Map.TERRAIN, g)
					print(" => ", g, g and g.name)
					end
				end
				if c.object then local d = t[c.object] if d then
					local e
					if type(d) == "string" then e = gen.zone:makeEntityByName(gen.level, "object", d)
					elseif type(d) == "table" and d.random_filter then e = gen.zone:makeEntity(gen.level, "object", d.random_filter, nil, true)
					else e = gen.zone:finishEntity(gen.level, "object", d)
					end
					if e then
						gen:roomMapAddEntity(i-1+x, j-1+y, "object", e)
						e.on_added_to_level = nil
					end
				end end
				if c.actor then local d = t[c.actor] if d then
					local e
					if type(d) == "string" then e = gen.zone:makeEntityByName(gen.level, "actor", d)
					elseif type(d) == "table" and d.random_filter then e = gen.zone:makeEntity(gen.level, "actor", d.random_filter, nil, true)
					else e = gen.zone:finishEntity(gen.level, "actor", d)
					end
					if e then
						gen:roomMapAddEntity(i-1+x, j-1+y, "actor", e)
						e.on_added_to_level = nil
					end
				end end
				if c.trap then local d = t[c.trap] if d then
					local e
					if type(d) == "string" then e = gen.zone:makeEntityByName(gen.level, "trap", d)
					elseif type(d) == "table" and d.random_filter then e = gen.zone:makeEntity(gen.level, "trap", d.random_filter, nil, true)
					else e = gen.zone:finishEntity(gen.level, "trap", d)
					end
					if e then
						gen:roomMapAddEntity(i-1+x, j-1+y, "trap", e)
						e.on_added_to_level = nil
					end
				end end
				if c.trigger then local d = t[c.trigger] if d then
					local e
					if type(d) == "string" then e = gen.zone:makeEntityByName(gen.level, "terrain", d)
					elseif type(d) == "table" and d.random_filter then e = gen.zone:makeEntity(gen.level, "terrain", d.random_filter, nil, true)
					else e = gen.zone:finishEntity(gen.level, "terrain", d)
					end
					if e then
						gen:roomMapAddEntity(i-1+x, j-1+y, "trigger", e)
						e.on_added_to_level = nil
					end
				end end

				if m.room_map[i] and m.room_map[i][j] then
					table.merge(gen.map.room_map[i-1+x][j-1+y], m.room_map[i][j])
				end
			end end
		end}
	end
	tmxid = tmxid + 1

	rooms_cache[basefile] = gen
	return gen
end

function _M:loadRoom(file)
	if rooms_cache[file] then return rooms_cache[file] end

	local filename = "/data/rooms/"..file..".lua"
	-- Found in the zone itself ?
	if file:find("^!") then filename = self.zone:getBaseName().."/rooms/"..file:sub(2)..".lua" end
	local tmxed = self:tmxLoadRoom(filename, file)
	if tmxed then return tmxed end

	local f, err = loadfile(filename)
	if not f and err then error(err) end
	setfenv(f, setmetatable({
		Map = require("engine.Map"),
	}, {__index=_G}))
	local ret, err = f()
	if not ret and err then error(err) end

	-- We got a room generator function, save it for later
	if type(ret) == "function" then
		print("loaded room generator",file,ret)
		rooms_cache[file] = ret
		return ret
	end

	-- Init the room with name and size
	local t = { name=file, w=ret[1]:len(), h=#ret }

	-- Read the room map
	for j, line in ipairs(ret) do
		local i = 1
		for c in line:gmatch(".") do
			t[i] = t[i] or {}
			t[i][j] = c
			i = i + 1
		end
	end
	print("loaded room",file,t.w,t.h)

	rooms_cache[file] = t
	return t
end

--- Easy way to make an irregular shapped room
function _M:makePod(x, y, radius, room_id, data, floor, wall)
	self.map(x, y, Map.TERRAIN, self:resolve(floor or '.'))
	self.map.room_map[x][y].room = room_id

	local lowest = {x=x, y=y}

	local noise = core.noise.new(1, data.hurst, data.lacunarity)

	local idx = 0
	local quadrant = function(i, j)
		local breakdist = radius
		local n = noise[data.noise](noise, data.zoom * idx / (radius * 4), data.octave)
		n = (n + 1) / 2
		breakdist = data.base_breakpoint * breakdist + ((1 - data.base_breakpoint) * breakdist * n)
		idx = idx + 1

		local l = line.new(lowest.x, lowest.y, i, j)
		local lx, ly = l()
		while lx do
			if core.fov.distance(lowest.x, lowest.y, lx, ly) >= breakdist then break end
			if self.map:isBound(lx, ly) then
				self.map(lx, ly, Map.TERRAIN, self:resolve(floor or '.'))
				self.map.room_map[lx][ly].room = room_id
			end
			lx, ly = l()
		end
	end
	local idx = 0
	for i = -radius + x, radius + x do
		quadrant(i, -radius + y)
	end
	for i = -radius + y, radius + y do
		quadrant(radius + x, i)
	end
	for i = -radius + x, radius + x do
		quadrant(i, radius + y)
	end
	for i = -radius + y, radius + y do
		quadrant(-radius + x, i)
	end

	for i = -radius + x, radius + x do for j = -radius + y, radius + y do
		local g1 = self.map.room_map[i-1] and self.map.room_map[i-1][j+1] and self.map.room_map[i-1][j+1].room == room_id
		local g2 = self.map.room_map[i] and self.map.room_map[i][j+1] and self.map.room_map[i][j+1].room == room_id
		local g3 = self.map.room_map[i+1] and self.map.room_map[i+1][j+1] and self.map.room_map[i+1][j+1].room == room_id
		local g4 = self.map.room_map[i-1] and self.map.room_map[i-1][j] and self.map.room_map[i-1][j].room == room_id
		local g6 = self.map.room_map[i+1] and self.map.room_map[i+1][j] and self.map.room_map[i+1][j].room == room_id
		local g7 = self.map.room_map[i-1] and self.map.room_map[i-1][j-1] and self.map.room_map[i-1][j-1].room == room_id
		local g8 = self.map.room_map[i] and self.map.room_map[i][j-1] and self.map.room_map[i][j-1].room == room_id
		local g9 = self.map.room_map[i+1] and self.map.room_map[i+1][j-1] and self.map.room_map[i+1][j-1].room == room_id

		if     not g8 and not g4 and not g6 and g2 then self.map(i, j, Map.TERRAIN, self:resolve(wall or '#')) self.map.room_map[i][j].room = nil
		elseif not g2 and not g4 and not g6 and g8 then self.map(i, j, Map.TERRAIN, self:resolve(wall or '#')) self.map.room_map[i][j].room = nil
		elseif not g6 and not g2 and not g8 and g4 then self.map(i, j, Map.TERRAIN, self:resolve(wall or '#')) self.map.room_map[i][j].room = nil
		elseif not g4 and not g2 and not g8 and g6 then self.map(i, j, Map.TERRAIN, self:resolve(wall or '#')) self.map.room_map[i][j].room = nil
		end
	end end

	return { id="podroom"..room_id, x=x, y=y, cx=x, cy=y }
end

--- Generates parse data for from an ascii def, for function room generators
function _M:roomParse(def)
	local room = { w=def[1]:len(), h=#def, spots={}, exits={}, special=def.special }

	-- Read the room map
	for j, line in ipairs(def) do
		local i = 1
		for c in line:gmatch(".") do
			room[i] = room[i] or {}

			if tonumber(c) then
				c = tonumber(c)
				room.spots[c] = room.spots[c] or {}
				room.spots[c][#room.spots[c]+1] = {x=i-1, y=j-1}
				c = def.numbers or '.'
			end
			if c == '!' then
				room.exits[#room.exits+1] = {x=i-1, y=j-1}
			end

			room[i][j] = c

			i = i + 1
		end
	end
	return room
end

--- Generates map data from an ascii def, for function room generators
function _M:roomFrom(id, x, y, is_lit, room)
	for i = 1, room.w do
		for j = 1, room.h do
			self.map.room_map[i-1+x][j-1+y].room = id
			local c = room[i][j]
			if c == '!' then
				self.map.room_map[i-1+x][j-1+y].room = nil
				self.map.room_map[i-1+x][j-1+y].can_open = true
				self.map(i-1+x, j-1+y, Map.TERRAIN, self:resolve('#'))
			else
				self.map(i-1+x, j-1+y, Map.TERRAIN, self:resolve(c))
			end
			if room.special then self.map.room_map[i-1+x][j-1+y].special = true end
			if is_lit then self.map.lites(i-1+x, j-1+y, true) end
		end
	end
end

--- Generates a room
function _M:roomGen(room, id, lev, old_lev)
	if type(room) == 'function' then
		print("room generator", room, "is making a room")
		room = room(self, id, lev, old_lev)
	end
	print("alloc", room.name)

	-- Sanity check
	if self.map.w - 2 - room.w < 2 or self.map.h - 2 - room.h < 2 then return false end

	return room
end

--- Place a room
function _M:roomPlace(room, id, x, y)
	local is_lit = rng.percent(self.data.lite_room_chance or 100)

	-- ok alloc it using the default generator or a specific one
	local cx, cy
	if room.generator then
		cx, cy = room:generator(x, y, is_lit)
	else
		for i = 1, room.w do
			for j = 1, room.h do
				self.map.room_map[i-1+x][j-1+y].room = id
				local c = room[i][j]
				if c == '!' then
					self.map.room_map[i-1+x][j-1+y].room = nil
					self.map.room_map[i-1+x][j-1+y].can_open = true
					self.map(i-1+x, j-1+y, Map.TERRAIN, self:resolve('#'))
				else
					self.map(i-1+x, j-1+y, Map.TERRAIN, self:resolve(c))
				end
				if is_lit then self.map.lites(i-1+x, j-1+y, true) end
			end
		end
	end
	print("room allocated at", x, y,"with center",math.floor(x+(room.w-1)/2), math.floor(y+(room.h-1)/2))
	cx = cx or math.floor(x+(room.w-1)/2)
	cy = cy or math.floor(y+(room.h-1)/2)
	return { id=id, x=x, y=y, cx=cx, cy=cy, room=room }
end

--- Make up a room
function _M:roomAlloc(room, id, lev, old_lev, add_check)
	room = self:roomGen(room, id, lev, old_lev)
	if not room then return end

	local prefered_location = room.prefered_location
	local tries = 100
	while tries > 0 do
		local ok = true
		local x, y
		if prefered_location then
			x, y = prefered_location(self.map)
			x, y = x - math.floor(room.w / 2), y - math.floor(room.h / 2)
			prefered_location = nil
		else
			x, y = rng.range(1, self.map.w - 2 - room.w), rng.range(1, self.map.h - 2 - room.h)
		end

		-- Do we stomp ?
		for i = 1, room.w do
			for j = 1, room.h do
				if self.map.room_map[i-1+x][j-1+y].room then ok = false break end
			end
			if not ok then break end
		end

		if ok and (not add_check or add_check(room, x, y)) then
			local res = self:roomPlace(room, id, x, y)
			if res then return res end
		end
		tries = tries - 1
	end
	return false
end

--- Random tunnel dir
function _M:randDir(sx, sy)
	local dirs = util.primaryDirs() --{4,6,8,2}
	return util.dirToCoord(dirs[rng.range(1, #dirs)], sx, sy)
end

--- Find the direction in which to tunnel
function _M:tunnelDir(x1, y1, x2, y2)
	-- HEX TODO ?
	local xdir = (x1 == x2) and 0 or ((x1 < x2) and 1 or -1)
	local ydir = (y1 == y2) and 0 or ((y1 < y2) and 1 or -1)
	if xdir ~= 0 and ydir ~= 0 then
		if rng.percent(50) then xdir = 0
		else ydir = 0
		end
	end
	return xdir, ydir
end

--- Marks a tunnel as a tunnel and the space behind it
function _M:markTunnel(x, y, xdir, ydir, id)
	-- Disable the many prints of tunnelling
	local print = function()end

	x, y = x - xdir, y - ydir
	local dir = util.coordToDir(xdir, ydir, x, y)
	local sides = util.dirSides(dir, x, y)
	local mark_dirs = {dir, sides.left, sides.right}
	for i, d in ipairs(mark_dirs) do
		local xd, yd = util.dirToCoord(d, x, y)
		if self.map:isBound(x+xd, y+yd) and not self.map.room_map[x+xd][y+yd].tunnel then self.map.room_map[x+xd][y+yd].tunnel = id print("mark tunnel", x+xd, y+yd , id) end
	end
	if not self.map.room_map[x][y].tunnel then self.map.room_map[x][y].tunnel = id print("mark tunnel", x, y , id) end
	self.map.room_map[x][y].real_tunnel = true
end

--- Can we create a door (will it lead anywhere)
function _M:canDoor(x, y)
	local open_spaces = {}
	for dir, coord in pairs(util.adjacentCoords(x, y)) do
		open_spaces[dir] = not self.map:checkEntity(coord[1], coord[2], Map.TERRAIN, "block_move")
	end

	-- Check the cardinal directions
	for i, dir in pairs(util.primaryDirs()) do
		local opposed_dir = util.opposedDir(dir, x, y)
		if open_spaces[dir] and open_spaces[opposed_dir] then
			local sides = util.dirSides(opposed_dir, x, y)
			-- HEX TODO: hex tiles should not use hard left/right, but this is hackish
			if util.isHex() then
				sides = table.clone(sides)
				sides.hard_left = nil
				sides.hard_right = nil
			end
			local blocked = true
			for _, check_dir in pairs(sides) do
				blocked = blocked and not open_spaces[check_dir]
			end
			if blocked then return true end
		end
	end
	return false
end

--- Tunnel from x1,y1 to x2,y2
function _M:tunnel(x1, y1, x2, y2, id, virtual)
	if x1 == x2 and y1 == y2 then return end
	-- Disable the many prints of tunnelling
	local print = function()end

	local xdir, ydir = self:tunnelDir(x1, y1, x2, y2)
	print("tunneling from",x1, y1, "to", x2, y2, "initial dir", xdir, ydir)

	local startx, starty = x1, y1
	local tun = {}

	local tries = 2000
	local no_move_tries = 0
	while tries > 0 do
		if rng.percent(self.data.tunnel_change) then
			if rng.percent(self.data.tunnel_random) then xdir, ydir = self:randDir(x1, x2)
			else xdir, ydir = self:tunnelDir(x1, y1, x2, y2)
			end
		end

		local nx, ny = x1 + xdir, y1 + ydir
		while true do
			if self.map:isBound(nx, ny) then break end

			if rng.percent(self.data.tunnel_random) then xdir, ydir = self:randDir(nx, ny)
			else xdir, ydir = self:tunnelDir(x1, y1, x2, y2)
			end
			nx, ny = x1 + xdir, y1 + ydir
		end
		print(feat, "try pos", nx, ny, "dir", util.coordToDir(xdir, ydir, nx, ny))

		if self.map.room_map[nx][ny].special then
			print(feat, "refuse special")
		elseif self.map.room_map[nx][ny].room then
			tun[#tun+1] = {nx,ny,false,true}
			x1, y1 = nx, ny
			print(feat, "accept room")
		elseif self.map.room_map[nx][ny].can_open ~= nil then
			if self.map.room_map[nx][ny].can_open then
				print(feat, "tunnel crossing can_open", nx,ny)
				for _, coord in pairs(util.adjacentCoords(nx, ny)) do
					if self.map:isBound(coord[1], coord[2]) and self.map.room_map[coord[1]][coord[2]].can_open then
						self.map.room_map[coord[1]][coord[2]].can_open = false
						print(feat, "forbidding crossing at ", coord[1], coord[2])
					end
				end
				tun[#tun+1] = {nx,ny,true}
				x1, y1 = nx, ny
				print(feat, "accept can_open")
			else
				print(feat, "reject can_open")
			end
		elseif self.map.room_map[nx][ny].tunnel then
			if self.map.room_map[nx][ny].tunnel ~= id or no_move_tries >= 15 then
				tun[#tun+1] = {nx,ny}
				x1, y1 = nx, ny
				print(feat, "accept tunnel", self.map.room_map[nx][ny].tunnel, id)
			else
				print(feat, "reject tunnel", self.map.room_map[nx][ny].tunnel, id)
			end
		else
			tun[#tun+1] = {nx,ny}
			x1, y1 = nx, ny
			print(feat, "accept normal")
		end

		if x1 == nx and y1 == ny then
			self:markTunnel(x1, y1, xdir, ydir, id)
			no_move_tries = 0
		else
			no_move_tries = no_move_tries + 1
		end

		if x1 == x2 and y1 == y2 then print(feat, "done") break end

		tries = tries - 1
	end

	local doors = {}
	for _, t in ipairs(tun) do
		local nx, ny = t[1], t[2]
		if t[3] and self.data.door then self.possible_doors[#self.possible_doors+1] = t end
		if not t[4] and not virtual then
			print("=======TUNN", nx, ny)
			self.map(nx, ny, Map.TERRAIN, self:resolve('=') or self:resolve('.'))
		end
	end
end

function _M:placeDoors(chance)
	-- Put doors where possible
	for _, t in ipairs(self.possible_doors) do
		local nx, ny = t[1], t[2]
		if rng.percent(chance) and self:canDoor(nx, ny) then
			self.map(nx, ny, Map.TERRAIN, self:resolve("door"))
		end
	end
end
