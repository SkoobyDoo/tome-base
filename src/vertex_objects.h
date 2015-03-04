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
#ifndef _VO_H_
#define _VO_H_

#include "tgl.h"
#include "useshader.h"

#define VERTEX_QUAD_SIZE 4
#define VERTEX_TRIANGLE_SIZE 3

typedef enum {
	VERTEX_STATIC = 1,
	VERTEX_DYNAMIC = 2,
	VERTEX_STREAM = 3,
} render_mode;

typedef enum{
	VO_POINTS = 1,
	VO_QUADS = 2,
	VO_TRIANGLE_FAN = 3,
} vertex_mode;

typedef struct {
	GLfloat x, y;
	GLfloat u, v;
	GLfloat r, g, b, a;
} vertex_data;

typedef struct
{
	render_mode mode;
	vertex_mode kind;
	int nb, size;
	int *ids;

	vertex_data *vertices;
	bool changed;

	GLuint tex;
	void *render;
} lua_vertexes;

extern int luaopen_vo(lua_State *L);

extern lua_vertexes* vertex_new(lua_vertexes *vx, int size, unsigned int tex, vertex_mode kind, render_mode mode);
extern lua_vertexes* vertex_clone(lua_vertexes *vx, lua_vertexes *srcvx);
extern void vertex_free(lua_vertexes *vx, bool self_delete);
extern void update_vertex_size(lua_vertexes *vx, int size);
extern int vertex_find(lua_vertexes *vx, int id);
extern int vertex_quad_size();
extern int vertex_add_point(lua_vertexes *vx,
	float x1, float y1, float u1, float v1, 
	float r, float g, float b, float a
);
extern int vertex_add_quad(lua_vertexes *vx,
	float x1, float y1, float u1, float v1, 
	float x2, float y2, float u2, float v2, 
	float x3, float y3, float u3, float v3, 
	float x4, float y4, float u4, float v4, 
	float r, float g, float b, float a
);
extern void vertex_update_quad_texture(lua_vertexes *L, int i, float u1, float v1, float u2, float v2, float u3, float v3, float u4, float v4);
extern void vertex_translate(lua_vertexes *vx, int start, int nb, float mx, float my);
extern void vertex_color(lua_vertexes *vx, int start, int nb, bool set, float r, float g, float b, float a);
extern void vertex_alpha(lua_vertexes *vx, int start, int stop, float a);
extern void vertex_remove(lua_vertexes *vx, int start, int nb);
extern void vertex_clear(lua_vertexes *vx);
extern int vertex_append(lua_vertexes *vx, lua_vertexes *srcvx, bool newids);
extern void vertex_toscreen(lua_vertexes *vx, int x, int y, int tex, float r, float g, float b, float a);

#include "renderer.h"

#endif
