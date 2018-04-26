/*
    TE4 - T-Engine 4
    Copyright (C) 2009 - 2018 Nicolas Casalini

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
#include "map/2d/Minimap2D.hpp"
#include <algorithm>
#include <unordered_set>

static unordered_set<MapObject*> mos_particles_clean;

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
	mos_particles_clean.erase(this);
	clearParticles();
	for (int i = 0; i < nb_textures; i++) {
		refcleaner(&textures_ref[i]);
	}
	refcleaner(&fdo_ref);
	refcleaner(&bdo_ref);
	refcleaner(&shader_ref);
	if (cb) delete cb;
	for (auto mor : mor_set) mor->removeMapObject(this); // Make sure that its impossible to access deleted stuff
}

void MapObject::setCallback(int ref) {
	if (!cb) cb = new DORCallbackMap();
	cb->setCallback(ref);
	notifyChangedMORs();
}

void MapObject::chain(sMapObject n) {
	next = n;
	MapObject *nm = n.get();
	while (nm) {
		nm->root = root;
		nm = nm->next.get();
	}
	notifyChangedMORs();
}

bool MapObject::setTexture(uint8_t slot, GLuint tex, int ref, vec4 coords) {
	if (slot >= MAX_TEXTURES) return false;
	refcleaner(&textures_ref[slot]);
	textures[slot] = tex;
	textures_ref[slot] = ref;
	tex_coords[slot] = coords;
	notifyChangedMORs();
	return true;
}

void MapObject::setDisplayObject(DisplayObject *d, int ref, bool front) {
	if (front) {
		refcleaner(&fdo_ref);
		fdisplayobject = d;
		fdo_ref = ref;
	} else {
		refcleaner(&bdo_ref);
		bdisplayobject = d;
		bdo_ref = ref;
	}
	notifyChangedMORs();
}

void MapObject::addMOR(MapObjectRenderer *mor) {
	mor_set.insert(mor);
}
void MapObject::removeMOR(MapObjectRenderer *mor) {
	mor_set.erase(mor);
}
void MapObject::notifyChangedMORs() {
	for (auto mor : mor_set) mor->setChanged();
}

void MapObject::addParticles(DORParticles *p, int ref) {
	particles.emplace_back(p, ref);
	notifyChangedMORs();
}
void MapObject::removeParticles(ParticlesVector::iterator *it) {
	refcleaner(&get<1>(**it));
	*it = particles.erase(*it);
	notifyChangedMORs();
}
void MapObject::removeParticles(DORParticles *p) {
	for (auto it = particles.begin(); it != particles.end(); it++) {
		if (get<0>(*it) == p) {
			refcleaner(&get<1>(*it));
			particles.erase(it);			
			break;
		}
	}
	notifyChangedMORs();
}
void MapObject::cleanParticles() {
	for (auto it = particles.begin(); it != particles.end(); ) {
		DORParticles *ps = get<0>(*it);
		if (ps->isDead()) removeParticles(&it);
		else it++;
	}		
}
void MapObject::clearParticles() {
	for (auto it = particles.begin(); it != particles.end(); it++) {
		refcleaner(&get<1>(*it));
	}
	particles.clear();
	notifyChangedMORs();
}

void MapObject::setShader(shader_type *s, int ref) {
	shader = s;
	refcleaner(&shader_ref);
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

inline bool MapObject::computeMoveAnim(float nb_keyframes) {
	if (!nb_keyframes) return move_max > 0;

	move_step += nb_keyframes;
	if (move_step >= move_max) {
		move_max = move_anim_dx = move_anim_dy = 0; // Reset once in place
	}

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
		return true;
	}
	return false;
}

inline void MapObjectProcessor::processMapObject(RendererGL *renderer, MapObject *dm, float dx, float dy, vec4 color, mat4 *model) {
	if (dm->hide) return;

	float base_x = dx, base_y = dy;
	dx += floor(dm->pos.x * tile_w);
	dy += floor(dm->pos.y * tile_h);

	float dw = dm->size.x, dh = dm->size.y;
	float x1, x2, y1, y2;

	if (dm->flip_x) { x2 = dx; x1 = tile_w * dw * dm->scale + dx; }
	else { x1 = dx; x2 = tile_w * dw * dm->scale + dx; }
	if (dm->flip_y) { y2 = dy; y1 = tile_h * dh * dm->scale + dy; }
	else { y1 = dy; y2 = tile_h * dh * dm->scale + dy; }

	if (allow_do && dm->bdisplayobject) {
		mat4 base;
		mat4 m = glm::translate(model ? *model : base, glm::vec3(base_x, base_y, 0));
		dm->bdisplayobject->render(renderer, m, color, true);
	}

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
		dl->list.push_back({(*model) * vec4(x1, y1, 0, 1), {tx1, ty1}, color});
		dl->list.push_back({(*model) * vec4(x2, y1, 0, 1), {tx2, ty1}, color});
		dl->list.push_back({(*model) * vec4(x2, y2, 0, 1), {tx2, ty2}, color});
		dl->list.push_back({(*model) * vec4(x1, y2, 0, 1), {tx1, ty2}, color});
	} else {
		dl->list.push_back({{x1, y1, 0, 1}, {tx1, ty1}, color});
		dl->list.push_back({{x2, y1, 0, 1}, {tx2, ty1}, color});
		dl->list.push_back({{x2, y2, 0, 1}, {tx2, ty2}, color});
		dl->list.push_back({{x1, y2, 0, 1}, {tx1, ty2}, color});
	}
	dl->list_map_info.push_back({dm->tex_coords[0], {(float)dm->grid_x, (float)dm->grid_y, 0.0, 0.0}});
	dl->list_map_info.push_back({dm->tex_coords[0], {(float)dm->grid_x, (float)dm->grid_y, 1.0, 0.0}});
	dl->list_map_info.push_back({dm->tex_coords[0], {(float)dm->grid_x, (float)dm->grid_y, 1.0, 1.0}});
	dl->list_map_info.push_back({dm->tex_coords[0], {(float)dm->grid_x, (float)dm->grid_y, 0.0, 1.0}});

	// DGDGDGDG: THIS DOES NOT WORK
	// Or rather, it does, but if the refcleaner comes between a particel death and a map renderer update
	// it will try to cann particle's toScreen whcih doesnt exist anymore
	// To fix particles would need to know they are inside a map and .. ugh
	if (allow_particles && dm->particles.size()) {
		float px = base_x + tile_w * dm->scale / 2, py = base_y + tile_h * dm->scale / 2;
		// Not on map, just display
		if (model) {
			mat4 m = glm::translate(*model, glm::vec3(px, py, 0));
			for (auto it = dm->particles.begin(); it != dm->particles.end(); ) {
				DORParticles *ps = get<0>(*it);
				if (ps->isDead()) {
					mos_particles_clean.insert(dm);
					++it;
				}
				else { ps->render(renderer, m, color, true); ++it; }
			}
		// On map, display and shift accordingly
		} else {
			// Compute the position with animation and absolute map positioning instead of screen positioning to be able ot deduce shift effect
			float nshiftx = floor((dm->root->grid_x + dm->root->move_anim_dx) * tile_w);
			float nshifty = floor((dm->root->grid_y + dm->root->move_anim_dy) * tile_h);

			if (dm->last_set) {
				mat4 m;
				m = glm::translate(m, glm::vec3(px, py, 0));
				for (auto it = dm->particles.begin(); it != dm->particles.end(); ) {
					DORParticles *ps = get<0>(*it);
					if (ps->isDead()) {
						mos_particles_clean.insert(dm);
						++it;
					} else {
						ps->shift(dm->last_x - nshiftx, dm->last_y - nshifty, false);
						ps->render(renderer, m, color, true);
						++it;
					}
				}
			}
			dm->last_x = nshiftx; dm->last_y = nshifty;
			dm->last_set = true;
		}
	}

	if (allow_do && dm->fdisplayobject) {
		mat4 base;
		mat4 m = glm::translate(model ? *model : base, glm::vec3(base_x, base_y, 0));
		dm->fdisplayobject->render(renderer, m, color, true);
	}

	if (allow_cb && L && dm->cb) {
		stopDisplayList(); // Needed to make sure we break texture chaining
		auto dl = getDisplayList(renderer);
		stopDisplayList(); // Needed to make sure we break texture chaining
		dm->cb->dx = base_x;
		dm->cb->dy = base_y;
		dm->cb->dw = tile_w * dw * dm->scale;
		dm->cb->dh = tile_h * dh * dm->scale;
		dm->cb->scale = dm->scale;
		dm->cb->tldx = dx;
		dm->cb->tldy = dy;
		dl->sub = dm->cb;
	}
}


/*************************************************************************
 ** MapObjectRender
 *************************************************************************/
MapObjectRenderer::MapObjectRenderer(float w, float h, bool allow_cb, bool allow_particles)
	: w(w), h(h), allow_cb(allow_cb), allow_particles(allow_particles), MapObjectProcessor(w, h, allow_cb, allow_cb, allow_particles)
{
}

MapObjectRenderer::~MapObjectRenderer() {
	resetMapObjects(); // Very important to cleanup all references and links
}

DisplayObject* MapObjectRenderer::clone() {
	MapObjectRenderer *into = new MapObjectRenderer(w, h, allow_cb, allow_particles);
	this->cloneInto(into);
	return into;
}
void MapObjectRenderer::cloneInto(DisplayObject *_into) {
	DORFlatSortable::cloneInto(_into);
	MapObjectRenderer *into = dynamic_cast<MapObjectRenderer*>(_into);
}

void MapObjectRenderer::resetMapObjects() {
	for (auto &it : mos) {
		get<0>(it)->removeMOR(this);
		refcleaner(&get<1>(it));
	}
	mos.clear();
	setChanged();
}

void MapObjectRenderer::addMapObject(sMapObject mo, int ref) {
	mos.emplace_back(mo, ref);
	mo->addMOR(this);
	setChanged();
}

void MapObjectRenderer::removeMapObject(MapObject *mo) {
	for (auto it = mos.begin(); it != mos.end(); it++) {
		if (get<0>(*it).get() == mo) {
			mos.erase(it);
			break;
		}
	}
	mo->removeMOR(this);
	setChanged();
}

void MapObjectRenderer::render(RendererGL *container, mat4& cur_model, vec4& cur_color, bool cur_visible) {
	if (!visible || !cur_visible) return;
	mat4 vmodel = cur_model * model;
	vec4 vcolor = cur_color * color;
	for (auto &it : mos) {
		MapObject *dm = get<0>(it).get();
		while (dm) {
			processMapObject(container, dm, 0, 0, vcolor, &vmodel);
			dm = dm->next.get();
		}
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
	: zdepth(z), w(w), h(h), tile_w(tile_w), tile_h(tile_h), mwidth(mwidth), mheight(mheight),
	MapObjectProcessor(tile_w, tile_h, true, true, true), seens_vbo(VBOMode::STATIC), grid_lines_vbo(VBOMode::STATIC)
{
	w_off = h;
	z_off = w * h;

	// Compute viewport, we make it a bit bigger than requested to be able to do smooth scrolling without black zones
	viewport_pos = {-50, -50};
	viewport_size = {mwidth + 50, mheight + 50};
	viewport_dimension = viewport_size - viewport_pos;

	// Init the map data
	map = new sMapObject[z * w * h];
	map_seens = new float[w * h]; std::fill_n(map_seens, w * h, 0);
	map_remembers = new bool[w * h]; std::fill_n(map_remembers, w * h, false);
	map_lites = new bool[w * h]; std::fill_n(map_lites, w * h, false);
	map_important = new bool[w * h]; std::fill_n(map_important, w * h, false);
	zobjects = new DisplayObject*[z]; std::fill_n(zobjects, z, nullptr);

	// Init vision data
	seens_texture_size = powerOfTwoSize(viewport_dimension.x, viewport_dimension.y);
	glGenTextures(1, &seens_texture);
	tglBindTexture(GL_TEXTURE_2D, seens_texture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, seens_texture_size.x, seens_texture_size.y, 0, GL_RED, GL_UNSIGNED_BYTE, NULL);
	seens_texture_data = new int8_t[seens_texture_size.x * seens_texture_size.y]; std:fill_n(seens_texture_data, seens_texture_size.x * seens_texture_size.y, 0);
	seens_vbo.setTexture(seens_texture);
	int32_t seenx = viewport_pos.x * tile_w, seeny = viewport_pos.y * tile_h;
	int32_t seenw = viewport_dimension.x * tile_w, seenh = viewport_dimension.y * tile_h;
	seens_vbo.addQuad(
		seenx,       seeny,       0, 0,
		seenx+seenw, seeny,       (float)viewport_dimension.x / (float)seens_texture_size.x, 0,
		seenx+seenw, seeny+seenh, (float)viewport_dimension.x / (float)seens_texture_size.x, (float)viewport_dimension.y / (float)seens_texture_size.y,
		seenx,       seeny+seenh, 0, (float)viewport_dimension.y / (float)seens_texture_size.y,
		1, 1, 1, 1
	);

	// Init renderers
	for (int32_t i = 0; i < z; i++) {
		RendererGL *renderer = new RendererGL(VBOMode::STREAM);
		renderer->setRendererName(strdup("map-layer"), false);
		renderer->setManualManagement(true);
		// renderer->countDraws(true);
		renderers.push_back(renderer);
		renderers_changed.push_back(true);
	}

	setupGridLines();
}

Map2D::~Map2D() {
	refcleaner(&default_shader_ref);
	delete[] map;
	delete[] map_seens;
	delete[] map_remembers;
	delete[] map_lites;
	delete[] map_important;
	delete[] zobjects;

	for (int32_t i = 0; i < zdepth; i++) delete renderers[i];

	for (auto &it : minimap_dos) it->mapDeath(this);

	delete[] seens_texture_data;
	glDeleteTextures(1, &seens_texture);
}

void Map2D::addMinimap(Minimap2D *mm) {
	minimap_dos.insert(mm);
}
void Map2D::removeMinimap(Minimap2D *mm) {
	minimap_dos.erase(mm);
}

void Map2D::smoothVision(bool v) {
	tglBindTexture(GL_TEXTURE_2D, seens_texture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, v ? GL_LINEAR : GL_NEAREST);
}

void Map2D::enableGridLines(float size) {
	show_grid_lines = size;
	setupGridLines();
}

extern GLuint gl_tex_white;
void Map2D::setupGridLines() {
	grid_lines_vbo.clear();
	if (!show_grid_lines) return;

	float size = show_grid_lines;
	int32_t grid_w = 1 + mwidth;
	int32_t grid_h = 1 + mheight;
	grid_lines_vbo.setTexture(gl_tex_white);

	int vi = 0, ci = 0, ti = 0, i;
	// Verticals
	for (i = 0; i < grid_w; i++) {
		grid_lines_vbo.addQuad(
			i * tile_w - size / 2, 0, 0, 0,
			i * tile_w + size / 2, 0, 1, 0,
			i * tile_w + size / 2, mheight * tile_h, 1, 1,
			i * tile_w - size / 2, mheight * tile_h, 0, 1,
			1, 1, 1, 1
		);
	}
	// Horizontals
	for (i = 0; i < grid_h; i++) {
		grid_lines_vbo.addQuad(
			0,		 i * tile_h - size / 2, 0, 0,
			0,		 i * tile_h + size / 2, 1, 0,
			mwidth * tile_w, i * tile_h + size / 2, 1, 1,
			mwidth * tile_w, i * tile_h - size / 2, 0, 1,
			1, 1, 1, 1
		);
	}
}

void Map2D::setDefaultShader(shader_type *s, int ref) {
	refcleaner(&default_shader_ref);
	default_shader = s;
	default_shader_ref = ref;
}

void Map2D::setVisionShader(shader_type *s, int ref) {
	refcleaner(&vision_shader_ref);
	vision_shader_ref = ref;
	seens_vbo.setShader(s);
}

void Map2D::setGridLinesShader(shader_type *s, int ref) {
	refcleaner(&grid_lines_shader_ref);
	grid_lines_shader_ref = ref;
	grid_lines_vbo.setShader(s);
}

void Map2D::setZCallback(int32_t z, int ref) {
	if (!checkBounds(z, 0, 0)) return;
	if (zobjects[z]) {
		printf("[Map2D] Error, setting zCallback (%d) over existing DO/CB\n", z);
		return;
	}

	DORCallbackMapZ *cb = new DORCallbackMapZ();
	cb->setCallback(ref);
	zobjects[z] = cb;
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

inline bool Map2D::computeScrollAnim(float nb_keyframes) {
	if (!nb_keyframes) return scroll_anim_max > 0;

	scroll_anim_step += nb_keyframes;
	if (scroll_anim_step >= scroll_anim_max) {
		scroll_anim_max = scroll_anim_dx = scroll_anim_dy = 0; // Reset once in place
	}

	if (scroll_anim_max) {
		// Compute the distance to traverse from origin to self
		float adx = mx - scroll_anim_start_x;
		float ady = my - scroll_anim_start_y;

		// Final step
		scroll_anim_dx = adx * scroll_anim_step / scroll_anim_max - adx;
		scroll_anim_dy = ady * scroll_anim_step / scroll_anim_max - ady;
		return true;
	}
	return false;
}

vec2 Map2D::getScroll() {
	return { -floor(scroll_anim_dx * tile_w), -floor(scroll_anim_dy * tile_h) };
}

inline void Map2D::computeGrid(MapObject *m, int32_t dz, int32_t i, int32_t j) {
	MapObject *dm;
	vec4 color = shown;

	float dx = floor(i * tile_w), dy = floor(j * tile_h);

	/********************************************************
	 ** Select the color to use
	 ********************************************************/
	if (m->tint.r < 1) color.r = (color.r + m->tint.r) / 2;
	if (m->tint.g < 1) color.g = (color.g + m->tint.g) / 2;
	if (m->tint.b < 1) color.b = (color.b + m->tint.b) / 2;

	/********************************************************
	 ** Compute/display movement
	 ********************************************************/
	if (m->computeMoveAnim(keyframes)) renderers_changed[dz] = true;
	
	/********************************************************
	 ** Display the entity
	 ********************************************************/
	dm = m;
	while (dm) {
		processMapObject(renderers[dz], dm, dx + floor(m->move_anim_dx * tile_w), dy + floor(m->move_anim_dy * tile_h), color, nullptr);
		dm = dm->next.get();
	}

	// Motion bluuuurr!
	if (m->move_max && m->move_blur && (m->move_step > 0)) {
		// Compute the distance to traverse from origin to self
		float adx = m->grid_x - m->move_start_x;
		float ady = m->grid_y - m->move_start_y;
		float blur_step_interval = m->move_step / m->move_blur;

		for (float step = 0; step <= m->move_step; step += blur_step_interval) {
			float blur_move_anim_dx = adx * step / m->move_max - adx;
			float blur_move_anim_dy = ady * step / m->move_max - ady;

			if (m->move_twitch) {
				float where = (0.5 - fabsf(step / m->move_max - 0.5)) * 2;
				if (m->move_twitch_dir == 4) blur_move_anim_dx -= m->move_twitch * where;
				else if (m->move_twitch_dir == 6) blur_move_anim_dx += m->move_twitch * where;
				else if (m->move_twitch_dir == 2) blur_move_anim_dy += m->move_twitch * where;
				else if (m->move_twitch_dir == 1) { blur_move_anim_dx -= m->move_twitch * where; blur_move_anim_dy += m->move_twitch * where; }
				else if (m->move_twitch_dir == 3) { blur_move_anim_dx += m->move_twitch * where; blur_move_anim_dy += m->move_twitch * where; }
				else if (m->move_twitch_dir == 7) { blur_move_anim_dx -= m->move_twitch * where; blur_move_anim_dy -= m->move_twitch * where; }
				else if (m->move_twitch_dir == 9) { blur_move_anim_dx += m->move_twitch * where; blur_move_anim_dy -= m->move_twitch * where; }
				else blur_move_anim_dy -= m->move_twitch * where;
			}

			dm = m;
			while (dm) {
				processMapObject(renderers[dz], dm, dx + floor((dm->pos.x + blur_move_anim_dx) * tile_w), dy + floor((dm->pos.y + blur_move_anim_dy) * tile_h), {color.r, color.g, color.b, 0.3 + (step / m->move_step) * 0.7}, nullptr);
				dm = dm->next.get();
			}
		}
	}
}

void Map2D::updateVision() {
	int32_t msx = mx, msy = my;
	// int32_t msx = mx + scroll_anim_dx, msy = my + scroll_anim_dy;
	int32_t mini = msx + viewport_pos.x, maxi = msx + viewport_size.x;
	int32_t minj = msy + viewport_pos.y, maxj = msy + viewport_size.y;

	for (int32_t j = minj; j < maxj; j++) {
		int32_t sj = j - minj;
		for (int32_t i = mini; i < maxi; i++) {
			// printf("%dx%d / %dx%d\n", i-mini, sj, viewport_dimension.x, viewport_dimension.y);
			int32_t idx = sj * seens_texture_size.x + (i - mini);
			if (!checkBounds(0, i, j)) seens_texture_data[idx] = 255;
			else {
				float seen = isSeen(i, j);
				if (seen) seens_texture_data[idx] = 255 - (seen < 0 ? 0 : (seen > 1 ? 1 : seen)) * 255;
				else if (isRemember(i, j)) seens_texture_data[idx] = obscure.a * 255;
				else seens_texture_data[idx] = 255;
			}
		}
	}

	tglBindTexture(GL_TEXTURE_2D, seens_texture);
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, seens_texture_size.x, seens_texture_size.y, GL_RED, GL_UNSIGNED_BYTE, seens_texture_data);
}

void Map2D::toScreen(mat4 cur_model, vec4 color) {
	color *= tint;

	computeScrollAnim(keyframes);

	float msx = -floor((mx + scroll_anim_dx) * tile_w), msy = -floor((my + scroll_anim_dy) * tile_h);
	float sx = -floor(scroll_anim_dx * tile_w), sy = -floor(scroll_anim_dy * tile_h);


	// Compute the smooth scrolling matrix offset
	mat4 scrollmodel = mat4();
	scrollmodel = glm::translate(scrollmodel, glm::vec3(sx, sy, 0));
	mat4 scur_model = cur_model * scrollmodel;

	mat4 mscrollmodel = mat4();
	mscrollmodel = glm::translate(mscrollmodel, glm::vec3(msx, msy, 0));
	mat4 mcur_model = cur_model * mscrollmodel;


	// DGDGDGDG Idea: define some layers as static and some as dynamic
	// static ones are generated for the whole level and we let GPU clip because they dont change often at all
	// dynamic one are generated for the screen and we do the clipping because they change every frame or close enough
	// DGDGDGDG Idea: define a max layer size, say 64x64, any map bigger is split into multiple sectors

	int32_t mini = 0, maxi = w;
	int32_t minj = 0, maxj = h;
	for (int32_t z = 0; z < zdepth; z++) {
		if (renderers_changed[z]) {
			renderers_changed[z] = false;
			renderers[z]->resetDisplayLists();
			renderers[z]->setChanged(true);

			// printf("------ recomputing Z %d\n", z);
			for (int32_t j = minj; j < maxj; j++) {
				for (int32_t i = mini; i < maxi; i++) {
					// printf("     * i, j %dx%d\n", i, j);
					if (!checkBounds(z, i, j)) continue;
					MapObject *mo = at(z, i, j);
					if (!mo) continue;

					float seen = isSeen(i, j);
					if ((mo->isSeen() && seen) || mo->isRemember() || mo->isUnknown()) {
						computeGrid(mo, z, i, j);
					}
				}
			}
		}

		// Render the layer
		renderers[z]->toScreen(mcur_model, color);
	}
	
	mat4 zmodel = mat4();
	vec4 zcolor = vec4(1, 1, 1, 1);
	// DGDGDGDG
	// for (int32_t z = 0; z < zdepth; z++) {
	// 	if (zobjects[z]) {
	// 		// DGDGDGDG: this is super-fugly, change it! Idealy do it all without callbacks
	// 		DORCallbackMapZ *mz = dynamic_cast<DORCallbackMapZ*>(zobjects[z]);
	// 		if (mz) {
	// 			mz->sx = sx;
	// 			mz->sy = sy;
	// 			mz->z = z;
	// 			mz->keyframes = keyframes;
	// 		}
	// 		zobjects[z]->render(&renderer, zmodel, zcolor, true);
	// 	}
	// }

	// Render the vision overlay	
	if (show_vision) {
		updateVision();
		seens_vbo.toScreen(scur_model);
	}

	// Render grid lines
	if (show_grid_lines) grid_lines_vbo.toScreen(scur_model);

	// Update minimaps
	if (minimap_changed) {
		minimap_changed = false;
		for (auto &it : minimap_dos) it->redrawMiniMap();
	}

	// We displayed, reset the frames counter
	keyframes = 0;
}

void Map2D::onKeyframe(float nb_keyframes) {
	keyframes += nb_keyframes;
}

void map2d_clean_particles() {
	if (mos_particles_clean.size() == 0) return;
	printf("[Map2D] Cleaning %ld MOs with some dead particles\n", mos_particles_clean.size());
	for (auto dm : mos_particles_clean) dm->cleanParticles();
	mos_particles_clean.clear();
}
void map2d_clean_particles_reset() {
	mos_particles_clean.clear();
}
