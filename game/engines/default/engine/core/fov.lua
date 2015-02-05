-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2015 Nicolas Casalini
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

--------------------------------------------------------------------------
--------------------------------------------------------------------------
-- WARNING about all that code
-- It makes things way faster but makes it non-reentrant:
-- Do NOT call a FOV calc from withing a FOV calc
-- not that you'd want that anyway
--------------------------------------------------------------------------
--------------------------------------------------------------------------

require "engine.class"
local ffi = require "ffi"
local C = ffi.C

ffi.cdef[[
struct lua_fovcache
{
	bool *cache;
	int w, h;
};
void ffi_fov_new_cache(struct lua_fovcache *cache, int x, int y);
void ffi_fov_cache_free(struct lua_fovcache *cache);
void ffi_fov_cache_set(struct lua_fovcache *cache, int x, int y, bool opaque);
bool ffi_fov_cache_get(struct lua_fovcache *cache, int x, int y);


typedef struct
{
	int x, y, xy;
	int dmap_value;
	int sqdist, dist;
} seen_result_ffi;
void ffi_fov_calc_default_fov(int x, int y, int radius, struct lua_fovcache *cache, int w, int h);
bool ffi_fov_get_results(int *x, int *y, int *radius, int *dist);
]]

local rx, ry, rradius, rdist = ffi.new("int[1]"), ffi.new("int[1]"), ffi.new("int[1]"), ffi.new("int[1]")
local ffi_fov = function(cache, x, y, radius, w, h, fct)
	C.ffi_fov_calc_default_fov(x, y, radius, cache, w, h)
	local ok = C.ffi_fov_get_results(rx, ry, rradius, rdist)
	while ok do
		fct(tonumber(rx[0]), tonumber(ry[0]), tonumber(rradius[0]), tonumber(rdist[0]))
		ok = C.ffi_fov_get_results(rx, ry, rradius, rdist)
	end
end
local ffi_fov_iterator = function(cache, x, y, radius, w, h, fct)
	C.ffi_fov_calc_default_fov(x, y, radius, cache, w, h)
	return function()
		local ok = C.ffi_fov_get_results(rx, ry, rradius, rdist)
		if not ok then return nil end
		return tonumber(rx[0]), tonumber(ry[0]), tonumber(rradius[0]), tonumber(rdist[0])
	end
end

local fovcache
local fovcache_mt = {
	__gc = C.ffi_fov_cache_free,
	__index = {
		get = C.ffi_fov_cache_get,
		set = function(cache, x, y, v) C.ffi_fov_cache_set(cache, x, y, v and true or false) end,
		fov = ffi_fov,
	},
}
fovcache = ffi.metatype("struct lua_fovcache", fovcache_mt)

--- FFI enabled FOV code
local fov = core.fov
fov.C = C

fov.newCache2 = function(w, h)
	local cache = ffi.new("struct lua_fovcache")
	C.ffi_fov_new_cache(cache, w, h)
	return cache
end

fov.ffiFOV = ffi_fov
fov.ffiFOVIterator = ffi_fov_iterator

local p = fov.newCache2(100,100)
p:set(50,50,true)
p:set(30,50,true)
for i = 1, 1 do
for x, y, radius, dist in core.fov.ffiFOVIterator(p, 40, 50, 2, 100, 100) do
	-- print(x, y, radius, dist)
end
end

-- C.exit(0)
