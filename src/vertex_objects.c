/*

 audio.c, part of the Pipmak Game Engine
 Copyright (c) 2006-2007 Christian Walther

 Modified for:
 TE4 - T-Engine 4
 Copyright (C) 2009 - 2015 Nicolas Casalini

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

 */

#include "display.h"
#include "fov/fov.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "types.h"
#include "script.h"
#include "display.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "SFMT.h"
#include "main.h"
#include "vertex_objects.h"
#include "core_lua.h"

/**************************************************************
 * Vertex Objects
 **************************************************************/

static void update_vertex_size(lua_vertexes *vx, int size) {
	if (size <= vx->size) return;
	vx->size = size;
	vx->vertices = realloc(vx->vertices, 2 * sizeof(GLfloat) * size);
	vx->colors = realloc(vx->colors, 4 * sizeof(GLfloat) * size);
	vx->textures = realloc(vx->textures, 2 * sizeof(GLfloat) * size);
}

static int gl_new_vertex(lua_State *L) {
	int size = lua_tonumber(L, 1);
	if (!size) size = 4;
	lua_vertexes *vx = (lua_vertexes*)lua_newuserdata(L, sizeof(lua_vertexes));
	auxiliar_setclass(L, "gl{vertexes}", -1);

	vx->size = vx->nb = 0;
	vx->vertices = NULL; vx->colors = NULL; vx->textures = NULL;
	update_vertex_size(vx, size);

	return 1;
}

static int gl_free_vertex(lua_State *L) {
	lua_vertexes *vx = (lua_vertexes*)auxiliar_checkclass(L, "gl{vertexes}", 1);

	if (vx->size > 0) {
		free(vx->vertices);
		free(vx->colors);
		free(vx->textures);
	}

	lua_pushnumber(L, 1);
	return 1;
}

static int gl_vertex_add(lua_State *L) {
	lua_vertexes *vx = (lua_vertexes*)auxiliar_checkclass(L, "gl{vertexes}", 1);
	float x = luaL_checknumber(L, 2);
	float y = luaL_checknumber(L, 3);
	float u = luaL_checknumber(L, 4);
	float v = luaL_checknumber(L, 5);
	float r = luaL_checknumber(L, 6);
	float g = luaL_checknumber(L, 7);
	float b = luaL_checknumber(L, 8);
	float a = luaL_checknumber(L, 9);

	if (vx->nb + 1 > vx->size) update_vertex_size(vx, vx->nb + 1);

	vx->vertices[vx->nb * 2 + 0] = x;
	vx->vertices[vx->nb * 2 + 1] = y;

	vx->textures[vx->nb * 2 + 0] = u;
	vx->textures[vx->nb * 2 + 1] = v;
	
	vx->colors[vx->nb * 4 + 0] = r;
	vx->colors[vx->nb * 4 + 1] = g;
	vx->colors[vx->nb * 4 + 2] = b;
	vx->colors[vx->nb * 4 + 3] = a;

	lua_pushnumber(L, vx->nb++);
	return 1;
}

static int gl_vertex_add_quad(lua_State *L) {
	lua_vertexes *vx = (lua_vertexes*)auxiliar_checkclass(L, "gl{vertexes}", 1);
	float r = luaL_checknumber(L, 2);
	float g = luaL_checknumber(L, 3);
	float b = luaL_checknumber(L, 4);
	float a = luaL_checknumber(L, 5);

	lua_pushnumber(L, 1); lua_gettable(L, 6); float x1 = luaL_checknumber(L, -1); lua_pop(L, 1);
	lua_pushnumber(L, 2); lua_gettable(L, 6); float y1 = luaL_checknumber(L, -1); lua_pop(L, 1);
	lua_pushnumber(L, 3); lua_gettable(L, 6); float u1 = luaL_checknumber(L, -1); lua_pop(L, 1);
	lua_pushnumber(L, 4); lua_gettable(L, 6); float v1 = luaL_checknumber(L, -1); lua_pop(L, 1);

	lua_pushnumber(L, 1); lua_gettable(L, 7); float x2 = luaL_checknumber(L, -1); lua_pop(L, 1);
	lua_pushnumber(L, 2); lua_gettable(L, 7); float y2 = luaL_checknumber(L, -1); lua_pop(L, 1);
	lua_pushnumber(L, 3); lua_gettable(L, 7); float u2 = luaL_checknumber(L, -1); lua_pop(L, 1);
	lua_pushnumber(L, 4); lua_gettable(L, 7); float v2 = luaL_checknumber(L, -1); lua_pop(L, 1);

	lua_pushnumber(L, 1); lua_gettable(L, 8); float x3 = luaL_checknumber(L, -1); lua_pop(L, 1);
	lua_pushnumber(L, 2); lua_gettable(L, 8); float y3 = luaL_checknumber(L, -1); lua_pop(L, 1);
	lua_pushnumber(L, 3); lua_gettable(L, 8); float u3 = luaL_checknumber(L, -1); lua_pop(L, 1);
	lua_pushnumber(L, 4); lua_gettable(L, 8); float v3 = luaL_checknumber(L, -1); lua_pop(L, 1);

	lua_pushnumber(L, 1); lua_gettable(L, 9); float x4 = luaL_checknumber(L, -1); lua_pop(L, 1);
	lua_pushnumber(L, 2); lua_gettable(L, 9); float y4 = luaL_checknumber(L, -1); lua_pop(L, 1);
	lua_pushnumber(L, 3); lua_gettable(L, 9); float u4 = luaL_checknumber(L, -1); lua_pop(L, 1);
	lua_pushnumber(L, 4); lua_gettable(L, 9); float v4 = luaL_checknumber(L, -1); lua_pop(L, 1);

	if (vx->nb + 4 > vx->size) update_vertex_size(vx, vx->nb + 4);

	int i = vx->nb;
	vx->vertices[i * 2 + 0] = x1; vx->vertices[i * 2 + 1] = y1; vx->textures[i * 2 + 0] = u1; vx->textures[i * 2 + 1] = v1; i++;
	vx->vertices[i * 2 + 0] = x2; vx->vertices[i * 2 + 1] = y2; vx->textures[i * 2 + 0] = u2; vx->textures[i * 2 + 1] = v2; i++;
	vx->vertices[i * 2 + 0] = x3; vx->vertices[i * 2 + 1] = y3; vx->textures[i * 2 + 0] = u3; vx->textures[i * 2 + 1] = v3; i++;
	// vx->vertices[i * 2 + 0] = x1; vx->vertices[i * 2 + 1] = y1; vx->textures[i * 2 + 0] = u1; vx->textures[i * 2 + 1] = v1; i++;
	// vx->vertices[i * 2 + 0] = x3; vx->vertices[i * 2 + 1] = y3; vx->textures[i * 2 + 0] = u3; vx->textures[i * 2 + 1] = v3; i++;
	vx->vertices[i * 2 + 0] = x4; vx->vertices[i * 2 + 1] = y4; vx->textures[i * 2 + 0] = u4; vx->textures[i * 2 + 1] = v4; i++;
	
	for (i = vx->nb; i < vx->nb + 4; i++) {
		// printf("===c %d\n",i);
		vx->colors[i * 4 + 0] = r; vx->colors[i * 4 + 1] = g; vx->colors[i * 4 + 2] = b; vx->colors[i * 4 + 3] = a;
	}

	lua_pushnumber(L, vx->nb += 4);
	return 0;
}

static int gl_vertex_toscreen(lua_State *L) {
	lua_vertexes *vx = (lua_vertexes*)auxiliar_checkclass(L, "gl{vertexes}", 1);
	if (!vx->nb) return 0;
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);

	if (lua_isuserdata(L, 4))
	{
		GLuint *t = (GLuint*)auxiliar_checkclass(L, "gl{texture}", 4);
		tglBindTexture(GL_TEXTURE_2D, *t);
	}
	else if (lua_toboolean(L, 4))
	{
		// Do nothing, we keep the currently bound texture
	}
	else
	{
		tglBindTexture(GL_TEXTURE_2D, gl_tex_white);
	}

	float r = 1, g = 1, b = 1, a = 1;
	if (lua_isnumber(L, 5)) {
		r = luaL_checknumber(L, 5);
		g = luaL_checknumber(L, 5);
		b = luaL_checknumber(L, 5);
		a = luaL_checknumber(L, 5);
	}
	tglColor4f(r, g, b, a);
	glTranslatef(x, y, 0);
	glVertexPointer(2, GL_FLOAT, 0, vx->vertices);
	glColorPointer(4, GL_FLOAT, 0, vx->colors);
	glTexCoordPointer(2, GL_FLOAT, 0, vx->textures);
	glDrawArrays(GL_QUADS, 0, vx->nb);
	glTranslatef(-x, -y, 0);
	return 0;
}


const luaL_Reg voFuncs[] = {
	{"__gc", gl_free_vertex},
	{"addPoint", gl_vertex_add},
	{"addQuad", gl_vertex_add_quad},
	{"toScreen", gl_vertex_toscreen},
	{NULL, NULL}
};

const luaL_Reg volib[] = {
	{"new", gl_new_vertex},
	{NULL, NULL}
};

int luaopen_vo(lua_State *L)
{
	auxiliar_newclass(L, "gl{vertexes}", voFuncs);
	luaL_openlib(L, "core.vo", volib, 0);
	lua_pop(L, 1);
	return 1;
}
