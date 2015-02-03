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

typedef struct
{
	enum{ VO_SIMPLE, VO_TEXT } kind;
	int nb, size;
	int next_id;
	int *ids;
	GLfloat *vertices;
	GLfloat *colors;
	GLfloat *textures;

	bool changed;

	GLuint tex;
} lua_vertexes;

extern int luaopen_vo(lua_State *L);
extern int gl_new_vertex(lua_State *L);
extern int vertex_add_quad(lua_vertexes *vx,
	float x1, float y1, float u1, float v1, 
	float x2, float y2, float u2, float v2, 
	float x3, float y3, float u3, float v3, 
	float x4, float y4, float u4, float v4, 
	float r, float g, float b, float a
);

#endif
