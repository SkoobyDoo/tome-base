-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2015 Nicolas Casalini
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Nicolas Casalini "DarkGod"
-- darkgod@te4.org

--------------------------------------------------------------------------
--------------------------------------------------------------------------
-- WARNING about all that code
-- It makes things way faster but makes it non-reentrant:
-- Do NOT call a FOV calc from withing a FOV calc
-- not that you'd want that anyway
--------------------------------------------------------------------------
--------------------------------------------------------------------------

require "engine.class"
local ffi = require "ffi"
local C = ffi.C

ffi.cdef[[
typedef float GLfloat;
typedef int GLuint;
typedef void vertexes_renderer;
typedef void shader_type;
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

	shader_type *shader;
	GLuint tex;
	void *render;
} lua_vertexes;


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

extern void renderer_pipe_start();
extern void renderer_pipe_stop();
extern void renderer_pipe_flush();
]]

local VERTEX_QUAD_SIZE = C.vertex_quad_size()
local vertexes_mt = { __gc = function(vo) C.vertex_free(vo, false) end,	__index = {
	prepareSize = C.update_vertex_size,
	find = function(vo, id) local i = C.vertex_find(vo, id) return i > -1 and i or nil end,
	getQuadSize = function() return VERTEX_QUAD_SIZE end,
	addQuadRaw = C.vertex_add_quad,
	addQuad = function(vo, r, g, b, a, p1, p2, p3, p4)
		return C.vertex_add_quad(vo,
			p1[1], p1[2], p1[3], p1[4], 
			p2[1], p2[2], p2[3], p2[4], 
			p3[1], p3[2], p3[3], p3[4], 
			p4[1], p4[2], p4[3], p4[4],
			r, g, b, a
		)
	end,
	updateQuadTexture = function(vo, id, p1, p2, p3, p4)
		return C.vertex_update_quad_texture(vo, id,
			p1[1], p1[2], 
			p2[1], p2[2], 
			p3[1], p3[2], 
			p4[1], p4[2]
		)
	end,
	remove = function(vo, start, stop) 
		local startid = C.vertex_find(vo, start)
		local stopid = C.vertex_find(vo, stop)
		C.vertex_remove(vo, startid, stopid)
	end,
	translate = function(vo, start, stop, mx, my)
		local startid = C.vertex_find(vo, start)
		local stopid = C.vertex_find(vo, stop)
		C.vertex_translate(vo, startid, stopid, mx, my)
	end,
	color = function(vo, start, stop, set, r, g, b, a)
		local startid = C.vertex_find(vo, start)
		local stopid = C.vertex_find(vo, stop)
		C.vertex_color(vo, startid, stopid, set, r, g, b, a)
	end,
	alpha = function(vo, start, stop, a)
		local startid = C.vertex_find(vo, start)
		local stopid = C.vertex_find(vo, stop)
		C.vertex_alpha(vo, startid, stopid, a)
	end,
	translateAll = function(vo, mx, my)
		C.vertex_translate(vo, 0, vo.nb - 1, mx, my)
	end,
	colorAll = function(vo, set, r, g, b, a)
		C.vertex_color(vo, 0, vo.nb - 1, set, r, g, b, a)
	end,
	alphaAll = function(vo, a)
		C.vertex_alpha(vo, 0, vo.nb - 1, a)
	end,
	append = function(vo, srcvo, start, stop)
		local shift = C.vertex_append(vo, srcvo, start and stop and true or false)
		if start and stop then
			return start + shift, stop + shift
		end
	end,
	clear = C.vertex_clear,
	clone = function(vo)
		local nvo = ffi.new("lua_vertexes")
		C.vertex_clone(nvo, vo)
		return nvo
	end,
	cloneByAppend = function(vo, start, stop)
		local nvo = core.vo.new()
		start, stop = nvo:append(vo, start, stop)
		return nvo, start, stop
	end,
	toScreen = function(vo, x, y, tex, r, g, b, a)
		if tex == true then tex = 0 end
		if tex == nil then tex = -1 end
		C.vertex_toscreen(vo, x, y, tex, r or 1, g or 1, b or 1, a or 1)
	end,
}}
local vertexes = ffi.metatype("lua_vertexes", vertexes_mt)

local vo = {}
core.vo = vo

vo.new = function(size, texture, kind, mode)
	local vo = ffi.new("lua_vertexes")
	if type(texture) == "userdata" then texture = texture:id() end
	C.vertex_new(vo, size or 24, texture or 0, kind or "VO_QUADS", mode or "VERTEX_DYNAMIC")
	return vo
end

vo.enablePipe = C.renderer_pipe_start
vo.disablePipe = C.renderer_pipe_stop
vo.flushPipe = C.renderer_pipe_flush

-- C.exit(0)
