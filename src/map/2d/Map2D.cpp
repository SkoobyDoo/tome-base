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

void MapObject::resetMoveAnim() {
	move_max = 0;
	move_anim_dx = move_anim_dy = 0;
}

void MapObject::setMoveAnim(int32_t startx, int32_t starty, float max, float blur, uint8_t twitch_dir, float twitch) {
	// If at rest use starting point
	if (!move_max) {
		move_start_x = startx;
		move_start_y = starty;
	// If already moving, compute starting point
	} else {
		move_start_x = move_anim_dx + startx;
		move_start_y = move_anim_dy + starty;
	}
	move_step = 0;
	move_max = max;
	move_blur = blur; // defaults to 0
	move_twitch_dir = twitch_dir; // defaults to 0 (which is equivalent to up or 8)
	move_twitch = twitch; // defaults to 0
}

inline vec2 MapObject::computeMoveAnim(float nb_keyframes) {
	if (!nb_keyframes) return {move_anim_dx, move_anim_dy};

	move_step += nb_keyframes;
	if (move_step >= move_max) move_max = 0; // Reset once in place

	if (move_max) {
		// Compute the distance to traverse from origin to self
		float adx = grid_x - move_start_x;
		float ady = grid_y - move_start_y;

		// Final step
		move_anim_dx = adx * move_step / move_max - adx;
		move_anim_dy = ady * move_step / move_max - ady;

		if (move_twitch) {
			float where = (0.5 - fabsf(move_step / move_max - 0.5)) * 2;
			if (move_twitch_dir == 4) move_anim_dx -= move_twitch * where;
			else if (move_twitch_dir == 6) move_anim_dx += move_twitch * where;
			else if (move_twitch_dir == 2) move_anim_dy += move_twitch * where;
			else if (move_twitch_dir == 1) { move_anim_dx -= move_twitch * where; move_anim_dy += move_twitch * where; }
			else if (move_twitch_dir == 3) { move_anim_dx += move_twitch * where; move_anim_dy += move_twitch * where; }
			else if (move_twitch_dir == 7) { move_anim_dx -= move_twitch * where; move_anim_dy -= move_twitch * where; }
			else if (move_twitch_dir == 9) { move_anim_dx += move_twitch * where; move_anim_dy -= move_twitch * where; }
			else move_anim_dy -= move_twitch * where;
		}

//			printf("==computing %f x %f : %f x %f // %d/%d\n", animdx, animdy, adx, ady, move_step, move_max);
	}
	return {move_anim_dx, move_anim_dy};
}

inline void MapObjectProcessor::processMapObject(RendererGL *renderer, MapObject *dm, float dx, float dy, float scrollx, float scrolly, vec4 color, mat4 *model) {
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
			if (model) {
				dl->list.push_back({(*model) * vec4(x1+scrollx, y1+scrolly, 0, 1), {tx1, ty1}, color});
				dl->list.push_back({(*model) * vec4(x2+scrollx, y1+scrolly, 0, 1), {tx2, ty1}, color});
				dl->list.push_back({(*model) * vec4(x2+scrollx, y2+scrolly, 0, 1), {tx2, ty2}, color});
				dl->list.push_back({(*model) * vec4(x1+scrollx, y2+scrolly, 0, 1), {tx1, ty2}, color});
			} else {
				dl->list.push_back({{x1+scrollx, y1+scrolly, 0, 1}, {tx1, ty1}, color});
				dl->list.push_back({{x2+scrollx, y1+scrolly, 0, 1}, {tx2, ty1}, color});
				dl->list.push_back({{x2+scrollx, y2+scrolly, 0, 1}, {tx2, ty2}, color});
				dl->list.push_back({{x1+scrollx, y2+scrolly, 0, 1}, {tx1, ty2}, color});
			}
			dl->list_map_info.push_back({dm->tex_coords[0], {(float)dm->grid_x, (float)dm->grid_y, 0.0, 0.0}});
			dl->list_map_info.push_back({dm->tex_coords[0], {(float)dm->grid_x, (float)dm->grid_y, 1.0, 0.0}});
			dl->list_map_info.push_back({dm->tex_coords[0], {(float)dm->grid_x, (float)dm->grid_y, 1.0, 1.0}});
			dl->list_map_info.push_back({dm->tex_coords[0], {(float)dm->grid_x, (float)dm->grid_y, 0.0, 1.0}});
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
MapObjectRenderer::MapObjectRenderer(float w, float h, float a, bool allow_cb, bool allow_shader)
	: w(w), h(h), a(a), allow_cb(allow_cb), allow_shader(allow_shader), MapObjectProcessor(w, h)
{
}

MapObjectRenderer::~MapObjectRenderer() {
	resetMapObjects();
}

DisplayObject* MapObjectRenderer::clone() {
	MapObjectRenderer *into = new MapObjectRenderer(w, h, a, allow_cb, allow_shader);
	this->cloneInto(into);
	return into;
}
void MapObjectRenderer::cloneInto(DisplayObject *_into) {
	DORFlatSortable::cloneInto(_into);
	MapObjectRenderer *into = dynamic_cast<MapObjectRenderer*>(_into);

	for (auto &it : mos) {
		int ref = LUA_NOREF;
		if (L && get<1>(it) != LUA_NOREF) {
			lua_rawgeti(L, LUA_REGISTRYINDEX, get<1>(it));
			ref = luaL_ref(L, LUA_REGISTRYINDEX);
		}
		into->addMapObject(get<0>(it), ref);
	}
}

void MapObjectRenderer::resetMapObjects() {
	for (auto &it : mos) {
		if (get<1>(it) != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, get<1>(it));
	}
	mos.clear();
	setChanged();
}

void MapObjectRenderer::addMapObject(MapObject *mo, int ref) {
	mos.emplace_back(mo, ref);
	setChanged();
}

void MapObjectRenderer::render(RendererGL *container, mat4& cur_model, vec4& cur_color, bool cur_visible) {
	if (!visible || !cur_visible) return;
	mat4 vmodel = cur_model * model;
	vec4 vcolor = cur_color * color;
	for (auto &it : mos) {		
		processMapObject(container, get<0>(it), 0, 0, 0, 0, vcolor, &vmodel);
	}
}

void MapObjectRenderer::sortZ(RendererGL *container, mat4& cur_model) {
	mat4 vmodel = cur_model * model;

	// We take a "virtual" point at zflat coordinates
	vec4 virtualz = vmodel * vec4(0, 0, 0, 1);
	sort_z = virtualz.z;
	sort_shader = NULL;
	sort_tex = {0,0,0};
	container->sorted_dos.push_back(this);
}

/*************************************************************************
 ** Map itself
 *************************************************************************/
Map2D::Map2D(int32_t z, int32_t w, int32_t h, int32_t tile_w, int32_t tile_h, int32_t mwidth, int32_t mheight)
	: zdepth(z), w(w), h(h), tile_w(tile_w), tile_h(tile_h), mwidth(mwidth), mheight(mheight), renderer(VBOMode::STREAM), MapObjectProcessor(tile_w, tile_h)
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

void Map2D::scroll(int32_t x, int32_t y, float smooth) {
	if (smooth) {
		// Not moving, use starting point
		if (!scroll_anim_max) 	{
			scroll_anim_start_x = mx;
			scroll_anim_start_y = my;
		// Already moving, compute starting point
		} else {
			scroll_anim_start_x = scroll_anim_dx + mx;
			scroll_anim_start_y = scroll_anim_dy + my;
		}
	} else {
		scroll_anim_start_x = x;
		scroll_anim_start_y = y;
	}

	scroll_anim_step = 0;
	scroll_anim_max = smooth;
	scroll_anim_dx = 0;
	scroll_anim_dy = 0;
	mx = x;
	my = y;	
}

inline vec2 Map2D::computeScrollAnim(float nb_keyframes) {
	if (!nb_keyframes) return {scroll_anim_dx, scroll_anim_dx};

	scroll_anim_step += nb_keyframes;
	if (scroll_anim_step >= scroll_anim_max) scroll_anim_max = 0; // Reset once in place

	if (scroll_anim_max) {
		// Compute the distance to traverse from origin to self
		float adx = mx - scroll_anim_start_x;
		float ady = my - scroll_anim_start_y;

		// Final step
		scroll_anim_dx = adx * scroll_anim_step / scroll_anim_max - adx;
		scroll_anim_dy = ady * scroll_anim_step / scroll_anim_max - ady;
	}
	return {scroll_anim_dx, scroll_anim_dy};
}

vec2 Map2D::getScroll() {
	return { -floor(scroll_anim_dx * tile_w), -floor(scroll_anim_dy * tile_h) };
}

inline void Map2D::computeGrid(MapObject *m, int32_t dz, int32_t i, int32_t j, float seen) {
	MapObject *dm;
	vec4 color = shown;

	float dx = floor((i - mx) * tile_w), dy = floor((j - my) * tile_h);

	/********************************************************
	 ** Select the color to use
	 ********************************************************/
	if (m->tint.r < 1) color.r = (color.r + m->tint.r) / 2;
	if (m->tint.g < 1) color.g = (color.g + m->tint.g) / 2;
	if (m->tint.b < 1) color.b = (color.b + m->tint.b) / 2;

	/********************************************************
	 ** Compute/display movement and motion blur
	 ********************************************************/
	m->computeMoveAnim(keyframes);
	// DGDGDGDG DO BLUR

	/********************************************************
	 ** Display the entity
	 ********************************************************/
	float dm_peel = 0;
	dm = m;
	while (dm) {
		MapObjectSort *so = getSorter();
		so->m = dm;
		so->dx = dx + floor((dm->pos.x + m->move_anim_dx) * tile_w);
		so->dy = dy + floor((dm->pos.y + m->move_anim_dy) * tile_h);
		so->dy_sort = j + dm->pos.y + m->move_anim_dy + ((float)dz / (zdepth)) + dm->size.y + dm_peel;
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

	computeScrollAnim(keyframes);

	float sx = -floor(scroll_anim_dx * tile_w), sy = -floor(scroll_anim_dy * tile_h);
	int32_t msx = mx + scroll_anim_dx, msy = my + scroll_anim_dy;
	int32_t mini = msx - 1, maxi = msx + mwidth + 2, minj = msy - 1, maxj = msy + mheight + 2;

	uint32_t start_sort = 0;
	initSorter();
	for (int32_t z = 0; z < zdepth; z++) {
		// DGDGDGDG add z-callbacks as DORCallbacks
		if (z == zdepth_sort_start) { start_sort = sorting_mos_next; }
		for (int32_t j = minj; j < maxj; j++) {
			for (int32_t i = mini; i < maxi; i++) {
				if (!checkBounds(z, i, j)) continue;
				MapObject *mo = at(z, i, j);
				if (!mo) continue;

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
		processMapObject(&renderer, so->m, so->dx, so->dy, sx, sy, so->color, nullptr);

	}
	renderer.toScreen(cur_model, color);

	keyframes = 0;
}

void Map2D::onKeyframe(float nb_keyframes) {
	keyframes += nb_keyframes;
}
