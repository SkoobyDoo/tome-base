/*
    TE4 - T-Engine 4
    Copyright (C) 2009 - 2015 Nicolas Casalini

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

#include "renderer-moderngl/Renderer.hpp"
#include "renderer-moderngl/TileMap.hpp"
#include "renderer-moderngl/Particles.hpp"
#include "spriter/Spriter.hpp"

extern "C" {
#include "auxiliar.h"
#include "renderer-moderngl/renderer-lua.h"
}

template<class T=DisplayObject>T* userdata_to_DO(const char *caller, lua_State *L, int index, const char *auxclass = nullptr) {
	DisplayObject **ptr;
	if (auxclass) {
		ptr = reinterpret_cast<DisplayObject**>(auxiliar_checkclass(L, auxclass, index));
	} else {
		ptr = reinterpret_cast<DisplayObject**>(lua_touserdata(L, index));
		if (!ptr) {
			printf("invalid display object passed ! %s expected\n", typeid(T).name());
			traceback(L);
			luaL_error(L, "invalid display object passed");
		}
	}
	T* result = dynamic_cast<T*>(*ptr);
	if (!result) {
		printf("display object of wrong class! %s / %s (expected) !=! %s (actual) from %s\n", typeid(T).name(), auxclass ? auxclass : "", (*ptr)->getKind(), caller);
		traceback(L);
		luaL_error(L, "display object of wrong class");
	}
	return result;
}


/******************************************************************
 ** Generic
 ******************************************************************/
static int gl_generic_getkind(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	lua_pushstring(L, c->getKind());
	return 1;
}
static int gl_generic_color_get(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	vec4 color = c->getColor();
	lua_pushnumber(L, color.r);
	lua_pushnumber(L, color.g);
	lua_pushnumber(L, color.b);
	lua_pushnumber(L, color.a);
	return 4;
}
static int gl_generic_translate_get(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	float x, y, z;
	c->getTranslate(&x, &y, &z);
	lua_pushnumber(L, x);
	lua_pushnumber(L, y);
	lua_pushnumber(L, z);
	return 3;
}
static int gl_generic_rotate_get(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	float x, y, z;
	c->getRotate(&x, &y, &z);
	lua_pushnumber(L, x);
	lua_pushnumber(L, y);
	lua_pushnumber(L, z);
	return 3;
}
static int gl_generic_scale_get(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	float x, y, z;
	c->getScale(&x, &y, &z);
	lua_pushnumber(L, x);
	lua_pushnumber(L, y);
	lua_pushnumber(L, z);
	return 3;
}
static int gl_generic_shown_get(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	lua_pushboolean(L, c->getShown());
	return 1;
}

static int gl_generic_color(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	c->setColor(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_generic_translate(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	c->translate(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_generic_rotate(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	c->rotate(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_generic_scale(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	c->scale(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_generic_reset_matrix(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	c->resetModelMatrix();
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_generic_shown(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	c->shown(lua_toboolean(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_generic_remove_from_parent(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	c->removeFromParent();
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** Renderer
 ******************************************************************/
static int gl_renderer_new(lua_State *L)
{
	DisplayObject **r = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	auxiliar_setclass(L, "gl{renderer}", -1);

	RendererGL *rgl = new RendererGL();
	*r = rgl;

	if (lua_isstring(L, 1)) {
		rgl->setRendererName(luaL_checkstring(L, 1));
	}

	return 1;
}

static int gl_renderer_free(lua_State *L)
{
	RendererGL *r = userdata_to_DO<RendererGL>(__FUNCTION__, L, 1, "gl{renderer}");
	delete(r);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_renderer_zsort(lua_State *L)
{
	RendererGL *r = userdata_to_DO<RendererGL>(__FUNCTION__, L, 1, "gl{renderer}");
	r->zSorting(lua_toboolean(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_renderer_cutoff(lua_State *L)
{
	RendererGL *r = userdata_to_DO<RendererGL>(__FUNCTION__, L, 1, "gl{renderer}");
	r->cutoff(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_renderer_set_name(lua_State *L)
{
	RendererGL *r = userdata_to_DO<RendererGL>(__FUNCTION__, L, 1, "gl{renderer}");
	r->setRendererName(luaL_checkstring(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_renderer_toscreen(lua_State *L)
{
	RendererGL *r = userdata_to_DO<RendererGL>(__FUNCTION__, L, 1, "gl{renderer}");
	r->toScreenSimple();
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** Container
 ******************************************************************/
static int gl_container_new(lua_State *L)
{
	DisplayObject **c = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	auxiliar_setclass(L, "gl{container}", -1);
	*c = new DORContainer();

	return 1;
}

static int gl_container_free(lua_State *L)
{
	DORContainer *c = userdata_to_DO<DORContainer>(__FUNCTION__, L, 1, "gl{container}");
	delete(c);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_container_add(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	DORContainer *c = userdata_to_DO<DORContainer>(__FUNCTION__, L, 1);
	DisplayObject *add = userdata_to_DO(__FUNCTION__, L, 2);
	c->add(add);
	add->setLuaRef(luaL_ref(L, LUA_REGISTRYINDEX));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_container_remove(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	DORContainer *c = userdata_to_DO<DORContainer>(__FUNCTION__, L, 1);
	DisplayObject *add = userdata_to_DO(__FUNCTION__, L, 2);
	c->remove(add);
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_container_clear(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	DORContainer *c = userdata_to_DO<DORContainer>(__FUNCTION__, L, 1);
	c->clear();
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** Target (FBO)
 ******************************************************************/
static int gl_target_new(lua_State *L)
{
	DisplayObject **c = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	auxiliar_setclass(L, "gl{target}", -1);
	int w = screen->w / screen_zoom;
	int h = screen->h / screen_zoom;
	int nbt = 1;

	if (lua_isnumber(L, 1)) w = lua_tonumber(L, 1);
	if (lua_isnumber(L, 2)) h = lua_tonumber(L, 2);
	if (lua_isnumber(L, 3)) nbt = lua_tonumber(L, 3);

	*c = new DORTarget(w, h, nbt);

	return 1;
}

static int gl_target_free(lua_State *L)
{
	DORTarget *c = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	delete(c);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_target_use(lua_State *L)
{
	DORTarget *c = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	c->use(lua_toboolean(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_displaysize(lua_State *L)
{
	DORTarget *c = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	c->displaySize(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_toboolean(L, 4));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_clearcolor(lua_State *L)
{
	DORTarget *c = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	c->setClearColor(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_shader(lua_State *L)
{
	DORTarget *v = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	shader_type *shader = (shader_type*)lua_touserdata(L, 2);
	v->setShader(shader);
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_set_auto_render(lua_State *L)
{
	DORTarget *c = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	if (lua_isnil(L, 2)) {
		c->setAutoRender(NULL, LUA_NOREF);
	} else {
		SubRenderer *o = userdata_to_DO<SubRenderer>(__FUNCTION__, L, 2);
		if (o) {
			lua_pushvalue(L, 2);
			c->setAutoRender(o, luaL_ref(L, LUA_REGISTRYINDEX));
		}
	}
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** Vertexes
 ******************************************************************/
static int gl_vertexes_new(lua_State *L)
{
	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	auxiliar_setclass(L, "gl{vertexes}", -1);
	*v = new DORVertexes();

	return 1;
}

static int gl_vertexes_free(lua_State *L)
{
	DORVertexes *v = userdata_to_DO<DORVertexes>(__FUNCTION__, L, 1, "gl{vertexes}");
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_vertexes_clear(lua_State *L)
{
	DORVertexes *v = userdata_to_DO<DORVertexes>(__FUNCTION__, L, 1, "gl{vertexes}");
	v->clear();
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_vertexes_quad(lua_State *L)
{
	DORVertexes *v = userdata_to_DO<DORVertexes>(__FUNCTION__, L, 1, "gl{vertexes}");
	float x1 = lua_tonumber(L, 2);  float y1 = lua_tonumber(L, 3);  float u1 = lua_tonumber(L, 4);  float v1 = lua_tonumber(L, 5); 
	float x2 = lua_tonumber(L, 6);  float y2 = lua_tonumber(L, 7);  float u2 = lua_tonumber(L, 8);  float v2 = lua_tonumber(L, 9); 
	float x3 = lua_tonumber(L, 10); float y3 = lua_tonumber(L, 11); float u3 = lua_tonumber(L, 12); float v3 = lua_tonumber(L, 13); 
	float x4 = lua_tonumber(L, 14); float y4 = lua_tonumber(L, 15); float u4 = lua_tonumber(L, 16); float v4 = lua_tonumber(L, 17); 
	float r = lua_tonumber(L, 18); float g = lua_tonumber(L, 19); float b = lua_tonumber(L, 20); float a = lua_tonumber(L, 21);
	v->addQuad(
		x1, y1, u1, v1, 
		x2, y2, u2, v2, 
		x3, y3, u3, v3, 
		x4, y4, u4, v4, 
		r, g, b, a
	);
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_vertexes_texture(lua_State *L)
{
	DORVertexes *v = userdata_to_DO<DORVertexes>(__FUNCTION__, L, 1, "gl{vertexes}");
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 2);
	lua_pushvalue(L, 2);
	v->setTexture(t->tex, luaL_ref(L, LUA_REGISTRYINDEX));

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_vertexes_shader(lua_State *L)
{
	DORVertexes *v = userdata_to_DO<DORVertexes>(__FUNCTION__, L, 1, "gl{vertexes}");
	shader_type *shader = (shader_type*)lua_touserdata(L, 2);
	v->setShader(shader);
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** Text
 ******************************************************************/
static int gl_text_new(lua_State *L)
{
	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	DORText *t;
	auxiliar_setclass(L, "gl{text}", -1);

	*v = t = new DORText();

	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
	if (lua_isnumber(L, 2)) t->setMaxWidth(lua_tonumber(L, 2));
	t->setNoLinefeed(lua_toboolean(L, 3));

	lua_pushvalue(L, 1);
	t->setFont(f, luaL_ref(L, LUA_REGISTRYINDEX));

	return 1;
}

static int gl_text_free(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_text_linefeed(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	v->setNoLinefeed(!lua_toboolean(L, 2));

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_text_get_letter_position(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	vec2 pos = v->getLetterPosition(lua_tonumber(L, 2));
	lua_pushnumber(L, pos.x);
	lua_pushnumber(L, pos.y);
	return 2;
}

static int gl_text_max_width(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	v->setMaxWidth(lua_tonumber(L, 2));

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_text_max_lines(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	v->setMaxLines(lua_tonumber(L, 2));

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_text_text_color(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	v->setTextColor(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_text_center(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	v->center();
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_text_set(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	v->setText(luaL_checkstring(L, 2));

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_text_stats(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");

	lua_pushnumber(L, v->w);
	lua_pushnumber(L, v->h);
	lua_pushnumber(L, v->nb_lines);
	return 3;
}

static int gl_text_shader(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	shader_type *shader = (shader_type*)lua_touserdata(L, 2);
	v->setShader(shader);
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** DORCallback 
 ******************************************************************/
static int gl_callback_new(lua_State *L)
{
	if (!lua_isfunction(L, 1)) {
		lua_pushstring(L, "callback arg is not a function");
		lua_error(L);
		return 0;
	}

	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	DORCallback *t;
	auxiliar_setclass(L, "gl{callback}", -1);

	*v = t = new DORCallback();

	lua_pushvalue(L, 1);
	t->setCallback(luaL_ref(L, LUA_REGISTRYINDEX));

	return 1;
}

static int gl_callback_free(lua_State *L)
{
	DORCallback *v = userdata_to_DO<DORCallback>(__FUNCTION__, L, 1, "gl{callback}");
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_callback_set(lua_State *L)
{
	DORCallback *v = userdata_to_DO<DORCallback>(__FUNCTION__, L, 1, "gl{callback}");
	if (!lua_isfunction(L, 2)) {
		lua_pushstring(L, "callback arg is not a function");
		lua_error(L);
		return 0;
	}
	lua_pushvalue(L, 2);
	v->setCallback(luaL_ref(L, LUA_REGISTRYINDEX));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_callback_enable(lua_State *L)
{
	DORCallback *v = userdata_to_DO<DORCallback>(__FUNCTION__, L, 1, "gl{callback}");
	v->enable(lua_toboolean(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** TileObject -- no constructor, this is in map.cpp
 ******************************************************************/
static int gl_tileobject_free(lua_State *L)
{
	DORTileObject *v = userdata_to_DO<DORTileObject>(__FUNCTION__, L, 1, "gl{tileobject}");
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

/******************************************************************
 ** Particles -- no constructor, this is in particles.cpp
 ******************************************************************/
static int gl_particles_free(lua_State *L)
{
	DORParticles *v = userdata_to_DO<DORParticles>(__FUNCTION__, L, 1, "gl{particles}");
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

/******************************************************************
 ** TileMap -- no constructor, this is in map.cpp
 ******************************************************************/
static int gl_tilemap_free(lua_State *L)
{
	DORTileMap *v = userdata_to_DO<DORTileMap>(__FUNCTION__, L, 1, "gl{tilemap}");
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_tilemap_setmap(lua_State *L)
{
	DORTileMap *v = userdata_to_DO<DORTileMap>(__FUNCTION__, L, 1, "gl{tilemap}");
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 2);

	v->setMap(map);	
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_tilemap_setminimap_info(lua_State *L)
{
	DORTileMap *v = userdata_to_DO<DORTileMap>(__FUNCTION__, L, 1, "gl{tilemap}");

	v->setMinimapInfo(luaL_checknumber(L, 2), luaL_checknumber(L, 3), luaL_checknumber(L, 4), luaL_checknumber(L, 5), luaL_checknumber(L, 6), luaL_checknumber(L, 7));
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** DORSpriter
 ******************************************************************/
static int gl_spriter_new(lua_State *L)
{
	const char *file = luaL_checkstring(L, 1);
	const char *name = luaL_checkstring(L, 2);

	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	DORSpriter *t;
	auxiliar_setclass(L, "gl{spriter}", -1);

	*v = t = new DORSpriter();
	t->load(file, name);
	return 1;
}

static int gl_spriter_free(lua_State *L)
{
	DORSpriter *v = userdata_to_DO<DORSpriter>(__FUNCTION__, L, 1, "gl{spriter}");
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_spriter_set_anim(lua_State *L)
{
	DORSpriter *v = userdata_to_DO<DORSpriter>(__FUNCTION__, L, 1, "gl{spriter}");
	v->startAnim(luaL_checkstring(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_spriter_trigger_callback(lua_State *L)
{
	DORSpriter *v = userdata_to_DO<DORSpriter>(__FUNCTION__, L, 1, "gl{spriter}");
	if (!lua_isfunction(L, 2)) {
		lua_pushstring(L, "callback arg is not a function");
		lua_error(L);
		return 0;
	}
	lua_pushvalue(L, 2);
	v->setTriggerCallback(luaL_ref(L, LUA_REGISTRYINDEX));
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** Generic non object functions
 ******************************************************************/
static int gl_dos_count(lua_State *L) 
{
	lua_pushnumber(L, donb);
	return 1;
}

/******************************************************************
 ** Lua declarations
 ******************************************************************/

static const struct luaL_Reg gl_renderer_reg[] =
{
	{"__gc", gl_renderer_free},
	{"zSort", gl_renderer_zsort},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"removeFromParent", gl_generic_remove_from_parent},
	{"add", gl_container_add},
	{"remove", gl_container_remove},
	{"clear", gl_container_clear},
	{"cutoff", gl_renderer_cutoff},
	{"setRendererName", gl_renderer_set_name},
	{"toScreen", gl_renderer_toscreen},
	{NULL, NULL},
};

static const struct luaL_Reg gl_target_reg[] =
{
	{"__gc", gl_target_free},
	{"use", gl_target_use},
	{"displaySize", gl_target_displaysize},
	{"clearColor", gl_target_clearcolor},
	{"shader", gl_target_shader},
	{"setAutoRender", gl_target_set_auto_render},
	{"clear", gl_vertexes_clear},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_container_reg[] =
{
	{"__gc", gl_container_free},
	{"add", gl_container_add},
	{"remove", gl_container_remove},
	{"clear", gl_container_clear},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_vertexes_reg[] =
{
	{"__gc", gl_vertexes_free},
	{"quad", gl_vertexes_quad},
	{"texture", gl_vertexes_texture},
	{"shader", gl_vertexes_shader},
	{"clear", gl_vertexes_clear},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_text_reg[] =
{
	{"__gc", gl_text_free},
	{"text", gl_text_set},
	{"textColor", gl_text_text_color},
	{"getStats", gl_text_stats},
	{"maxWidth", gl_text_max_width},
	{"maxLines", gl_text_max_lines},
	{"linefeed", gl_text_linefeed},
	{"getLetterPosition", gl_text_get_letter_position},
	{"center", gl_text_center},
	{"shader", gl_text_shader},
	{"clear", gl_vertexes_clear},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_callback_reg[] =
{
	{"__gc", gl_callback_free},
	{"set", gl_callback_set},
	{"enable", gl_callback_enable},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_tileobject_reg[] =
{
	{"__gc", gl_tileobject_free},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_tilemap_reg[] =
{
	{"__gc", gl_tilemap_free},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"removeFromParent", gl_generic_remove_from_parent},
	{"setMap", gl_tilemap_setmap},
	{"setMinimapInfo", gl_tilemap_setminimap_info},
	{NULL, NULL},
};

static const struct luaL_Reg gl_particles_reg[] =
{
	{"__gc", gl_particles_free},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_spriter_reg[] =
{
	{"__gc", gl_spriter_free},
	{"triggerCallback", gl_spriter_trigger_callback},
	{"setAnim", gl_spriter_set_anim},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

const luaL_Reg rendererlib[] = {
	{"renderer", gl_renderer_new},
	{"vertexes", gl_vertexes_new},
	{"text", gl_text_new},
	{"container", gl_container_new},
	{"target", gl_target_new},
	{"callback", gl_callback_new},
	{"spriter", gl_spriter_new},
	{"countDOs", gl_dos_count},
	{NULL, NULL}
};

int luaopen_renderer(lua_State *L)
{
	auxiliar_newclass(L, "gl{renderer}", gl_renderer_reg);
	auxiliar_newclass(L, "gl{vertexes}", gl_vertexes_reg);
	auxiliar_newclass(L, "gl{text}", gl_text_reg);
	auxiliar_newclass(L, "gl{container}", gl_container_reg);
	auxiliar_newclass(L, "gl{target}", gl_target_reg);
	auxiliar_newclass(L, "gl{callback}", gl_callback_reg);
	auxiliar_newclass(L, "gl{tileobject}", gl_tileobject_reg);
	auxiliar_newclass(L, "gl{tilemap}", gl_tilemap_reg);
	auxiliar_newclass(L, "gl{particles}", gl_particles_reg);
	auxiliar_newclass(L, "gl{spriter}", gl_spriter_reg);
	luaL_openlib(L, "core.renderer", rendererlib, 0);

	init_spriter();
	return 1;
}
