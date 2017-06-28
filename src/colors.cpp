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
#include "display.h"
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
}
#include "colors.hpp"

unordered_map<string, Color> Color::all_colors;

Color::Color(float r, float g, float b, float a) {
	rgba = {r, g, b, a};
}

vec4 Color::get1() {
	return rgba;
}

vec4 Color::get256() {
	return {rgba.r * 255, rgba.g * 255, rgba.b * 255, rgba.a * 255};
}

void Color::resetAll() {
	all_colors.clear();
}

void Color::define256(const char *name, int r, int g, int b, int a) {
	all_colors.insert({name, {(float)r / 255, (float)g / 255, (float)b / 255, (float)a / 255}});
}

Color *Color::find(string &name) {
	auto it = all_colors.find(name);
	// printf("[CCOLOR] finding %s : %s\n", name.c_str(), it == all_colors.end() ? "unfound" : "found");
	if (it == all_colors.end()) return NULL;
	return &it->second;
}

static int lua_reset_colors(lua_State *L) {
	Color::resetAll();
	return 0;
}

static int lua_define_color256(lua_State *L) {
	const char *name = luaL_checkstring(L, 1);
	int r = luaL_checknumber(L, 2);
	int g = luaL_checknumber(L, 3);
	int b = luaL_checknumber(L, 4);
	int a = luaL_checknumber(L, 5);
	Color::define256(name, r, g, b, a);
	return 0;
}

const luaL_Reg colorslib[] = {
	{"reset", lua_reset_colors},
	{"define256", lua_define_color256},
	{NULL, NULL}
};

extern "C" int luaopen_colors (lua_State *L);
int luaopen_colors(lua_State *L)
{
	luaL_openlib(L, "core.colors", colorslib, 0);
	lua_pop(L, 1);
	return 1;
}
