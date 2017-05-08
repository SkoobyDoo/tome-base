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
#ifndef _MAP_HPP_
#define _MAP_HPP_

#include <renderer-moderngl/Renderer.hpp>
#include <renderer-moderngl/VBO.hpp>
#include <unordered_map>

/****************************************************************************
 ** A special DORCallback to handle what is needed by map code
 ****************************************************************************/
class DORCallbackMap : public DORCallback {
public:
	float dx, dy, dw, dh, scale, tldx, tldy;

	DO_STANDARD_CLONE_METHOD(DORCallbackMap);
	virtual const char* getKind() { return "DORCallbackMap"; };
	virtual void toScreen(mat4 cur_model, vec4 color) {
		if (cb_ref == LUA_NOREF) return;
		lua_rawgeti(L, LUA_REGISTRYINDEX, cb_ref);
		lua_checkstack(L, 8);
		lua_pushnumber(L, dx);
		lua_pushnumber(L, dy);
		lua_pushnumber(L, dw);
		lua_pushnumber(L, dh);
		lua_pushnumber(L, scale);
		lua_pushboolean(L, true);
		lua_pushnumber(L, tldx);
		lua_pushnumber(L, tldy);
		if (lua_pcall(L, 8, 1, 0))
		{
			printf("DORCallbackMap callback error: %s\n", lua_tostring(L, -1));
			lua_pop(L, 1);
		}
	};
};
/****************************************************************************/

enum display_last_kind {DL_NONE, DL_TRUE_LAST, DL_TRUE};

struct map_object {
	int nb_textures;
	int *textures_ref;
	GLuint *textures;
	GLfloat *tex_x, *tex_y, *tex_factorx, *tex_factory;
	bool *textures_is3d;
	shader_type *shader;
	int shader_ref;
	int cur_x, cur_y;
	float dx, dy, scale, world_x, world_y;
	float animdx, animdy;
	float oldrawdx, oldrawdy;
	float dw, dh;
	float tint_r;
	float tint_g;
	float tint_b;
	float mm_r;
	float mm_g;
	float mm_b;
	bool on_seen;
	bool on_remember;
	bool on_unknown;
	bool valid;
	bool flip_x, flip_y;
	float oldx, oldy;
	float move_step, move_max, move_blur, move_twitch_dir;
	float move_twitch;
	int anim_max, anim_loop;
	float anim_step, anim_speed;
	enum display_last_kind display_last;
	long uid;

	DisplayObject *displayobject;
	int do_ref;

	DORCallbackMap *cb;

	map_object *next;
	int next_ref;
};

struct map_object_sort {
	map_object *m, *dm;
	int z;
	float anim;
	float dx, dy, dy_sort;
	float tldx, tldy;
	float r, g, b, a;
	int i, j;
};

struct map_type {
	map_object_sort **sort_mos;
	int sort_mos_max;
	map_object* ***grids;
	int ***grids_ref;
	float *grids_seens;
	bool **grids_remembers;
	bool **grids_lites;
	bool **grids_important;

	GLubyte *minimap;
	GLuint mm_texture;
	int mm_w, mm_h;
	int mm_rw, mm_rh;
	int minimap_gridsize, old_minimap_gridsize;

	int nb_grid_lines_vertices;
	DORVertexes *grid_lines;
	RendererGL *grid_lines_renderer;

	GLubyte *seens_map;
	int seens_map_w, seens_map_h;

	int default_shader_ref;
	shader_type *default_shader;

	int *z_callbacks;

	GLuint seens_texture;

	int mo_list_ref;

	int is_hex;

	// Map parameters
	float obscure_r, obscure_g, obscure_b, obscure_a;
	float shown_r, shown_g, shown_b, shown_a;
	float tint_r, tint_g, tint_b, tint_a;

	// Map size
	int w;
	int h;
	int zdepth;
	int tile_w, tile_h;
	GLfloat tex_tile_w[3], tex_tile_h[3];

	// Scrolling
	float scroll_x, scroll_y;
	int mx, my, mwidth, mheight;
	float oldmx, oldmy;
	float move_step, move_max;
	float used_mx, used_my;
	float used_animdx, used_animdy;
	int seensinfo_w;
	int seensinfo_h;
	bool seen_changed;

	// Render processing
	bool changed;
	RendererGL *renderer;
	unordered_map<string, float> *shader_to_shaderkind;
	VBO *seens_vbo;
	VBO *mm_vbo;
};

extern void map_toscreen(lua_State *L, map_type *map, int x, int y, float nb_keyframes, bool always_show, mat4 model, vec4 color);
extern void minimap_toscreen(map_type *map, mat4 model, int gridsize, int mdx, int mdy, int mdw, int mdh, float transp);

#endif
