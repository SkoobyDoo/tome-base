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
#include "map/2d/Minimap2D.hpp"
#include "displayobjects/renderer-lua.hpp"
#include "auxiliar.hpp"


/*************************************************************************
 ** MapObject wrapper
 *************************************************************************/
static uint64_t nb_mo = 0;
static int map_object_new(lua_State *L) {
	long uid = luaL_checknumber(L, 1);
	int nb_textures = luaL_checknumber(L, 2);
	int i;

	lua_make_sobj(L, "core{mapobj2d}", new MapObject(uid, nb_textures,
		lua_toboolean(L, 3),
		lua_toboolean(L, 4),
		lua_toboolean(L, 5),
		{ luaL_checknumber(L, 6), luaL_checknumber(L, 7) },
		{ luaL_checknumber(L, 8), luaL_checknumber(L, 9) },
		luaL_checknumber(L, 10)
	));
	nb_mo++;

	return 1;
}

static int map_object_free(lua_State *L) {
	auto obj = lua_get_sobj_ptr<MapObject>(L, "core{mapobj2d}", 1);
	// printf("========del %ld : use %ld\n", (*obj)->getUID(), obj->use_count());
	delete obj;
	nb_mo--;
	lua_pushnumber(L, 1);
	return 1;
}

static int map_object_cb(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);

	if (lua_isfunction(L, 2)) {
		lua_pushvalue(L, 2);
		obj->setCallback(luaL_ref(L, LUA_REGISTRYINDEX));
	}
	return 0;
}

static int map_object_chain(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	auto obj2 = lua_get_sobj<MapObject>(L, "core{mapobj2d}", 2);
	
	obj->chain(obj2);
	return 0;
}

static int map_object_hide(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	obj->setHidden(true);
	return 0;
}

static int map_object_on_seen(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	if (lua_isboolean(L, 2)) {
		obj->setSeen(lua_toboolean(L, 2));
	}
	lua_pushboolean(L, obj->isSeen());
	return 1;
}

static int map_object_texture(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
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

static int map_object_set_do(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	if (!lua_isnil(L, 2)) {
		DisplayObject *v = userdata_to_DO(__FUNCTION__, L, 2);
		lua_pushvalue(L, 2);
		obj->setDisplayObject(v, luaL_ref(L, LUA_REGISTRYINDEX), lua_toboolean(L, 3));
	} else {
		obj->setDisplayObject(nullptr, LUA_NOREF, lua_toboolean(L, 3));
	}
	return 0;
}

static int map_object_shader(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	if (!lua_isnil(L, 2)) {
		shader_type *s = (shader_type*)lua_touserdata(L, 2);
		lua_pushvalue(L, 2);
		obj->setShader(s, luaL_ref(L, LUA_REGISTRYINDEX));
	} else {
		obj->setShader(nullptr, LUA_NOREF);
	}
	return 0;
}

static int map_object_add_particles(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	DORParticles *v = userdata_to_DO<DORParticles>(__FUNCTION__, L, 2, "gl{particles}");
	lua_pushvalue(L, 2);
	obj->addParticles(v, luaL_ref(L, LUA_REGISTRYINDEX));
	return 0;
}
static int map_object_remove_particles(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	DORParticles *v = userdata_to_DO<DORParticles>(__FUNCTION__, L, 2, "gl{particles}");
	obj->removeParticles(v);
	return 0;
}
static int map_object_clear_particles(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	obj->clearParticles();
	return 0;
}

static int map_object_tint(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	obj->setTint({luaL_checknumber(L, 2), luaL_checknumber(L, 3), luaL_checknumber(L, 4)});
	return 0;
}

static int map_object_minimap(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	obj->setMinimapColor({luaL_checknumber(L, 2), luaL_checknumber(L, 3), luaL_checknumber(L, 4)});
	return 0;
}

static int map_object_flip_x(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	obj->flipX(lua_toboolean(L, 2));
	return 0;
}

static int map_object_flip_y(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	obj->flipY(lua_toboolean(L, 2));
	return 0;
}

static int map_object_print(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	return 0;
}

static int map_object_invalid(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	obj->invalidate();
	return 0;
}


static int map_object_set_anim(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);

	// obj->anim_step = luaL_checknumber(L, 2);
	// obj->anim_max = luaL_checknumber(L, 3);
	// obj->anim_speed = luaL_checknumber(L, 4);
	// obj->anim_loop = luaL_checknumber(L, 5);
	return 0;
}

static int map_object_reset_move_anim(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	obj->resetMoveAnim();
	return 0;
}

static int map_object_set_move_anim(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	obj->setMoveAnim(luaL_checknumber(L, 2), luaL_checknumber(L, 3), luaL_checknumber(L, 4), lua_tonumber(L, 5), lua_tonumber(L, 6), lua_tonumber(L, 7));
	return 0;
}

static int map_object_get_move_anim(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
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

static int map_object_get_world_pos(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	lua_pushnumber(L, 0);lua_pushnumber(L, 0);return 2;
	// lua_pushnumber(L, obj->world_x);
	// lua_pushnumber(L, obj->world_y);
	return 2;
}

static int map_object_is_valid(lua_State *L) {
	auto obj = lua_get_sobj_get<MapObject>(L, "core{mapobj2d}", 1);
	lua_pushboolean(L, obj->isValid());
	return 1;
}

static void map_object_update(lua_State *L, int moid, MapObjectRenderer *mor) {
	while (lua_isuserdata(L, moid)) {
		auto obj = lua_get_sobj<MapObject>(L, "core{mapobj2d}", moid);
		mor->addMapObject(obj);
		moid++;
	}
}

static int map_objects_to_displayobject(lua_State *L) {
	int w = luaL_checknumber(L, 1);
	int h = luaL_checknumber(L, 2);
	bool allow_cb = lua_toboolean(L, 3);
	bool allow_particles = lua_toboolean(L, 4);

	MapObjectRenderer *mor = new MapObjectRenderer(w, h, allow_cb, allow_cb);

	map_object_update(L, 5, mor);

	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	*v = mor;
	auxiliar_setclass(L, "gl{mapobj2drender}", -1);
	return 1;
}


/*************************************************************************
 ** Map2D wrapper
 *************************************************************************/
static int map_new(lua_State *L) {
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
	*pmap = new Map2D(zdepth, w, h, tile_w, tile_h, mwidth, mheight);
	return 1;
}

static int map_free(lua_State *L) {
	Map2D **map = (Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	delete *map;

	lua_pushnumber(L, 1);
	return 1;
}

static int map_show_vision(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->enableVision(lua_toboolean(L, 2));
	return 0;
}

static int map_smooth_vision(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->smoothVision(lua_toboolean(L, 2));
	return 0;
}

static int map_define_grid_lines(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->enableGridLines(luaL_checknumber(L, 2));
	return 0;
}

static int map_set_z_callback(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	int32_t z = luaL_checknumber(L, 2);
	if (lua_isfunction(L, 3)) {
		lua_pushvalue(L, 3);
		map->setZCallback(z, luaL_ref(L, LUA_REGISTRYINDEX));
	}
	return 0;
}

static int map_set_sort_start(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->setZSortStart(lua_tonumber(L, 2));
	return 0;
}


static int map_set_tint(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->setTint({lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5)});
	return 0;
}

static int map_set_zoom(lua_State *L) {
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

static int map_set_vision_shader(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	if (!lua_isnil(L, 2)) {
		shader_type *s = (shader_type*)lua_touserdata(L, 2);
		lua_pushvalue(L, 2);
		map->setVisionShader(s, luaL_ref(L, LUA_REGISTRYINDEX));
	} else {
		lua_pushliteral(L, "Map vision shader must exist");
		lua_error(L);
	}
	return 0;
}

static int map_set_grid_lines_shader(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	if (!lua_isnil(L, 2)) {
		shader_type *s = (shader_type*)lua_touserdata(L, 2);
		lua_pushvalue(L, 2);
		map->setGridLinesShader(s, luaL_ref(L, LUA_REGISTRYINDEX));
	} else {
		map->setGridLinesShader(nullptr, LUA_NOREF);
	}
	return 0;
}

static int map_set_default_shader(lua_State *L) {
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

static int map_set_obscure(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->setObscure({lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5)});
	return 0;
}

static int map_set_shown(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->setShown({lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5)});
	return 0;
}

static int map_set_grid(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	uint32_t x = luaL_checknumber(L, 2);
	uint32_t y = luaL_checknumber(L, 3);
	vec2 size = map->getSize();
	if (x < 0 || y < 0 || x >= size.x || y >= size.y) return 0;

	for (uint8_t z = 0; z < map->getDepth(); z++) {
		lua_pushnumber(L, z + 1);
		lua_gettable(L, 4); // Access the table of mos for this spot
		sMapObject mo(nullptr);
		if (!lua_isnoneornil(L, -1)) mo = lua_get_sobj<MapObject>(L, "core{mapobj2d}", -1);
		map->set(z, x, y, mo);

		// Remove the mo and get the next
		lua_pop(L, 1);
	}

	// Pop the mo list
	lua_pop(L, 1);
	return 0;
}

static int map_set_seen(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	int x = lua_tonumber(L, 2);
	int y = lua_tonumber(L, 3);
	float v = lua_tonumber(L, 4);

	map->setSeen(x, y, v);
	return 0;
}

static int map_set_remember(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	int x = lua_tonumber(L, 2);
	int y = lua_tonumber(L, 3);
	bool v = lua_toboolean(L, 4);

	map->setRemember(x, y, v);
	return 0;
}

static int map_set_lite(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	int x = lua_tonumber(L, 2);
	int y = lua_tonumber(L, 3);
	bool v = lua_toboolean(L, 4);

	map->setLite(x, y, v);
	return 0;
}

static int map_set_important(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	int x = lua_tonumber(L, 2);
	int y = lua_tonumber(L, 3);
	bool v = lua_toboolean(L, 4);

	map->setImportant(x, y, v);
	return 0;
}

static int map_clean_seen(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->cleanSeen(0);
	return 0;
}

static int map_clean_remember(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->cleanRemember(0);
	return 0;
}

static int map_clean_lite(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	map->cleanLite(0);
	return 0;
}

static int map_set_scroll(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);
	int smooth = luaL_checknumber(L, 4);
	map->scroll(x, y, smooth);
	return 0;
}

static int map_get_scroll(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);
	vec2 s = map->getScroll();
	lua_pushnumber(L, s.x);
	lua_pushnumber(L, s.y);
	return 2;
}

static int lua_map_toscreen(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);

	mat4 model = mat4();
	model = glm::translate(model, glm::vec3(lua_tonumber(L, 2), lua_tonumber(L, 3), 0));

	map->toScreen(model, {1, 1, 1, 1});
	return 0;
}

static int map_get_display_object_mm(lua_State *L) {
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 1);

	Minimap2D *tm = new Minimap2D();

	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	*v = tm;
	auxiliar_setclass(L, "gl{minimap2d}", -1);
	return 1;
}

/*************************************************************************
 ** MapObjectRenderer wrapper
 *************************************************************************/
static int gl_mapobjectrenderer_free(lua_State *L) {
	MapObjectRenderer **mor = (MapObjectRenderer**)auxiliar_checkclass(L, "gl{mapobj2drender}", 1);
	delete *mor;

	lua_pushnumber(L, 1);
	return 1;
}

static int gl_mapobjectrenderer_update(lua_State *L) {
	MapObjectRenderer *mor = *(MapObjectRenderer**)auxiliar_checkclass(L, "gl{mapobj2drender}", 1);
	mor->resetMapObjects();
	map_object_update(L, 2, mor);
	lua_pushvalue(L, 1);
	return 1;
}

/*************************************************************************
 ** Minimap2D wrapper
 *************************************************************************/
static int gl_minimap2d_free(lua_State *L) {
	Minimap2D **mor = (Minimap2D**)auxiliar_checkclass(L, "gl{minimap2d}", 1);
	delete *mor;

	lua_pushnumber(L, 1);
	return 1;
}
static int gl_minimap2d_setmap(lua_State *L) {
	Minimap2D *mor = *(Minimap2D**)auxiliar_checkclass(L, "gl{minimap2d}", 1);
	Map2D *map = *(Map2D**)auxiliar_checkclass(L, "core{map2d}", 2);
	mor->setMap(map);
	lua_pushvalue(L, 1);
	return 1;
}
static int gl_minimap2d_setinfo(lua_State *L) {
	Minimap2D *mor = *(Minimap2D**)auxiliar_checkclass(L, "gl{minimap2d}", 1);
	mor->setMinimapInfo(luaL_checknumber(L, 2), luaL_checknumber(L, 3), luaL_checknumber(L, 4), luaL_checknumber(L, 5), luaL_checknumber(L, 6));
	lua_pushvalue(L, 1);
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
	{"setVisionShader", map_set_vision_shader},
	{"setGridLinesShader", map_set_grid_lines_shader},
	{"setSeen", map_set_seen},
	{"setRemember", map_set_remember},
	{"setLite", map_set_lite},
	{"setImportant", map_set_important},
	{"setScroll", map_set_scroll},
	{"getScroll", map_get_scroll},
	{"showVision", map_show_vision},
	{"smoothVision", map_smooth_vision},
	{"toScreen", lua_map_toscreen},
	{"setupGridLines", map_define_grid_lines},
	{"getMinimapDO", map_get_display_object_mm},
	INJECT_GENERIC_DO_METHODS
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
	{"addParticles", map_object_add_particles},
	{"removeParticles", map_object_remove_particles},
	{"clearParticles", map_object_clear_particles},
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

static const struct luaL_Reg gl_minimap2d_reg[] =
{
	{"__gc", gl_minimap2d_free},
	INJECT_GENERIC_DO_METHODS
	{"setMap", gl_minimap2d_setmap},
	{"setMinimapInfo", gl_minimap2d_setinfo},
	{NULL, NULL},
};

static const struct luaL_Reg gl_mapobjectrenderer_reg[] =
{
	{"__gc", gl_mapobjectrenderer_free},
	{"updateEntity", gl_mapobjectrenderer_update},
	INJECT_GENERIC_DO_METHODS
	{NULL, NULL},
};

extern "C" int luaopen_map2d(lua_State *L) {
	auxiliar_newclass(L, "core{map2d}", map_reg);
	auxiliar_newclass(L, "core{mapobj2d}", map_object_reg);
	auxiliar_newclass(L, "gl{mapobj2drender}", gl_mapobjectrenderer_reg);
	auxiliar_newclass(L, "gl{minimap2d}", gl_minimap2d_reg);
	luaL_openlib(L, "core.map2d", maplib, 0);
	lua_pop(L, 1);

	// sMapObject mo1 = make_shared<MapObject>(1, 1, true, true, true, vec2(), vec2(), 1);
	// sMapObject mo2 = make_shared<MapObject>(1, 1, true, true, true, vec2(), vec2(), 1);
	// vector<sMapObject> map;
	// printf("===== %ld\n", mo1.use_count());
	// map.emplace_back(mo1);
	// printf("===== %ld\n", mo1.use_count());
	// map.clear();
	// printf("===== %ld\n", mo1.use_count());

	// exit(1);
	return 1;
}
