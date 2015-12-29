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
extern "C" {
#include "auxiliar.h"
#include "renderer-moderngl/renderer-lua.h"
}

/******************************************************************
 ** Renderer
 ******************************************************************/
static int gl_renderer_new(lua_State *L)
{
	RendererGL **r = (RendererGL**)lua_newuserdata(L, sizeof(RendererGL*));
	auxiliar_setclass(L, "gl{renderer}", -1);
	*r = new RendererGL();
	(*r)->setLuaState(L);

	return 1;
}

static int gl_renderer_free(lua_State *L)
{
	RendererGL **r = (RendererGL**)auxiliar_checkclass(L, "gl{renderer}", 1);
	delete(*r);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_renderer_toscreen(lua_State *L)
{
	RendererGL **renderer = (RendererGL**)auxiliar_checkclass(L, "gl{renderer}", 1);
	float x = lua_tonumber(L, 2);
	float y = lua_tonumber(L, 3);
	float r = lua_tonumber(L, 4);
	float g = lua_tonumber(L, 5);
	float b = lua_tonumber(L, 6);
	float a = lua_tonumber(L, 7);
	(*renderer)->toScreen(x, y, r, g, b, a);
	return 0;
}

static int gl_renderer_add(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	RendererGL **c = (RendererGL**)lua_touserdata(L, 1);
	DisplayObject **add = (DisplayObject**)lua_touserdata(L, 2);
	(*c)->add(*add);	
	(*add)->setLuaRef(luaL_ref(L, LUA_REGISTRYINDEX));
	return 0;
}

static int gl_renderer_remove(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	RendererGL **c = (RendererGL**)lua_touserdata(L, 1);
	DisplayObject **add = (DisplayObject**)lua_touserdata(L, 2);
	(*c)->remove(*add);
	return 0;
}

/******************************************************************
 ** Container
 ******************************************************************/
static int gl_container_new(lua_State *L)
{
	DORContainer **c = (DORContainer**)lua_newuserdata(L, sizeof(DORContainer*));
	auxiliar_setclass(L, "gl{container}", -1);
	*c = new DORContainer();
	(*c)->setLuaState(L);

	return 1;
}

static int gl_container_free(lua_State *L)
{
	DORContainer **c = (DORContainer**)auxiliar_checkclass(L, "gl{container}", 1);
	delete(*c);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_container_add(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	DORContainer **c = (DORContainer**)lua_touserdata(L, 1);
	DisplayObject **add = (DisplayObject**)lua_touserdata(L, 2);
	(*c)->add(*add);	
	(*add)->setLuaRef(luaL_ref(L, LUA_REGISTRYINDEX));
	return 0;
}

static int gl_container_remove(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	DORContainer **c = (DORContainer**)lua_touserdata(L, 1);
	DisplayObject **add = (DisplayObject**)lua_touserdata(L, 2);
	(*c)->remove(*add);
	return 0;
}

static int gl_container_translate(lua_State *L)
{
	DORContainer **c = (DORContainer**)auxiliar_checkclass(L, "gl{container}", 1);
	(*c)->translate(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	return 0;
}

static int gl_container_rotate(lua_State *L)
{
	DORContainer **c = (DORContainer**)auxiliar_checkclass(L, "gl{container}", 1);
	(*c)->rotate(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	return 0;
}

static int gl_container_scale(lua_State *L)
{
	DORContainer **c = (DORContainer**)auxiliar_checkclass(L, "gl{container}", 1);
	(*c)->scale(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	return 0;
}

/******************************************************************
 ** Vertexes
 ******************************************************************/
static int gl_vertexes_new(lua_State *L)
{
	DORVertexes **v = (DORVertexes**)lua_newuserdata(L, sizeof(DORVertexes*));
	auxiliar_setclass(L, "gl{vertexes}", -1);
	*v = new DORVertexes();
	(*v)->setLuaState(L);

	return 1;
}

static int gl_vertexes_free(lua_State *L)
{
	DORVertexes **v = (DORVertexes**)auxiliar_checkclass(L, "gl{vertexes}", 1);
	delete(*v);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_vertexes_quad(lua_State *L)
{
	DORVertexes **v = (DORVertexes**)auxiliar_checkclass(L, "gl{vertexes}", 1);
	float x1 = lua_tonumber(L, 2);  float y1 = lua_tonumber(L, 3);  float u1 = lua_tonumber(L, 4);  float v1 = lua_tonumber(L, 5); 
	float x2 = lua_tonumber(L, 6);  float y2 = lua_tonumber(L, 7);  float u2 = lua_tonumber(L, 8);  float v2 = lua_tonumber(L, 9); 
	float x3 = lua_tonumber(L, 10); float y3 = lua_tonumber(L, 11); float u3 = lua_tonumber(L, 12); float v3 = lua_tonumber(L, 13); 
	float x4 = lua_tonumber(L, 14); float y4 = lua_tonumber(L, 15); float u4 = lua_tonumber(L, 16); float v4 = lua_tonumber(L, 17); 
	float r = lua_tonumber(L, 18); float g = lua_tonumber(L, 19); float b = lua_tonumber(L, 20); float a = lua_tonumber(L, 21);
	(*v)->addQuad(
		x1, y1, u1, v1, 
		x2, y2, u2, v2, 
		x3, y3, u3, v3, 
		x4, y4, u4, v4, 
		r, g, b, a
	);
	return 0;
}

static int gl_vertexes_texture(lua_State *L)
{
	DORVertexes **v = (DORVertexes**)auxiliar_checkclass(L, "gl{vertexes}", 1);
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 2);
	lua_pushvalue(L, 2);
	(*v)->setTexture(t->tex, luaL_ref(L, LUA_REGISTRYINDEX));

	return 0;
}

static int gl_vertexes_shader(lua_State *L)
{
	DORVertexes **v = (DORVertexes**)auxiliar_checkclass(L, "gl{vertexes}", 1);
	shader_type *shader = (shader_type*)lua_touserdata(L, 2);
	(*v)->setShader(shader);
	return 0;
}

static int gl_vertexes_translate(lua_State *L)
{
	DORVertexes **v = (DORVertexes**)auxiliar_checkclass(L, "gl{vertexes}", 1);
	(*v)->translate(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	return 0;
}

static int gl_vertexes_rotate(lua_State *L)
{
	DORVertexes **v = (DORVertexes**)auxiliar_checkclass(L, "gl{vertexes}", 1);
	(*v)->rotate(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	return 0;
}

static int gl_vertexes_scale(lua_State *L)
{
	DORVertexes **c = (DORVertexes**)auxiliar_checkclass(L, "gl{vertexes}", 1);
	(*c)->scale(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	return 0;
}

/******************************************************************
 ** Lua declarations
 ******************************************************************/

static const struct luaL_Reg gl_renderer_reg[] =
{
	{"__gc", gl_renderer_free},
	{"add", gl_renderer_add},
	{"remove", gl_renderer_remove},
	{"toScreen", gl_renderer_toscreen},
	{NULL, NULL},
};

static const struct luaL_Reg gl_container_reg[] =
{
	{"__gc", gl_container_free},
	{"add", gl_container_add},
	{"remove", gl_container_remove},
	{"translate", gl_container_translate},
	{"rotate", gl_container_rotate},
	{"scale", gl_container_scale},
	{NULL, NULL},
};

static const struct luaL_Reg gl_vertexes_reg[] =
{
	{"__gc", gl_vertexes_free},
	{"quad", gl_vertexes_quad},
	{"texture", gl_vertexes_texture},
	{"shader", gl_vertexes_shader},
	{"translate", gl_vertexes_translate},
	{"rotate", gl_vertexes_rotate},
	{"scale", gl_vertexes_scale},
	{NULL, NULL},
};

const luaL_Reg rendererlib[] = {
	{"renderer", gl_renderer_new},
	{"vertexes", gl_vertexes_new},
	{"container", gl_container_new},
	{NULL, NULL}
};

int luaopen_renderer(lua_State *L)
{
	auxiliar_newclass(L, "gl{renderer}", gl_renderer_reg);
	auxiliar_newclass(L, "gl{vertexes}", gl_vertexes_reg);
	auxiliar_newclass(L, "gl{container}", gl_container_reg);
	luaL_openlib(L, "core.renderer", rendererlib, 0);
	return 1;
}
