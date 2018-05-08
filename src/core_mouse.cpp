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
#include "types.h"
#include "display.h"
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "script.h"
#include "useshader.h"
extern SDL_Window *window;
}
#include "core_lua.hpp"

#include <renderer-moderngl/Renderer.hpp>

static int lua_get_mouse(lua_State *L)
{
	int x = 0, y = 0;
	int buttons = SDL_GetMouseState(&x, &y);

	lua_pushnumber(L, x / screen_zoom);
	lua_pushnumber(L, y / screen_zoom);
	lua_pushnumber(L, SDL_BUTTON(buttons));

	return 3;
}
static int lua_set_mouse(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	int y = luaL_checknumber(L, 2);
	SDL_WarpMouseInWindow(window, x * screen_zoom, y * screen_zoom);
	return 0;
}
extern int current_mousehandler;
static int lua_set_current_mousehandler(lua_State *L)
{
	refcleaner(&current_mousehandler);

	if (lua_isnil(L, 1))
		current_mousehandler = LUA_NOREF;
	else
		current_mousehandler = luaL_ref(L, LUA_REGISTRYINDEX);

	return 0;
}
static int lua_mouse_show(lua_State *L)
{
	SDL_ShowCursor(lua_toboolean(L, 1) ? TRUE : FALSE);
	return 0;
}

static int lua_is_touch_enabled(lua_State *L)
{
	lua_pushboolean(L, SDL_GetNumTouchDevices() > 0);
	return 1;
}

int mouse_cursor_s_ref = LUA_NOREF;
int mouse_cursor_down_s_ref = LUA_NOREF;
SDL_Surface *mouse_cursor_s = nullptr;
SDL_Surface *mouse_cursor_down_s = nullptr;
SDL_Cursor *mouse_cursor = nullptr;
SDL_Cursor *mouse_cursor_down = nullptr;
extern int mouse_cursor_ox, mouse_cursor_oy;
static int sdl_set_mouse_cursor(lua_State *L)
{
	mouse_cursor_ox = luaL_checknumber(L, 1);
	mouse_cursor_oy = luaL_checknumber(L, 2);

	/* Down */
	refcleaner(&mouse_cursor_down_s_ref);

	if (!lua_isnil(L, 4))
	{
		SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 4);
		mouse_cursor_down_s = *s;
		mouse_cursor_down_s_ref = luaL_ref(L, LUA_REGISTRYINDEX);

		if (mouse_cursor_down) { SDL_FreeCursor(mouse_cursor_down); mouse_cursor_down = nullptr; }
		mouse_cursor_down = SDL_CreateColorCursor(mouse_cursor_down_s, -mouse_cursor_ox, -mouse_cursor_oy);
		if (mouse_cursor_down) SDL_SetCursor(mouse_cursor_down);
	}

	/* Default */
	refcleaner(&mouse_cursor_s_ref);

	if (!lua_isnil(L, 3))
	{
		SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 3);
		mouse_cursor_s = *s;
		mouse_cursor_s_ref = luaL_ref(L, LUA_REGISTRYINDEX);

		if (mouse_cursor) { SDL_FreeCursor(mouse_cursor); mouse_cursor = NULL; }
		mouse_cursor = SDL_CreateColorCursor(mouse_cursor_s, -mouse_cursor_ox, -mouse_cursor_oy);
		if (mouse_cursor) SDL_SetCursor(mouse_cursor);
	}
	return 0;
}

extern int mousex, mousey;
static RendererGL *mouse_renderer = nullptr;
static DisplayObject *mouse_drag_do = nullptr;
static int mouse_drag_do_ref = LUA_NOREF;
static bool mouse_drag_set = false;
static int mouse_drag_w = 32, mouse_drag_h = 32;
static int sdl_set_mouse_cursor_drag(lua_State *L)
{
	if (lua_isnil(L, 1))
	{
		if (mouse_renderer) {
			mouse_renderer->clear();
		}
		mouse_drag_set = false;
		if (mouse_drag_do) {
			mouse_drag_do = nullptr;
			refcleaner(&mouse_drag_do_ref);
		}
	}
	else
	{
		mouse_drag_w = luaL_checknumber(L, 2);
		mouse_drag_h = luaL_checknumber(L, 3);

		if (!mouse_renderer) mouse_renderer = new RendererGL(VBOMode::STATIC);
		DisplayObject *c = userdata_to_DO(L, 1);
		lua_pushvalue(L, 1);
		mouse_drag_do_ref = luaL_ref(L, LUA_REGISTRYINDEX);
		mouse_drag_do = c;
		mouse_renderer->add(mouse_drag_do);
		mouse_drag_set = true;
	}
	return 0;
}

static int lua_set_mouse_relative(lua_State *L) {
	bool v = lua_toboolean(L, 1);
	SDL_SetRelativeMouseMode(v ? SDL_TRUE : SDL_FALSE);
	return 0;
}

static const struct luaL_Reg mouselib[] =
{
	{"setRelative", lua_set_mouse_relative},
	{"touchCapable", lua_is_touch_enabled},
	{"setMouseCursor", sdl_set_mouse_cursor},
	{"setMouseDrag", sdl_set_mouse_cursor_drag},
	{"show", lua_mouse_show},
	{"get", lua_get_mouse},
	{"set", lua_set_mouse},
	{"set_current_handler", lua_set_current_mousehandler},
	{NULL, NULL},
};

int luaopen_core_mouse(lua_State *L)
{
	luaL_openlib(L, "core.mouse", mouselib, 0);
	lua_settop(L, 0);
	return 1;
}

void core_mouse_close() {
	if (mouse_drag_do) {
		mouse_renderer->clear();
		mouse_drag_set = false;
		mouse_drag_do = nullptr;
		refcleaner(&mouse_drag_do_ref);
	}
}

void mouse_draw_drag() {
	if (!mouse_drag_set) return;

	int x = mousex;
	int y = mousey;
	int w = mouse_drag_w / 2;
	int h = mouse_drag_h / 2;

	mouse_renderer->translate(x - w, y - h, 0, false);
	mouse_renderer->toScreenSimple();
}
