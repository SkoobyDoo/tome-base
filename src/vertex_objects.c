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
#include "core_display.h"

/**************************************************************
 * Vertex Objects
 **************************************************************/

void update_vertex_size(lua_vertexes *vx, int size) {
	if (size <= vx->size) return;
	vx->size = size;
	vx->vertices = realloc(vx->vertices, sizeof(vertex_data) * size);
	vx->ids = realloc(vx->ids, sizeof(int) * size);
}

lua_vertexes* vertex_new(lua_vertexes *vx, int size, unsigned int tex, render_mode mode) {
	if (!vx) vx = malloc(sizeof(lua_vertexes));

	vx->mode = mode;
	vx->kind = VO_QUADS;
	vx->changed = TRUE;
	vx->size = vx->nb = 0;
	vx->next_id = 1;
	vx->shader = NULL;
	vx->vertices = NULL; vx->ids = NULL;
	update_vertex_size(vx, size);

	vx->render = vertexes_renderer_new(mode);
	vx->tex = tex;
	return vx;
}

void vertex_free(lua_vertexes *vx, bool self_delete) {
	if (vx->size > 0) {
		free(vx->vertices);
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
	vx->vertices[i].x = x1; vx->vertices[i].y = y1; vx->vertices[i].u = u1; vx->vertices[i].v = v1; vx->vertices[i].r = r; vx->vertices[i].g = g; vx->vertices[i].b = b; vx->vertices[i].a = a; i++;
	vx->vertices[i].x = x2; vx->vertices[i].y = y2; vx->vertices[i].u = u2; vx->vertices[i].v = v2; vx->vertices[i].r = r; vx->vertices[i].g = g; vx->vertices[i].b = b; vx->vertices[i].a = a; i++;
	vx->vertices[i].x = x3; vx->vertices[i].y = y3; vx->vertices[i].u = u3; vx->vertices[i].v = v3; vx->vertices[i].r = r; vx->vertices[i].g = g; vx->vertices[i].b = b; vx->vertices[i].a = a; i++;
	vx->vertices[i].x = x4; vx->vertices[i].y = y4; vx->vertices[i].u = u4; vx->vertices[i].v = v4; vx->vertices[i].r = r; vx->vertices[i].g = g; vx->vertices[i].b = b; vx->vertices[i].a = a; i++;
	
	for (i = vx->nb; i < vx->nb + 4; i++) {
		vx->ids[i] = vx->next_id;
	}

	vx->nb += VERTEX_QUAD_SIZE;
	vx->changed = TRUE;
	return vx->next_id++;
}

void vertex_update_quad_texture(lua_vertexes *vx, int i, float u1, float v1, float u2, float v2, float u3, float v3, float u4, float v4) {
	vx->vertices[i].u = u1; vx->vertices[i].v = v1; i++;
	vx->vertices[i].u = u2; vx->vertices[i].v = v2; i++;
	vx->vertices[i].u = u3; vx->vertices[i].v = v3; i++;
	vx->vertices[i].u = u4; vx->vertices[i].v = v4; i++;

	vx->changed = TRUE;
}

void vertex_remove(lua_vertexes *vx, int start, int stop) {
	if (start == -1 || stop == -1) return;
	if (start >= vx->nb - 1) return;

	vx->changed = TRUE;

	int nextquad = stop + VERTEX_QUAD_SIZE;

	// Removing from the end is very easy
	if (nextquad >= vx->nb - 1) {
		vx->nb = start;
		return;
	}

	int untilend = vx->nb - nextquad;
	memmove(&vx->vertices[start], &vx->vertices[nextquad], untilend * sizeof(vertex_data));
	memmove(&vx->ids[start], &vx->ids[nextquad], untilend * sizeof(int));
	vx->nb -= nextquad - start;
}

void vertex_translate(lua_vertexes *vx, int start, int stop, float mx, float my) {
	if (start == -1 || stop == -1) return;
	if (start >= vx->nb) return;

	vx->changed = TRUE;

	stop += VERTEX_QUAD_SIZE - 1;
	if (stop >= vx->nb) stop = vx->nb - 1;

	int i;
	for (i = start; i <= stop; i++) {
		vx->vertices[i].x += mx;
		vx->vertices[i].y += my;
	}
}

void vertex_color(lua_vertexes *vx, int start, int stop, bool set, float r, float g, float b, float a) {
	if (start == -1 || stop == -1) return;
	if (start >= vx->nb) return;

	vx->changed = TRUE;

	stop += VERTEX_QUAD_SIZE - 1;
	if (stop >= vx->nb) stop = vx->nb - 1;

	int i;
	if (set) {
		for (i = start; i <= stop; i++) {
			vx->vertices[i].r = r;
			vx->vertices[i].g = g;
			vx->vertices[i].b = b;
			vx->vertices[i].a = a;
		}
	} else {
		for (i = start; i <= stop; i++) {
			vx->vertices[i].r *= r;
			vx->vertices[i].g *= g;
			vx->vertices[i].b *= b;
			vx->vertices[i].a *= a;
		}
	}
}

void vertex_toscreen(lua_vertexes *vx, int x, int y, int tex, bool ignore_shader) {
	if (tex == -1) {
		if (vx->tex) { tex = vx->tex; }
		else { tex = gl_tex_white; }
		vx->tex = tex;
	} else if (tex) vx->tex = tex;

	vertexes_renderer_toscreen((vertexes_renderer*)vx->render, vx, x, y, ignore_shader);
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
