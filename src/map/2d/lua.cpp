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
#include <math.h>
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "map.h"
#include "main.h"
#include "script.h"
#include "useshader.h"
#include "assert.h"
}

#include "map/2d/Map2D.hpp"
#include "renderer-moderngl/renderer-lua.hpp"

/*************************************************************************
 ** MapObject wrapper
 *************************************************************************/
static int map_object_new(lua_State *L)
{
	long uid = luaL_checknumber(L, 1);
	int nb_textures = luaL_checknumber(L, 2);
	int i;

	MapObject **pobj = (MapObject**)lua_newuserdata(L, sizeof(MapObject*));
	auxiliar_setclass(L, "core{mapobj2d}", -1);
	*pobj = new MapObject(uid, nb_textures,
		lua_toboolean(L, 3),
		lua_toboolean(L, 4),
		lua_toboolean(L, 5),
		{ luaL_checknumber(L, 6), luaL_checknumber(L, 7) },
		{ luaL_checknumber(L, 8), luaL_checknumber(L, 9) },
		luaL_checknumber(L, 10)
	);

	return 1;
}

static int map_object_free(lua_State *L)
{
	MapObject **obj = (MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	delete *obj;
	lua_pushnumber(L, 1);
	return 1;
}

static int map_object_cb(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);

	if (lua_isfunction(L, 2)) {
		lua_pushvalue(L, 2);
		obj->setCallback(luaL_ref(L, LUA_REGISTRYINDEX));
	}
	return 0;
}

static int map_object_chain(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	MapObject *obj2 = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 2);
	
	lua_pushvalue(L, 2);
	obj->chain(obj2, luaL_ref(L, LUA_REGISTRYINDEX));
	return 0;
}

static int map_object_hide(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	obj->setHidden(true);
	return 0;
}

static int map_object_on_seen(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	if (lua_isboolean(L, 2)) {
		obj->setSeen(lua_toboolean(L, 2));
	}
	lua_pushboolean(L, obj->isSeen());
	return 1;
}

static int map_object_texture(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	int i = luaL_checknumber(L, 2);
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 3);

	vec4 coords = {0, 0, lua_tonumber(L, 5), lua_tonumber(L, 6)};
	if (lua_isnumber(L, 7)) {
		coords.x = lua_tonumber(L, 7);
		coords.y = lua_tonumber(L, 8);
	}

	lua_pushvalue(L, 3); // Get the texture
	obj->setTexture(i, t->tex, luaL_ref(L, LUA_REGISTRYINDEX), coords);
	return 0;
}

static int map_object_set_do(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	if (!lua_isnil(L, 2)) {
		DisplayObject *v = userdata_to_DO(__FUNCTION__, L, 2);
		obj->setDisplayObject(v, luaL_ref(L, LUA_REGISTRYINDEX));
	} else {
		obj->setDisplayObject(nullptr, LUA_NOREF);
	}
	return 0;
}

static int map_object_shader(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	if (!lua_isnil(L, 2)) {
		shader_type *s = (shader_type*)lua_touserdata(L, 2);
		lua_pushvalue(L, 2);
		obj->setShader(s, luaL_ref(L, LUA_REGISTRYINDEX));
	} else {
		obj->setShader(nullptr, LUA_NOREF);
	}
	return 0;
}

static int map_object_tint(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	obj->setTint({luaL_checknumber(L, 2), luaL_checknumber(L, 3), luaL_checknumber(L, 4)});
	return 0;
}

static int map_object_minimap(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	obj->setMinimapColor({luaL_checknumber(L, 2), luaL_checknumber(L, 3), luaL_checknumber(L, 4)});
	return 0;
}

static int map_object_flip_x(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	obj->flipX(lua_toboolean(L, 2));
	return 0;
}

static int map_object_flip_y(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	obj->flipY(lua_toboolean(L, 2));
	return 0;
}

static int map_object_print(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	return 0;
}

static int map_object_invalid(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	obj->invalidate();
	return 0;
}


static int map_object_set_anim(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);

	// obj->anim_step = luaL_checknumber(L, 2);
	// obj->anim_max = luaL_checknumber(L, 3);
	// obj->anim_speed = luaL_checknumber(L, 4);
	// obj->anim_loop = luaL_checknumber(L, 5);
	return 0;
}

static int map_object_reset_move_anim(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	// obj->move_max = 0;
	// obj->animdx = obj->animdy = 0;
	return 0;
}

static int map_object_set_move_anim(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);

	// lua_is_hex(L);
	// int is_hex = luaL_checknumber(L, -1);

	// // If at rest use starting point
	// if (!obj->move_max)
	// {
	// 	int ox = luaL_checknumber(L, 2);
	// 	int oy = luaL_checknumber(L, 3);
	// 	obj->oldx = ox;
	// 	obj->oldy = oy + 0.5f*(ox & is_hex);
	// }
	// // If already moving, compute starting point
	// else
	// {
	// 	int ox = luaL_checknumber(L, 2);
	// 	int oy = luaL_checknumber(L, 3);
	// 	obj->oldx = obj->animdx + ox;
	// 	obj->oldy = obj->animdy + oy + 0.5f*(ox & is_hex);
	// }
	// obj->move_step = 0;
	// obj->move_max = luaL_checknumber(L, 6);
	// obj->move_blur = lua_tonumber(L, 7); // defaults to 0
	// obj->move_twitch_dir = lua_tonumber(L, 8); // defaults to 0 (which is equivalent to up or 8)
	// obj->move_twitch = lua_tonumber(L, 9); // defaults to 0
	// // obj->animdx = obj->animdx - ((float)obj->cur_x - obj->oldx);
	// // obj->animdy = obj->animdy - ((float)obj->cur_y - obj->oldy);

	// // Invalidate layers upon which we exist, so that the animation can actually play
	// if (lua_isuserdata(L, 10) && lua_istable(L, 11)) {
	// 	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map2d}", 10);
	// 	lua_pushnil(L);
	// 	while (lua_next(L, 11) != 0) {
	// 		int z = lua_tonumber(L, -1) - 1;
	// 		z = (z < 0) ? 0 : ((z >= map->zdepth) ? map->zdepth : z);
	// 		lua_pop(L, 1);
	// 	}		
	// 	map->changed = true;
	// }
	
	return 0;
}

static int map_object_get_move_anim(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	// map_type *map = (map_type*)auxiliar_checkclass(L, "core{map2d}", 2);

	lua_pushnumber(L, 0);lua_pushnumber(L, 0);return 2;
// 	int i = luaL_checknumber(L, 3);
// 	int j = luaL_checknumber(L, 4);

// 	float mapdx = 0, mapdy = 0;
// 	if (map->move_max)
// 	{
// 		float adx = (float)map->mx - map->oldmx;
// 		float ady = (float)map->my - map->oldmy;
// 		mapdx = -(adx * map->move_step / (float)map->move_max - adx);
// 		mapdy = -(ady * map->move_step / (float)map->move_max - ady);
// 	}

// 	if (!obj->move_max) // || obj->display_last == DL_NONE)
// 	{
// //		printf("==== GET %f x %f\n", mapdx, mapdy);
// 		lua_pushnumber(L, mapdx);
// 		lua_pushnumber(L, mapdy);
// 	}
// 	else
// 	{
// //		printf("==== GET %f x %f :: %f x %f\n", mapdx, mapdy,obj->animdx,obj->animdy);
// 		lua_pushnumber(L, mapdx + obj->animdx);
// 		lua_pushnumber(L, mapdy + obj->animdy);
// 	}
// 	return 2;
}

static int map_object_get_world_pos(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	lua_pushnumber(L, 0);lua_pushnumber(L, 0);return 2;
	// lua_pushnumber(L, obj->world_x);
	// lua_pushnumber(L, obj->world_y);
	return 2;
}

static int map_object_is_valid(lua_State *L)
{
	MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", 1);
	lua_pushboolean(L, obj->isValid());
	return 1;
}

static int map_objects_to_displayobject(lua_State *L) {
	int w = luaL_checknumber(L, 1);
	int h = luaL_checknumber(L, 2);
	// bool allow_cb = lua_toboolean(L, 3);
	// bool allow_shader = lua_toboolean(L, 4);

	MapObjectRenderer *mor = new MapObjectRenderer(w, h);
	// to->setLuaState(L);

	int moid = 6;
	while (lua_isuserdata(L, moid))
	{
		MapObject *obj = *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", moid);
		lua_pushvalue(L, -1);
		int ref = luaL_ref(L, LUA_REGISTRYINDEX);

		mor->addMapObject(obj, ref);
		moid++;
	}

	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	*v = mor;
	auxiliar_setclass(L, "gl{mapobj2drender}", -1);
	return 1;
}


/*************************************************************************
 ** Map2D wrapper
 *************************************************************************/
static int map_new(lua_State *L)
{
	int w = luaL_checknumber(L, 1);
	int h = luaL_checknumber(L, 2);
	int mx = luaL_checknumber(L, 3);
	int my = luaL_checknumber(L, 4);
	int mwidth = luaL_checknumber(L, 5);
	int mheight = luaL_checknumber(L, 6);
	int tile_w = luaL_checknumber(L, 7);
	int tile_h = luaL_checknumber(L, 8);
	int zdepth = luaL_checknumber(L, 9);

	Map2D **pmap = (Map2D**)lua_newuserdata(L, sizeof(Map2D*));
	auxiliar_setclass(L, "core{map2d}", -1);
	*pmap = new Map2D(zdepth, w, h, tile_w, tile_h);
	return 1;
}

static int map_free(lua_State *L)
{
	Map2D **map = (Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	delete *map;

	lua_pushnumber(L, 1);
	return 1;
}

static int map_define_grid_lines(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	// int size = luaL_checknumber(L, 2);
	// if (!size) {
	// 	if (map->grid_lines_renderer) delete map->grid_lines_renderer;
	// 	if (map->grid_lines) delete map->grid_lines;
	// 	map->grid_lines_renderer = NULL;
	// 	map->grid_lines = NULL;
	// 	map->nb_grid_lines_vertices = 0;
	// 	return 0;
	// }

	// float r = luaL_checknumber(L, 3);
	// float g = luaL_checknumber(L, 4);
	// float b = luaL_checknumber(L, 5);
	// float a = luaL_checknumber(L, 6);

	// if (map->grid_lines_renderer) delete map->grid_lines_renderer;
	// if (map->grid_lines) delete map->grid_lines;

	// int mwidth = map->mwidth;
	// int mheight = map->mheight;
	// int tile_w = map->tile_w;
	// int tile_h = map->tile_h;
	// int grid_w = 1 + mwidth;
	// int grid_h = 1 + mheight;
	// map->nb_grid_lines_vertices = grid_w + grid_h;
	// map->grid_lines = new DORVertexes();
	// map->grid_lines->setTexture(gl_tex_white, LUA_NOREF);
	// map->grid_lines_renderer = new RendererGL(VBOMode::STATIC);
	// map->grid_lines_renderer->add(map->grid_lines);

	// int vi = 0, ci = 0, ti = 0, i;
	// // Verticals
	// for (i = 0; i < grid_w; i++) {
	// 	map->grid_lines->addQuad(
	// 		i * tile_w - size / 2, 0, 0, 0,
	// 		i * tile_w + size / 2, 0, 1, 0,
	// 		i * tile_w + size / 2, mheight * tile_h, 1, 1,
	// 		i * tile_w - size / 2, mheight * tile_h, 0, 1,
	// 		r, g, b, a
	// 	);
	// }
	// // Horizontals
	// for (i = 0; i < grid_h; i++) {
	// 	map->grid_lines->addQuad(
	// 		0,		 i * tile_h - size / 2, 0, 0,
	// 		0,		 i * tile_h + size / 2, 1, 0,
	// 		mwidth * tile_w, i * tile_h + size / 2, 1, 1,
	// 		mwidth * tile_w, i * tile_h - size / 2, 0, 1,
	// 		r, g, b, a
	// 	);
	// }
	return 0;
}

static int map_set_z_callback(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	// int z = luaL_checknumber(L, 2);

	// if (map->z_callbacks[z] != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, map->z_callbacks[z]);

	// if (lua_isfunction(L, 3)) {
	// 	lua_pushvalue(L, 3);
	// 	map->z_callbacks[z] = luaL_ref(L, LUA_REGISTRYINDEX);
	// }
	return 0;
}

static int map_set_sort_start(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->setZSortStart(lua_tonumber(L, 2));
	return 0;
}


static int map_set_tint(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->setTint({lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5)});
	return 0;
}

static int map_set_zoom(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	// int tile_w = luaL_checknumber(L, 2);
	// int tile_h = luaL_checknumber(L, 3);
	// int mwidth = luaL_checknumber(L, 4);
	// int mheight = luaL_checknumber(L, 5);
	// map->tile_w = tile_w;
	// map->tile_h = tile_h;
	// map->mwidth = mwidth;
	// map->mheight = mheight;
	// map->seen_changed = true;
	// setup_seens_texture(map);
	return 0;
}

static int map_set_default_shader(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	if (!lua_isnil(L, 2)) {
		shader_type *s = (shader_type*)lua_touserdata(L, 2);
		lua_pushvalue(L, 2);
		map->setDefaultShader(s, luaL_ref(L, LUA_REGISTRYINDEX));
	} else {
		map->setDefaultShader(nullptr, LUA_NOREF);
	}
	return 0;
}

static int map_set_obscure(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->setObscure({lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5)});
	return 0;
}

static int map_set_shown(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->setShown({lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5)});
	return 0;
}

static int map_set_grid(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	uint32_t x = luaL_checknumber(L, 2);
	uint32_t y = luaL_checknumber(L, 3);
	vec2 size = map->getSize();
	if (x < 0 || y < 0 || x >= size.x || y >= size.y) return 0;

	for (uint8_t z = 0; z < map->getDepth(); z++) {
		lua_pushnumber(L, z + 1);
		lua_gettable(L, 4); // Access the table of mos for this spot
		MapObject *mo = lua_isnoneornil(L, -1) ? nullptr : *(MapObject**)auxiliar_checkclass(L, "core{mapobj2d}", -1);
		int ref = LUA_NOREF;
		if (mo) {
			lua_pushvalue(L, -1);
			luaL_ref(L, LUA_REGISTRYINDEX);
		}
		map->set(z, x, y, mo, ref);

		// Remove the mo and get the next
		lua_pop(L, 1);
	}

	// Pop the mo list
	lua_pop(L, 1);
	return 0;
}

static int map_set_seen(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	int x = lua_tonumber(L, 2);
	int y = lua_tonumber(L, 3);
	float v = lua_tonumber(L, 4);

	map->setSeen(x, y, v);
	return 0;
}

static int map_set_remember(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	int x = lua_tonumber(L, 2);
	int y = lua_tonumber(L, 3);
	bool v = lua_toboolean(L, 4);

	map->setRemember(x, y, v);
	return 0;
}

static int map_set_lite(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	int x = lua_tonumber(L, 2);
	int y = lua_tonumber(L, 3);
	bool v = lua_toboolean(L, 4);

	map->setLite(x, y, v);
	return 0;
}

static int map_set_important(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	int x = lua_tonumber(L, 2);
	int y = lua_tonumber(L, 3);
	bool v = lua_toboolean(L, 4);

	map->setImportant(x, y, v);
	return 0;
}

static int map_clean_seen(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->cleanSeen(0);
	return 0;
}

static int map_clean_remember(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->cleanRemember(0);
	return 0;
}

static int map_clean_lite(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->cleanLite(0);
	return 0;
}

static int map_get_seensinfo(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	vec2 tile = map->getTileSize();
	// lua_pushnumber(L, map->tile_w);
	// lua_pushnumber(L, map->tile_h);
	// lua_pushnumber(L, map->seensinfo_w);
	// lua_pushnumber(L, map->seensinfo_h);
	lua_pushnumber(L, tile.x);
	lua_pushnumber(L, tile.y);
	lua_pushnumber(L, 0);
	lua_pushnumber(L, 0);
	return 4;
}

// static void map_update_seen_texture(map_type *map)
// {
	// tglBindTexture(GL_TEXTURE_2D, map->seens_texture);
	// gl_c_texture = -1;

	// int mx = map->used_mx;
	// int my = map->used_my;
	// GLubyte *seens = map->seens_map;
	// int ptr = 0;
	// int f = (map->is_hex & 1);
	// int ii, jj;
	// map->seensinfo_w = map->w+10;
	// map->seensinfo_h = map->h+10;

	// for (jj = 0; jj < map->h+10; jj++)
	// {
	// 	for (ii = 0; ii < map->w+10; ii++)
	// 	{
	// 		int i = ii, j = jj;
	// 		int ri = i-5, rj = j-5;
	// 		ptr = (((1+f)*j + (ri & f)) * map->seens_map_w + (1+f)*i) * 4;
	// 		ri = (ri < 0) ? 0 : (ri >= map->w) ? map->w-1 : ri;
	// 		rj = (rj < 0) ? 0 : (rj >= map->h) ? map->h-1 : rj;
	// 		if ((i < 0) || (j < 0) || (i >= map->w+10) || (j >= map->h+10))
	// 		{
	// 			seens[ptr] = 0;
	// 			seens[ptr+1] = 0;
	// 			seens[ptr+2] = 0;
	// 			seens[ptr+3] = 255;
	// 			if (f) {
	// 				ptr += 4;
	// 				seens[ptr] = 0;
	// 				seens[ptr+1] = 0;
	// 				seens[ptr+2] = 0;
	// 				seens[ptr+3] = 255;
	// 				ptr += 4 * map->seens_map_w - 4;
	// 				seens[ptr] = 0;
	// 				seens[ptr+1] = 0;
	// 				seens[ptr+2] = 0;
	// 				seens[ptr+3] = 255;
	// 				ptr += 4;
	// 				seens[ptr] = 0;
	// 				seens[ptr+1] = 0;
	// 				seens[ptr+2] = 0;
	// 				seens[ptr+3] = 255;
	// 			}
	// 			//ptr += 4;
	// 			continue;
	// 		}
	// 		float v = map->grids_seens[rj*map->w+ri] * 255;
	// 		if (v)
	// 		{
	// 			if (v > 255) v = 255;
	// 			if (v < 0) v = 0;
	// 			seens[ptr] = (GLubyte)0;
	// 			seens[ptr+1] = (GLubyte)0;
	// 			seens[ptr+2] = (GLubyte)0;
	// 			seens[ptr+3] = (GLubyte)255-v;
	// 			if (f) {
	// 				ptr += 4;
	// 				seens[ptr] = (GLubyte)0;
	// 				seens[ptr+1] = (GLubyte)0;
	// 				seens[ptr+2] = (GLubyte)0;
	// 				seens[ptr+3] = (GLubyte)255-v;
	// 				ptr += 4 * map->seens_map_w - 4;
	// 				seens[ptr] = (GLubyte)0;
	// 				seens[ptr+1] = (GLubyte)0;
	// 				seens[ptr+2] = (GLubyte)0;
	// 				seens[ptr+3] = (GLubyte)255-v;
	// 				ptr += 4;
	// 				seens[ptr] = (GLubyte)0;
	// 				seens[ptr+1] = (GLubyte)0;
	// 				seens[ptr+2] = (GLubyte)0;
	// 				seens[ptr+3] = (GLubyte)255-v;
	// 			}
	// 		}
	// 		else if (map->grids_remembers[ri][rj])
	// 		{
	// 			seens[ptr] = 0;
	// 			seens[ptr+1] = 0;
	// 			seens[ptr+2] = 0;
	// 			seens[ptr+3] = 255 - map->obscure_a * 255;
	// 			if (f) {
	// 				ptr += 4;
	// 				seens[ptr] = 0;
	// 				seens[ptr+1] = 0;
	// 				seens[ptr+2] = 0;
	// 				seens[ptr+3] = 255 - map->obscure_a * 255;
	// 				ptr += 4 * map->seens_map_w - 4;
	// 				seens[ptr] = 0;
	// 				seens[ptr+1] = 0;
	// 				seens[ptr+2] = 0;
	// 				seens[ptr+3] = 255 - map->obscure_a * 255;
	// 				ptr += 4;
	// 				seens[ptr] = 0;
	// 				seens[ptr+1] = 0;
	// 				seens[ptr+2] = 0;
	// 				seens[ptr+3] = 255 - map->obscure_a * 255;
	// 			}
	// 		}
	// 		else
	// 		{
	// 			seens[ptr] = 0;
	// 			seens[ptr+1] = 0;
	// 			seens[ptr+2] = 0;
	// 			seens[ptr+3] = 255;
	// 			if (f) {
	// 				ptr += 4;
	// 				seens[ptr] = 0;
	// 				seens[ptr+1] = 0;
	// 				seens[ptr+2] = 0;
	// 				seens[ptr+3] = 255;
	// 				ptr += 4 * map->seens_map_w - 4;
	// 				seens[ptr] = 0;
	// 				seens[ptr+1] = 0;
	// 				seens[ptr+2] = 0;
	// 				seens[ptr+3] = 255;
	// 				ptr += 4;
	// 				seens[ptr] = 0;
	// 				seens[ptr+1] = 0;
	// 				seens[ptr+2] = 0;
	// 				seens[ptr+3] = 255;
	// 			}
	// 		}
	// 		//ptr += 4;
	// 	}
	// 	// Skip the rest of the texture, silly GPUs not supporting NPOT textures!
	// 	//ptr += (map->seens_map_w - map->w) * 4;
	// }
	// glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, map->seens_map_w, map->seens_map_h, GL_BGRA, GL_UNSIGNED_BYTE, seens);

	// if (!map->seens_vbo) {
	// 	map->seens_vbo = new VBO(VBOMode::STATIC);
		
	// 	map->seens_vbo->setTexture(map->seens_texture);

	// 	int w = (map->seens_map_w) * map->tile_w;
	// 	int h = (map->seens_map_h) * map->tile_h;
	// 	int f = 1 + (map->is_hex & 1);
	// 	map->seens_vbo->addQuad(
	// 		0, 0, 0, 0,
	// 		w, 0, f, 0,
	// 		w, h, f, f,
	// 		0, h, 0, f,
	// 		1, 1, 1, 1
	// 	);
	// }
// }

static int map_update_seen_texture_lua(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	// map_update_seen_texture(map);
	return 0;
}

static int map_draw_seen_texture(lua_State *L)
{
	// Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	// if (!map->seens_vbo) return 0;
	// int x = lua_tonumber(L, 2);
	// int y = lua_tonumber(L, 3);
	// int mx = map->mx;
	// int my = map->my;
	// x += -map->tile_w * 5;
	// y += -map->tile_h * 5;
	// x -= map->tile_w * (map->used_animdx + map->oldmx);
	// y -= map->tile_h * (map->used_animdy + map->oldmy);

	// map->seens_vbo->toScreen(x, y, 0, 1, 1);
	return 0;
}

static int map_bind_seen_texture(lua_State *L)
{
	// Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	// int unit = luaL_checknumber(L, 2);
	// if (unit > 0 && !multitexture_active) return 0;

	// if (unit > 0) tglActiveTexture(GL_TEXTURE0+unit);
	// tglBindTexture(GL_TEXTURE_2D, map->seens_texture);
	// if (unit > 0) tglActiveTexture(GL_TEXTURE0);

	return 0;
}

static int map_set_scroll(lua_State *L)
{
	// Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	// int x = luaL_checknumber(L, 2);
	// int y = luaL_checknumber(L, 3);
	// int smooth = luaL_checknumber(L, 4);

	// if (map->mx != x || map->my != y) {
	// 	map->changed = true;
	// }

	// if (smooth)
	// {
	// 	// Not moving, use starting point
	// 	if (!map->move_max)
	// 	{
	// 		map->oldmx = map->mx;
	// 		map->oldmy = map->my;
	// 	}
	// 	// Already moving, compute starting point
	// 	else
	// 	{
	// 		map->oldmx = map->oldmx + map->used_animdx;
	// 		map->oldmy = map->oldmy + map->used_animdy;
	// 	}
	// } else {
	// 	map->oldmx = x;
	// 	map->oldmy = y;
	// }

	// map->move_step = 0;
	// map->move_max = smooth;
	// map->used_animdx = 0;
	// map->used_animdy = 0;
	// map->mx = x;
	// map->my = y;
	// map->seen_changed = true;
	return 0;
}

static int map_get_scroll(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	// lua_pushnumber(L, -map->tile_w*(map->used_animdx + map->oldmx - map->mx));
	// lua_pushnumber(L, -map->tile_h*(map->used_animdy + map->oldmy - map->my));
	lua_pushnumber(L,0);lua_pushnumber(L,0);
	return 2;
}

static int lua_map_toscreen(lua_State *L)
{
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);

	mat4 model = mat4();
	model = glm::translate(model, glm::vec3(lua_tonumber(L, 2), lua_tonumber(L, 3), 0));

	map->toScreen(model, {1, 1, 1, 1});
	return 0;
}

static int map_line_grids(lua_State *L) {
	// Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	// if (!map->grid_lines_renderer) return 0;

	// int x = luaL_checknumber(L, 2);
	// int y = luaL_checknumber(L, 3);

	// glTranslatef(x - map->used_animdx * map->tile_w, y - map->used_animdy * map->tile_h, 0);
	// mat4 model = mat4();
	// model = glm::translate(model, vec3(x, y, 0));
	// map->grid_lines_renderer->toScreen(model, {1, 1, 1, 1});
	return 0;	
}

static int map_get_display_object(lua_State *L)
{
	// Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);

	// DORTileMap *tm = new DORTileMap();
	// tm->setMap(map);

	// DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	// *v = tm;
	// auxiliar_setclass(L, "gl{tilemap}", -1);
	// return 1;
	return 0;
}

static int map_get_display_object_mm(lua_State *L)
{
	// Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);

	// DORTileMiniMap *tm = new DORTileMiniMap();
	// tm->setMap(map);

	// DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	// *v = tm;
	// auxiliar_setclass(L, "gl{tileminimap}", -1);
	// return 1;
	return 0;
}

/*************************************************************************
 ** MapObjectRenderer wrapper
 *************************************************************************/
static int gl_mapobjectrenderer_free(lua_State *L)
{
	MapObjectRenderer **mor = (MapObjectRenderer**)auxiliar_checkclass(L, "core{mapobj2drender}", 1);
	delete *mor;

	lua_pushnumber(L, 1);
	return 1;
}


/*************************************************************************
 ** Lua defines
 *************************************************************************/
static const struct luaL_Reg maplib[] = {
	{"newMap", map_new},
	{"newObject", map_object_new},
	{"mapObjectsToDisplayObject", map_objects_to_displayobject},
	{NULL, NULL},
};

static const struct luaL_Reg map_reg[] = {
	{"__gc", map_free},
	{"close", map_free},
	{"updateSeensTexture", map_update_seen_texture_lua},
	{"bindSeensTexture", map_bind_seen_texture},
	{"drawSeensTexture", map_draw_seen_texture},
	{"setSortStart", map_set_sort_start},
	{"setZoom", map_set_zoom},
	{"setTint", map_set_tint},
	{"setShown", map_set_shown},
	{"setObscure", map_set_obscure},
	{"setGrid", map_set_grid},
	{"zCallback", map_set_z_callback},
	{"cleanSeen", map_clean_seen},
	{"cleanRemember", map_clean_remember},
	{"cleanLite", map_clean_lite},
	{"setDefaultShader", map_set_default_shader},
	{"setSeen", map_set_seen},
	{"setRemember", map_set_remember},
	{"setLite", map_set_lite},
	{"setImportant", map_set_important},
	{"getSeensInfo", map_get_seensinfo},
	{"setScroll", map_set_scroll},
	{"getScroll", map_get_scroll},
	{"toScreen", lua_map_toscreen},
	{"toScreenLineGrids", map_line_grids},
	{"setupGridLines", map_define_grid_lines},
	{"getMapDO", map_get_display_object},
	{"getMinimapDO", map_get_display_object_mm},
	{NULL, NULL},
};

static const struct luaL_Reg map_object_reg[] = {
	{"__gc", map_object_free},
	{"texture", map_object_texture},
	{"displayObject", map_object_set_do},
	{"displayCallback", map_object_cb},
	{"chain", map_object_chain},
	{"tint", map_object_tint},
	{"shader", map_object_shader},
	{"print", map_object_print},
	{"invalidate", map_object_invalid},
	{"isValid", map_object_is_valid},
	{"onSeen", map_object_on_seen},
	{"hide", map_object_hide},
	{"minimap", map_object_minimap},
	{"resetMoveAnim", map_object_reset_move_anim},
	{"setMoveAnim", map_object_set_move_anim},
	{"getMoveAnim", map_object_get_move_anim},
	{"getWorldPos", map_object_get_world_pos},
	{"setAnim", map_object_set_anim},
	{"flipX", map_object_flip_x},
	{"flipY", map_object_flip_y},
	{NULL, NULL},
};


static const struct luaL_Reg gl_mapobjectrenderer_reg[] =
{
	{"__gc", gl_mapobjectrenderer_free},
	INJECT_GENERIC_DO_METHODS
	{NULL, NULL},
};

extern "C" int luaopen_map2d(lua_State *L) {
	auxiliar_newclass(L, "core{map2d}", map_reg);
	auxiliar_newclass(L, "core{mapobj2d}", map_object_reg);
	auxiliar_newclass(L, "gl{mapobj2drender}", gl_mapobjectrenderer_reg);
	luaL_openlib(L, "core.map2d", maplib, 0);
	lua_pop(L, 1);
	return 1;
}
