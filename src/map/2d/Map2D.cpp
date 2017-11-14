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

extern "C" {
#include "lua.h"
#include "types.h"
#include "display.h"
#include <math.h>
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "main.h"
#include "script.h"
#include "useshader.h"
#include "assert.h"
}

#include "map/2d/Map2D.hpp"
#include <algorithm>


/*************************************************************************
 ** Map objects
 *************************************************************************/
MapObject::MapObject(int64_t uid, uint8_t nb_textures, bool on_seen, bool on_remember, bool on_unknown, vec2 pos, vec2 size, float scale)
	: uid(uid), nb_textures(nb_textures), on_seen(on_seen), on_remember(on_remember), on_unknown(on_unknown), pos(pos), size(size), scale(scale)
{
	for (int i = 0; i < MAX_TEXTURES; i++) {
		textures_ref[i] = LUA_NOREF;
		textures[i] = 0;
	}
	root = this;
}

MapObject::~MapObject() {
	for (int i = 0; i < nb_textures; i++) {
		if (textures_ref[i] != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, textures_ref[i]);
	}
	if (next_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, next_ref);
	if (do_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, do_ref);
	if (shader_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, shader_ref);
	if (cb) delete cb;
}

void MapObject::setCallback(int ref) {
	if (!cb) cb = new DORCallbackMap();
	cb->setCallback(ref);
}

void MapObject::chain(MapObject *n, int ref) {
	if (next_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, next_ref);
	next = n;
	next_ref = ref;
	n->root = root;
}

bool MapObject::setTexture(uint8_t slot, GLuint tex, int ref, vec4 coords) {
	if (slot >= MAX_TEXTURES) return false;
	if (textures_ref[slot] != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, textures_ref[slot]);
	textures[slot] = tex;
	textures_ref[slot] = ref;
	tex_coords[slot] = coords;
	return true;
}

void MapObject::setDisplayObject(DisplayObject *d, int ref) {
	if (do_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, do_ref);	
	displayobject = d;
	do_ref = ref;
}

void MapObject::setShader(shader_type *s, int ref) {
	shader = s;
	if (shader_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, shader_ref);
	shader_ref = ref;
}

inline void MapObjectProcessor::processMapObject(RendererGL *renderer, MapObject *dm, float dx, float dy, vec4 color) {
	float dw = dm->size.x, dh = dm->size.y;
	float x1, x2, y1, y2;

	if (dm->flip_x) {
		x2 = dx; x1 = tile_w * dw * dm->scale + dx;
	} else {
		x1 = dx; x2 = tile_w * dw * dm->scale + dx;
	}
	if (dm->flip_y) {
		y2 = dy; y1 = tile_h * dh * dm->scale + dy;
	} else {
		y1 = dy; y2 = tile_h * dh * dm->scale + dy;
	}

	if (!dm->hide) {
		if (dm->displayobject) {
			// DGDGDGDG: integrate that as a chained DO perhaps
			mat4 model = mat4();
			model = glm::translate(model, glm::vec3(x1, y1, 0));
			dm->displayobject->render(renderer, model, color, true);
			if (!dm->displayobject->independantRenderer()) {
				// map->changed = true; // DGDGDGDG: for t his and other similar eventually it'd be good to try and detect which aprts of the VBO need reconstructing and only do those
			}
		} else {
			float tx1 = dm->tex_coords[0].x, tx2 = dm->tex_coords[0].x + dm->tex_coords[0].z;
			float ty1 = dm->tex_coords[0].y, ty2 = dm->tex_coords[0].y + dm->tex_coords[0].w;

			shader_type *shader = default_shader;
			if (dm->shader) shader = dm->shader;
			else if (dm->root->shader) shader = dm->root->shader;
			else shader = default_shader;

			auto dl = getDisplayList(renderer, {dm->textures[0], 0, 0}, shader, VERTEX_MAP_INFO, RenderKind::QUADS);
		
			// Make sure we do not have to reallocate each step
			// DGDGDGDG: actually do it

			// Put it directly into the DisplayList
			dl->list.push_back({{x1, y1, 0, 1}, {tx1, ty1}, color});
			dl->list.push_back({{x2, y1, 0, 1}, {tx2, ty1}, color});
			dl->list.push_back({{x2, y2, 0, 1}, {tx2, ty2}, color});
			dl->list.push_back({{x1, y2, 0, 1}, {tx1, ty2}, color});
			dl->list_map_info.push_back({dm->tex_coords[0], {dx, dy, x2, y2}});
			dl->list_map_info.push_back({dm->tex_coords[0], {dx, dy, x2, y2}});
			dl->list_map_info.push_back({dm->tex_coords[0], {dx, dy, x2, y2}});
			dl->list_map_info.push_back({dm->tex_coords[0], {dx, dy, x2, y2}});
		}
	}

	if (L && dm->cb)
	{
	/*
		stopDisplayList(); // Needed to make sure we break texture chaining
		auto dl = getDisplayList(map->renderer);
		stopDisplayList(); // Needed to make sure we break texture chaining
		dm->cb->dx = dx - map->scroll_x;
		dm->cb->dy = dy - map->scroll_y;
		dm->cb->dw = tile_w * (dw) * (dm->scale);
		dm->cb->dh = tile_h * (dh) * (dm->scale);
		dm->cb->scale = dm->scale;
		dm->cb->tldx = tldx - map->scroll_x;
		dm->cb->tldy = tldy - map->scroll_y;
		dl->sub = dm->cb;
		*/
	}
	// DGDGDGDG: this needs to be done smartly, no actual CB here, but creation of a callback put into the DisplayList
	/*
	if (L && dm->cb_ref != LUA_NOREF)
	{
		lua_rawgeti(L, LUA_REGISTRYINDEX, dm->cb_ref);
		lua_checkstack(L, 8);
		lua_pushnumber(L, dx);
		lua_pushnumber(L, dy);
		lua_pushnumber(L, tile_w * (dw) * (dm->scale));
		lua_pushnumber(L, tile_h * (dh) * (dm->scale));
		lua_pushnumber(L, (dm->scale));
		lua_pushboolean(L, true);
		lua_pushnumber(L, tldx);
		lua_pushnumber(L, tldy);
		if (lua_pcall(L, 8, 1, 0))
		{
			printf("Display callback error: UID %ld: %s\n", dm->uid, lua_tostring(L, -1));
			lua_pop(L, 1);
		}
		lua_pop(L, 1);
	}
	*/
}


/*************************************************************************
 ** MapObjectRender
 *************************************************************************/
MapObjectRenderer::MapObjectRenderer(int32_t tile_w, int32_t tile_h)
	: tile_w(tile_w), tile_h(tile_h), renderer(VBOMode::STREAM), MapObjectProcessor(tile_w, tile_h)
{
}

MapObjectRenderer::~MapObjectRenderer() {
	for (auto& it : objs) {
		if (get<1>(it) != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, get<1>(it));
	}	
}

void MapObjectRenderer::addMapObject(MapObject *dm, int ref) {
	objs.emplace_back(dm, ref);
}

void MapObjectRenderer::toScreen(mat4 cur_model, vec4 color) {
	renderer.resetDisplayLists();
	renderer.setChanged(true);
	for (auto &it : objs) processMapObject(&renderer, get<0>(it), 0, 0, color);
	renderer.toScreen(cur_model, color);
}

/*************************************************************************
 ** Map itself
 *************************************************************************/
Map2D::Map2D(int32_t z, int32_t w, int32_t h, int32_t tile_w, int32_t tile_h)
	: zdepth(z), w(w), h(h), tile_w(tile_w), tile_h(tile_h), renderer(VBOMode::STREAM), MapObjectProcessor(tile_w, tile_h)
{
	w_off = h;
	z_off = w * h;

	map = new MapObject*[z * w * h];
	
	map_ref = new int[z * w * h]; std::fill_n(map_ref, z * w * h, LUA_NOREF);
	
	map_seens = new float[w * h]; std::fill_n(map_seens, w * h, 0);
	map_remembers = new bool[w * h]; std::fill_n(map_remembers, w * h, false);
	map_lites = new bool[w * h]; std::fill_n(map_lites, w * h, false);
	map_important = new bool[w * h]; std::fill_n(map_important, w * h, false);

	// Reserve some sorting space
	sorting_mos.reserve(8092);
	for (uint32_t i = 0; i < sorting_mos.capacity(); i++) sorting_mos.emplace_back(new MapObjectSort());

	renderer.setRendererName(strdup("map-layer"), false);
	renderer.setManualManagement(true);
	// renderer.countDraws(true);
}

Map2D::~Map2D() {
	if (default_shader_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, default_shader_ref);
	for (uint32_t i = 0; i < z * w * h; i++) {
		if (map_ref[i] != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, map_ref[i]);
	}
	delete[] map;
	delete[] map_ref;
	delete[] map_seens;
	delete[] map_remembers;
	delete[] map_lites;
	delete[] map_important;
	for (auto mos : sorting_mos) delete mos;
}

void Map2D::setDefaultShader(shader_type *s, int ref) {
	if (default_shader_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, default_shader_ref);
	default_shader = s;
	default_shader_ref = ref;
}

inline void Map2D::computeGrid(MapObject *m, int32_t dz, int32_t i, int32_t j, float seen) {
	MapObject *dm;
	vec4 color = shown;

	float dx = i * tile_w, dy = j * tile_h;

	/********************************************************
	 ** Select the color to use
	 ********************************************************/
	if (m->tint.r < 1) color.r = (color.r + m->tint.r) / 2;
	if (m->tint.g < 1) color.g = (color.g + m->tint.g) / 2;
	if (m->tint.b < 1) color.b = (color.b + m->tint.b) / 2;

	/********************************************************
	 ** Compute/display movement and motion blur
	 ********************************************************/
/*
	float animdx = 0, animdy = 0;
	float tlanimdx = 0, tlanimdy = 0;

	if (m->move_max)
	{
		map->changed = true;
		m->move_step += nb_keyframes;
		if (m->move_step >= m->move_max) m->move_max = 0; // Reset once in place

		if (m->move_max)
		{
			float adx = (float)i - m->oldx;
			float ady = (float)j - m->oldy + 0.5f*(i & is_hex);

			// Motion bluuuurr!
			if (m->move_blur)
			{
				int step;
				for (z = 1; z <= m->move_blur; z++)
				{
					step = m->move_step - z;
					if (step >= 0)
					{
						animdx = tlanimdx = tile_w * (adx * step / (float)m->move_max - adx);
						animdy = tlanimdy = tile_h * (ady * step / (float)m->move_max - ady);
						float dm_peel = 0;
						dm = m;
						while (dm)
						{
							map_object_sort *so = map->sort_mos[map->sort_mos_max++];
							so->m = m;
							so->dm = dm;
							so->z = dz;
							so->anim = 0;
							so->dx = dx + dm->dx * tile_w + animdx;
							so->dy = dy + dm->dy * tile_h + animdy;
							so->dy_sort = j + dm->dy + animdy + ((float)dz / (map->zdepth)) + dm->dh + dm_peel;
							so->tldx = dx + dm->dx * tile_w + tlanimdx;
							so->tldy = dy + dm->dy * tile_h + tlanimdy;
							so->r = r;
							so->g = b;
							so->b = b;
							so->a = ((dm->dy < 0) && up_important) ? a / 3 : a;
							so->i = i;
							so->j = j;
							dm = dm->next;
							dm_peel += 0.001;
						}
					}
				}
			}

			// Final step
			animdx = tlanimdx = adx * m->move_step / (float)m->move_max - adx;
			animdy = tlanimdy = ady * m->move_step / (float)m->move_max - ady;

			if (m->move_twitch) {
				float where = (0.5 - fabsf(m->move_step / (float)m->move_max - 0.5)) * 2;
				if (m->move_twitch_dir == 4) animdx -= m->move_twitch * where;
				else if (m->move_twitch_dir == 6) animdx += m->move_twitch * where;
				else if (m->move_twitch_dir == 2) animdy += m->move_twitch * where;
				else if (m->move_twitch_dir == 1) { animdx -= m->move_twitch * where; animdy += m->move_twitch * where; }
				else if (m->move_twitch_dir == 3) { animdx += m->move_twitch * where; animdy += m->move_twitch * where; }
				else if (m->move_twitch_dir == 7) { animdx -= m->move_twitch * where; animdy -= m->move_twitch * where; }
				else if (m->move_twitch_dir == 9) { animdx += m->move_twitch * where; animdy -= m->move_twitch * where; }
				else animdy -= m->move_twitch * where;
			}

//			printf("==computing %f x %f : %f x %f // %d/%d\n", animdx, animdy, adx, ady, m->move_step, m->move_max);
		}
	}

//	if ((j - 1 >= 0) && map->grids_important[i][j - 1] && map->grids[i][j-1][9] && !map->grids[i][j-1][9]->move_max) up_important = true;
	*/

	/********************************************************
	 ** Display the entity
	 ********************************************************/
	float dm_peel = 0;
	dm = m;
	while (dm)
	{
/*
		if (!dm->anim_max) anim = 0;
		else {
			dm->anim_step += (dm->anim_speed * nb_keyframes);
			anim_step = dm->anim_step;
			if (dm->anim_step >= dm->anim_max) {
				dm->anim_step = 0;
				if (dm->anim_loop == 0) dm->anim_max = 0;
				else if (dm->anim_loop > 0) dm->anim_loop--;
			}
			anim = (float)anim_step / dm->anim_max;
			map->changed = true;
		}
		dm->world_x = bdx + (dm->dx + animdx) * tile_w;
		dm->world_y = bdy + (dm->dy + animdy) * tile_h;
*/
	 	// if (m != dm && dm->shader) {
			// unbatchQuads((*vert_idx), (*col_idx));
			// // printf(" -- unbatch3\n");

			// for (zc = dm->nb_textures - 1; zc > 0; zc--)
			// {
			// 	if (multitexture_active) tglActiveTexture(GL_TEXTURE0+zc);
			// 	tglBindTexture(dm->textures_is3d[zc] ? GL_TEXTURE_3D : GL_TEXTURE_2D, dm->textures[zc]);
			// }
			// if (dm->nb_textures && multitexture_active) tglActiveTexture(GL_TEXTURE0); // Switch back to default texture unit

	 	// 	useShader(dm->shader, dx, dy, tile_w, tile_h, dm->tex_x[0], dm->tex_y[0], dm->tex_factorx[0], dm->tex_factory[0], r, g, b, a);
	 	// }

		MapObjectSort *so = getSorter();
		so->m = dm;
		so->dx = dx + (dm->pos.x /*+ animdx*/) * tile_w;
		so->dy = dy + (dm->pos.y /*+ animdy*/) * tile_h;
		so->dy_sort = j + dm->pos.y /*+ animdy*/ + ((float)dz / (zdepth)) + dm->size.y + dm_peel;
		so->color = color;
		dm = dm->next;
		dm_peel += 0.001;
	}
}

static bool sort_mos(MapObjectSort *i, MapObjectSort *j) {
	if (i->dy_sort == j->dy_sort) return i->dx < j->dx;
	else return i->dy_sort < j->dy_sort;
}

void Map2D::toScreen(mat4 cur_model, vec4 color) {
	color *= tint;

	renderer.resetDisplayLists();
	renderer.setChanged(true);

	int32_t mini = 0, maxi = w - 1, minj = 0, maxj = h - 1;

	uint32_t start_sort = 0;
	initSorter();
	for (int32_t z = 0; z < zdepth; z++) {
		// DGDGDGDG add z-callbacks as DORCallbacks
		if (z == zdepth_sort_start) { start_sort = sorting_mos_next; }
		for (int32_t j = minj; j < maxj; j++) {
			for (int32_t i = mini; i < maxi; i++) {
				MapObject *mo = at(z, i, j);
				if (!mo) continue;
				int32_t dx = i * tile_w;
				int32_t dy = j * tile_h;

				float seen = isSeen(i, j);
				if ((mo->isSeen() && seen) || mo->isRemember() || mo->isUnknown()) {
					computeGrid(mo, z, i, j, seen);
				}
			}
		}
	}
	// stable_sort(map->sort_mos, map->sort_mos + start_sort, sort_mos_shader);
	sort(sorting_mos.begin() + start_sort, sorting_mos.begin() + sorting_mos_next, sort_mos);
	// printf("sorted %d mos\n", map->sort_mos_max - start_sort);

	for (int spos = 0; spos < sorting_mos_next; spos++) {
		MapObjectSort *so = sorting_mos[spos];
		processMapObject(&renderer, so->m, so->dx, so->dy, so->color);

	}
	renderer.toScreen(cur_model, color);

	keyframes = 0;
}

void Map2D::onKeyframe(float nb_keyframes) {
	keyframes += nb_keyframes;
}
