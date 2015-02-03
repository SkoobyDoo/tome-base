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
	vx->ids = realloc(vx->ids, sizeof(int) * size);
}

int gl_new_vertex(lua_State *L) {
	int size = lua_tonumber(L, 1);
	if (!size) size = 4;
	lua_vertexes *vx = (lua_vertexes*)lua_newuserdata(L, sizeof(lua_vertexes));
	auxiliar_setclass(L, "gl{vertexes}", -1);

	vx->changed = TRUE;
	vx->size = vx->nb = 0;
	vx->next_id = 1;
	vx->vertices = NULL; vx->colors = NULL; vx->textures = NULL; vx->ids = NULL;
	update_vertex_size(vx, size);

	vx->tex = 0;
	if (lua_isuserdata(L, 2)) {
		GLuint *t = (GLuint*)auxiliar_checkclass(L, "gl{texture}", 2);
		vx->tex = *t;	
	} else if (lua_isnumber(L, 2)) {
		vx->tex = lua_tonumber(L, 2);
	}

	return 1;
}

static int gl_free_vertex(lua_State *L) {
	lua_vertexes *vx = (lua_vertexes*)auxiliar_checkclass(L, "gl{vertexes}", 1);

	if (vx->size > 0) {
		free(vx->vertices);
		free(vx->colors);
		free(vx->textures);
		free(vx->ids);
	}

	lua_pushnumber(L, 1);
	return 1;
}

static int gl_find_vertex(lua_State * L) {
	lua_vertexes *vx = (lua_vertexes*)auxiliar_checkclass(L, "gl{vertexes}", 1);
	int id = luaL_checknumber(L, 2);
	int i;
	for (i = 0; i < vx->nb; i++) {
		if (vx->ids[i] == id) {
			lua_pushnumber(L, i);
			return 1;
		}
	}
	lua_pushboolean(L, FALSE);
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

	vx->ids[vx->nb] = vx->next_id;
	lua_pushnumber(L, vx->next_id);
	vx->next_id++;
	vx->changed = TRUE;
	return 1;
}

static int gl_vertex_update(lua_State *L) {
	lua_vertexes *vx = (lua_vertexes*)auxiliar_checkclass(L, "gl{vertexes}", 1);
	int i = luaL_checknumber(L, 2);

	float x = luaL_checknumber(L, 3);
	float y = luaL_checknumber(L, 4);
	float u = luaL_checknumber(L, 5);
	float v = luaL_checknumber(L, 6);
	float r = luaL_checknumber(L, 7);
	float g = luaL_checknumber(L, 8);
	float b = luaL_checknumber(L, 9);
	float a = luaL_checknumber(L, 10);

	vx->vertices[i * 2 + 0] = x;
	vx->vertices[i * 2 + 1] = y;

	vx->textures[i * 2 + 0] = u;
	vx->textures[i * 2 + 1] = v;
	
	vx->colors[i * 4 + 0] = r;
	vx->colors[i * 4 + 1] = g;
	vx->colors[i * 4 + 2] = b;
	vx->colors[i * 4 + 3] = a;

	lua_pushboolean(L, TRUE);
	vx->changed = TRUE;
	return 1;
}

int vertex_add_quad(lua_vertexes *vx,
	float x1, float y1, float u1, float v1, 
	float x2, float y2, float u2, float v2, 
	float x3, float y3, float u3, float v3, 
	float x4, float y4, float u4, float v4, 
	float r, float g, float b, float a
) {
	if (vx->nb + 4 > vx->size) update_vertex_size(vx, vx->nb + 4);

	int i = vx->nb;
	vx->vertices[i * 2 + 0] = x1; vx->vertices[i * 2 + 1] = y1; vx->textures[i * 2 + 0] = u1; vx->textures[i * 2 + 1] = v1; i++;
	vx->vertices[i * 2 + 0] = x2; vx->vertices[i * 2 + 1] = y2; vx->textures[i * 2 + 0] = u2; vx->textures[i * 2 + 1] = v2; i++;
	vx->vertices[i * 2 + 0] = x3; vx->vertices[i * 2 + 1] = y3; vx->textures[i * 2 + 0] = u3; vx->textures[i * 2 + 1] = v3; i++;
	vx->vertices[i * 2 + 0] = x4; vx->vertices[i * 2 + 1] = y4; vx->textures[i * 2 + 0] = u4; vx->textures[i * 2 + 1] = v4; i++;
	
	for (i = vx->nb; i < vx->nb + 4; i++) {
		vx->colors[i * 4 + 0] = r; vx->colors[i * 4 + 1] = g; vx->colors[i * 4 + 2] = b; vx->colors[i * 4 + 3] = a;
		vx->ids[i] = vx->next_id;
	}

	vx->nb += 4;
	vx->changed = TRUE;
	return vx->next_id++;
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

	int id = vertex_add_quad(vx,
		x1, y1, u1, v1, 
		x2, y2, u2, v2, 
		x3, y3, u3, v3, 
		x4, y4, u4, v4, 
		r, g, b, a
	);
	lua_pushnumber(L, id);
	return 1;
}

static int gl_vertex_update_quad(lua_State *L) {
	lua_vertexes *vx = (lua_vertexes*)auxiliar_checkclass(L, "gl{vertexes}", 1);
	int bi = luaL_checknumber(L, 2);
	int i = bi;

	lua_pushnumber(L, 1); lua_gettable(L, 7);
	if (lua_isnumber(L, -1)) {
		float x1 = luaL_checknumber(L, -1); lua_pop(L, 1);
		lua_pushnumber(L, 2); lua_gettable(L, 7); float y1 = luaL_checknumber(L, -1); lua_pop(L, 1);
		vx->vertices[i * 2 + 0] = x1; vx->vertices[i * 2 + 1] = y1;
	}

	lua_pushnumber(L, 3); lua_gettable(L, 7);
	if (lua_isnumber(L, -1)) {
		float u1 = luaL_checknumber(L, -1); lua_pop(L, 1);
		lua_pushnumber(L, 4); lua_gettable(L, 7); float v1 = luaL_checknumber(L, -1); lua_pop(L, 1);
		vx->textures[i * 2 + 0] = u1; vx->textures[i * 2 + 1] = v1;
	}

	i = bi + 1;
	lua_pushnumber(L, 1); lua_gettable(L, 8);
	if (lua_isnumber(L, -1)) {
		float x2 = luaL_checknumber(L, -1); lua_pop(L, 1);
		lua_pushnumber(L, 2); lua_gettable(L, 8); float y2 = luaL_checknumber(L, -1); lua_pop(L, 1);
		vx->vertices[i * 2 + 0] = x2; vx->vertices[i * 2 + 1] = y2;
	}

	lua_pushnumber(L, 3); lua_gettable(L, 8);
	if (lua_isnumber(L, -1)) {
		float u2 = luaL_checknumber(L, -1); lua_pop(L, 1);
		lua_pushnumber(L, 4); lua_gettable(L, 8); float v2 = luaL_checknumber(L, -1); lua_pop(L, 1);
		vx->textures[i * 2 + 0] = u2; vx->textures[i * 2 + 1] = v2;
	}

	i = bi + 2;
	lua_pushnumber(L, 1); lua_gettable(L, 9);
	if (lua_isnumber(L, -1)) {
		float x3 = luaL_checknumber(L, -1); lua_pop(L, 1);
		lua_pushnumber(L, 2); lua_gettable(L, 9); float y3 = luaL_checknumber(L, -1); lua_pop(L, 1);
		vx->vertices[i * 2 + 0] = x3; vx->vertices[i * 2 + 1] = y3;
	}

	lua_pushnumber(L, 3); lua_gettable(L, 9);
	if (lua_isnumber(L, -1)) {
		float u3 = luaL_checknumber(L, -1); lua_pop(L, 1);
		lua_pushnumber(L, 4); lua_gettable(L, 9); float v3 = luaL_checknumber(L, -1); lua_pop(L, 1);
		vx->textures[i * 2 + 0] = u3; vx->textures[i * 2 + 1] = v3;
	}

	i = bi + 3;
	lua_pushnumber(L, 1); lua_gettable(L, 10);
	if (lua_isnumber(L, -1)) {
		float x4 = luaL_checknumber(L, -1); lua_pop(L, 1);
		lua_pushnumber(L, 2); lua_gettable(L, 10); float y4 = luaL_checknumber(L, -1); lua_pop(L, 1);
		vx->vertices[i * 2 + 0] = x4; vx->vertices[i * 2 + 1] = y4;
	}

	lua_pushnumber(L, 3); lua_gettable(L, 10);
	if (lua_isnumber(L, -1)) {
		float u4 = luaL_checknumber(L, -1); lua_pop(L, 1);
		lua_pushnumber(L, 4); lua_gettable(L, 10); float v4 = luaL_checknumber(L, -1); lua_pop(L, 1);
		vx->textures[i * 2 + 0] = u4; vx->textures[i * 2 + 1] = v4;
	}

	if (lua_isnumber(L, 3))	{
		float r = luaL_checknumber(L, 3);
		float g = luaL_checknumber(L, 4);
		float b = luaL_checknumber(L, 5);
		float a = luaL_checknumber(L, 6);
		for (i = bi; i < bi + 4; i++) {
			vx->colors[i * 4 + 0] = r; vx->colors[i * 4 + 1] = g; vx->colors[i * 4 + 2] = b; vx->colors[i * 4 + 3] = a;
		}
	}

	lua_pushboolean(L, TRUE);
	vx->changed = TRUE;
	return 1;
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
		if (vx->tex) { tglBindTexture(GL_TEXTURE_2D, vx->tex); }
		else { tglBindTexture(GL_TEXTURE_2D, gl_tex_white); }
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

static int gl_get_quad_size(lua_State *L) {
	lua_pushnumber(L, 4);
	return 1;
}


const luaL_Reg voFuncs[] = {
	{"__gc", gl_free_vertex},
	{"find", gl_find_vertex},
	{"getQuadSize", gl_get_quad_size},
	{"addPoint", gl_vertex_add},
	{"updatePoint", gl_vertex_update},
	{"addQuad", gl_vertex_add_quad},
	{"updateQuad", gl_vertex_update_quad},
	{"toScreen", gl_vertex_toscreen},
	{NULL, NULL}
};

const luaL_Reg volib[] = {
	{"new", gl_new_vertex},
	// {"text", gl_new_vertex_text},
	{NULL, NULL}
};

int luaopen_vo(lua_State *L)
{
	auxiliar_newclass(L, "gl{vertexes}", voFuncs);
	luaL_openlib(L, "core.vo", volib, 0);
	lua_pop(L, 1);
	return 1;
}
