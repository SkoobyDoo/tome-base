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
#include "script.h"
#include "useshader.h"
#include "core_lua.h"
extern SDL_Window *window;
}

extern int current_gamepadhandler;
static int lua_set_current_gamepadhandler(lua_State *L)
{
	refcleaner(&current_gamepadhandler);

	if (lua_isnil(L, 1))
		current_gamepadhandler = LUA_NOREF;
	else
		current_gamepadhandler = luaL_ref(L, LUA_REGISTRYINDEX);

	return 0;
}

static int lua_is_gamepad_enabled(lua_State *L)
{
	if (!SDL_NumJoysticks()) return 0;
	const char *str = SDL_JoystickNameForIndex(0);
	lua_pushstring(L, str);
	return 1;
}

static const struct luaL_Reg gamepadlib[] =
{
	{"gamepadCapable", lua_is_gamepad_enabled},
	{"set_current_handler", lua_set_current_gamepadhandler},
	{NULL, NULL},
};

int luaopen_core_gamepad(lua_State *L)
{
	luaL_openlib(L, "core.gamepad", gamepadlib, 0);
	lua_settop(L, 0);
	return 1;
}
