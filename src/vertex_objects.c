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

void update_vertex_size(lua_vertexes *vx, int size) {
	if (size <= vx->size) return;
	vx->size = size;
	vx->vertices = realloc(vx->vertices, 2 * sizeof(GLfloat) * size);
	vx->colors = realloc(vx->colors, 4 * sizeof(GLfloat) * size);
	vx->textures = realloc(vx->textures, 2 * sizeof(GLfloat) * size);
	vx->ids = realloc(vx->ids, sizeof(int) * size);
}

lua_vertexes* vertex_new(lua_vertexes *vx, int size, unsigned int tex, render_mode mode) {
	if (!vx) vx = malloc(sizeof(lua_vertexes));

	vx->mode = mode;
	vx->kind = VO_QUADS;
	vx->changed = TRUE;
	vx->size = vx->nb = 0;
	vx->next_id = 1;
	vx->vertices = NULL; vx->colors = NULL; vx->textures = NULL; vx->ids = NULL;
	update_vertex_size(vx, size);

	vx->render = vertexes_renderer_new(mode);
	vx->tex = tex;
	return vx;
}

void vertex_free(lua_vertexes *vx, bool self_delete) {
	if (vx->size > 0) {
		free(vx->vertices);
		free(vx->colors);
		free(vx->textures);
		free(vx->ids);
	}
	vertexes_renderer_free((vertexes_renderer*)vx->render);
	if (self_delete) free(vx);	
}

int vertex_find(lua_vertexes *vx, int id) {
	int i;
	for (i = 0; i < vx->nb; i++) {
		if (vx->ids[i] == id) {
			return i;
		}
	}
	return -1;	
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

	vx->nb += VERTEX_QUAD_SIZE;
	vx->changed = TRUE;
	return vx->next_id++;
}


void vertex_update_quad_texture(lua_vertexes *vx, int i, float u1, float v1, float u2, float v2, float u3, float v3, float u4, float v4) {
	vx->textures[i * 2 + 0] = u1; vx->textures[i * 2 + 1] = v1; i++;
	vx->textures[i * 2 + 0] = u2; vx->textures[i * 2 + 1] = v2; i++;
	vx->textures[i * 2 + 0] = u3; vx->textures[i * 2 + 1] = v3; i++;
	vx->textures[i * 2 + 0] = u4; vx->textures[i * 2 + 1] = v4; i++;

	vx->changed = TRUE;
}

void vertex_remove(lua_vertexes *vx, int start, int nb) {
	if (!nb) return;
	if (start >= vx->nb) return;

	vx->changed = TRUE;

	// Removing from the end is very easy
	if (start + nb >= vx->nb) {
		vx->nb = start;
		return;
	}

	int stop = start + nb;
	int untilend = vx->nb - stop;
	int wordlen = 2 * sizeof(GLfloat);
	memmove(&vx->vertices[start*2], &vx->vertices[stop*2], untilend * wordlen);
	memmove(&vx->textures[start*2], &vx->textures[stop*2], untilend * wordlen);
	wordlen = 4 * sizeof(GLfloat);
	memmove(&vx->colors[start*4], &vx->colors[stop*4], untilend * wordlen);
	wordlen = 1 * sizeof(int);
	memmove(&vx->ids[start], &vx->ids[stop], untilend * wordlen);

	vx->nb -= nb;
}

void vertex_translate(lua_vertexes *vx, int start, int nb, float mx, float my) {
	if (!nb) return;
	if (start >= vx->nb) return;

	vx->changed = TRUE;

	int stop = start + nb;
	if (stop >= vx->nb) stop = vx->nb - 1;

	int i;
	for (i = start; i <= stop; i++) {
		vx->vertices[i*2+0] += mx;
		vx->vertices[i*2+1] += my;
	}
}

void vertex_color(lua_vertexes *vx, int start, int nb, bool set, float r, float g, float b, float a) {
	if (!nb) return;
	if (start >= vx->nb) return;

	vx->changed = TRUE;

	int stop = start + nb;
	if (stop >= vx->nb) stop = vx->nb - 1;

	int i;
	if (set) {
		for (i = start; i <= stop; i++) {
			vx->colors[i*4+0] = r;
			vx->colors[i*4+1] = g;
			vx->colors[i*4+2] = b;
			vx->colors[i*4+3] = a;
		}
	} else {
		for (i = start; i <= stop; i++) {
			vx->colors[i*4+0] *= r;
			vx->colors[i*4+1] *= g;
			vx->colors[i*4+2] *= b;
			vx->colors[i*4+3] *= a;
		}
	}
}

void vertex_toscreen(lua_vertexes *vx, int x, int y, int tex) {
	if (tex == -1) {
		if (vx->tex) { tex = vx->tex; }
		else { tex = gl_tex_white; }
	}

	vertexes_renderer_toscreen((vertexes_renderer*)vx->render, vx, x, y);
}

int vertex_quad_size() {
	return VERTEX_QUAD_SIZE;
}

void vertex_clear(lua_vertexes *vx) {
	vx->changed = TRUE;
	vx->nb = 0;
}

int luaopen_vo(lua_State *L)
{
	return 1;
}
