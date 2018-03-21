/*
	TE4 - T-Engine 4
	Copyright (C) 2009 - 2018 Nicolas Casalini

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
#include "lauxlib.h"
#include "display.h"
#include "types.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "main.h"
#include "auxiliar.h"
#include "lua_externs.h"
}

#include <vector>
#include "clipper/clipper.hpp"

using namespace std;

class TE4Clipper {
private:
	ClipperLib::Clipper clpr;
	vector<ClipperLib::Path*> paths;
public:
	~TE4Clipper() {
		for (auto p : paths) delete p;
	}
	void add(ClipperLib::Path *path) {
		paths.push_back(path);
	}
	bool execute(ClipperLib::Paths &solution) {
		bool first = true;
		for (auto p : paths) {
			clpr.AddPath(*p, first ? ClipperLib::ptSubject : ClipperLib::ptClip , true);
			first = false;
		}
		return clpr.Execute(ClipperLib::ctUnion, solution, ClipperLib::pftEvenOdd, ClipperLib::pftNonZero);
	}
};

static int lua_clipper_clipper(lua_State *L) {
	TE4Clipper **v = (TE4Clipper**)lua_newuserdata(L, sizeof(TE4Clipper*));
	auxiliar_setclass(L, "clipper{clipper}", -1);
	*v = new TE4Clipper();
	return 1;
}

static int lua_clipper_clipper_free(lua_State *L) {
	TE4Clipper **clpr = (TE4Clipper**)auxiliar_checkclass(L, "clipper{clipper}", 1);
	delete *clpr;
	lua_pushnumber(L, 1);
	return 1;
}

static int lua_clipper_clipper_add(lua_State *L) {
	TE4Clipper **clpr = (TE4Clipper**)auxiliar_checkclass(L, "clipper{clipper}", 1);
	ClipperLib::Path *path = new ClipperLib::Path();
	for (int i = 1; i <= lua_objlen(L, 2); i++) {
		lua_rawgeti(L, 2, i);
		lua_rawgeti(L, -1, 1);
		lua_rawgeti(L, -2, 2);
		ClipperLib::cInt x = lua_tonumber(L, -2);
		ClipperLib::cInt y = lua_tonumber(L, -1);
		path->emplace_back(x, y);
		lua_pop(L, 3);
	}
	(*clpr)->add(path);
	return 0;
}

static int lua_clipper_clipper_execute(lua_State *L) {
	TE4Clipper **clpr = (TE4Clipper**)auxiliar_checkclass(L, "clipper{clipper}", 1);
	ClipperLib::Paths paths;
	if (!(*clpr)->execute(paths)) return 0;
	lua_newtable(L);
	int path_id = 1;
	for (auto &path : paths) {
		int p_id = 1;
		lua_newtable(L);
		for (auto &p : path) {
			lua_newtable(L);
			lua_pushnumber(L, p.X); lua_rawseti(L, -2, 1);
			lua_pushnumber(L, p.Y); lua_rawseti(L, -2, 2);
			lua_rawseti(L, -2, p_id++);
		}
		lua_rawseti(L, -2, path_id++);
	}
	return 1;
}

static const struct luaL_Reg clipperobj[] =
{
	{"__gc", lua_clipper_clipper_free},
	{"add", lua_clipper_clipper_add},
	{"execute", lua_clipper_clipper_execute},
	{NULL, NULL},
};

static const struct luaL_Reg clipperlib[] =
{
	{"clipper", lua_clipper_clipper},
	{NULL, NULL},
};

extern "C" int luaopen_clipper(lua_State *L)
{
	auxiliar_newclass(L, "clipper{clipper}", clipperobj);
	luaL_openlib(L, "core.clipper", clipperlib, 0);
	lua_settop(L, 0);
	return 1;
}
