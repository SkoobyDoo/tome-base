/*
	TE4 - T-Engine 4
	Copyright (C) 2009 - 2017 Nicolas Casalini

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.

	Nicolas Casalini "DarkGod"
	darkgod@te4.org
*/

extern "C" {
#include "lua.h"
#include "types.h"
#include "lauxlib.h"
#include "lualib.h"
#include "refcleaner_clean.h"
}

#include "map/2d/Map2D.hpp"

#include <vector>
using namespace std;

static vector<int> refs_to_clean;

extern "C" void refcleaner(int ref) {
	if (ref == LUA_NOREF) return;
	// printf("[RefCleaner] adding ref %d to clean\n", ref);
	refs_to_clean.push_back(ref);
}

extern "C" void refcleaner_clean(lua_State *L) {
	map2d_clean_particles();

	if (refs_to_clean.size() == 0) return;
	// printf("[RefCleaner] cleaning %ld lua references\n", refs_to_clean.size());
	for (auto it : refs_to_clean) {
		luaL_unref(L, LUA_REGISTRYINDEX, it);
	}	
	refs_to_clean.clear();
}

extern "C" void refcleaner_reset() {
	map2d_clean_particles_reset();
	refs_to_clean.clear();
}
