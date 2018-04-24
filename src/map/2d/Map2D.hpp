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
#ifndef _MAP2D_HPP_
#define _MAP2D_HPP_

#include "displayobjects/Renderer.hpp"
#include "displayobjects/VBO.hpp"
#include "displayobjects/Particles.hpp"
#include <unordered_map>
#include <unordered_set>
#include <vector>

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
class DORCallbackMapZ : public DORCallback {
public:
	float sx, sy, z, keyframes;

	DO_STANDARD_CLONE_METHOD(DORCallbackMapZ);
	virtual const char* getKind() { return "DORCallbackMapZ"; };
	virtual void toScreen(mat4 cur_model, vec4 color) {
		if (cb_ref == LUA_NOREF) return;
		lua_rawgeti(L, LUA_REGISTRYINDEX, cb_ref);
		lua_checkstack(L, 4);
		lua_pushnumber(L, z);
		lua_pushnumber(L, keyframes);
		lua_pushnumber(L, sx);
		lua_pushnumber(L, sy);
		if (lua_pcall(L, 4, 1, 0))
		{
			printf("DORCallbackMapZ callback error: %s\n", lua_tostring(L, -1));
			lua_pop(L, 1);
		}
	};
};
/****************************************************************************/

class Map2D;
class MapObject;
class Minimap2D;
class MapObjectRenderer;
class MapObjectProcessor;

using ParticlesVector = vector<tuple<DORParticles*,int>>;
using sMapObject = shared_ptr<MapObject>;


/****************************************************************************
 ** An object on the map, at a given z/x/y coord
 ****************************************************************************/
class MapObject {
	friend Map2D;
	friend Minimap2D;
	friend MapObjectProcessor;
	friend MapObjectRenderer;
protected:
	int64_t uid = 0;
	bool valid = true;
	bool hide = false;

	const static uint8_t MAX_TEXTURES = 5;
	uint8_t nb_textures = 0;
	int textures_ref[MAX_TEXTURES];
	GLuint textures[MAX_TEXTURES];
	vec4 tex_coords[MAX_TEXTURES];

	shader_type *shader = nullptr;
	int shader_ref = LUA_NOREF;
	
	bool flip_x = false, flip_y = false;

	bool on_seen = false;
	bool on_remember = false;
	bool on_unknown = false;

	vec3 tint = {1, 1, 1};
	vec3 mm = {1, 1, 1}; // Minimap color

	float scale = 1;
	vec2 pos = {0, 0}, size = {1, 1};

	float grid_x = 0, grid_y = 0; // Current position on the map (stored as float to avoid later convertion)
	float last_x = 0, last_y = 0;
	bool last_set = false;

	float move_step = 0, move_max = 0, move_blur = 0;
	float move_twitch = 0;
	uint8_t move_twitch_dir = 0;
	float move_start_x, move_start_y;
	float move_anim_dx = 0, move_anim_dy = 0;

	DisplayObject *bdisplayobject = nullptr;
	DisplayObject *fdisplayobject = nullptr;
	int bdo_ref = LUA_NOREF;
	int fdo_ref = LUA_NOREF;
	ParticlesVector particles;

	DORCallbackMap *cb = nullptr;

	MapObject *root = nullptr;
	sMapObject next = nullptr;

	unordered_set<MapObjectRenderer*> mor_set;

public:
	MapObject(int64_t uid, uint8_t nb_textures, bool on_seen, bool on_remember, bool on_unknown, vec2 pos, vec2 size, float scale);
	~MapObject();

	int64_t getUID() { return uid; };
	void setCallback(int ref);
	void chain(sMapObject n);
	void setHidden(bool v) { hide = v; }
	void setSeen(bool v) { on_seen = v; }
	bool setTexture(uint8_t slot, GLuint tex, int ref, vec4 coords);
	void setDisplayObject(DisplayObject *d, int ref, bool front);
	void addParticles(DORParticles *p, int ref);
	void removeParticles(ParticlesVector::iterator *it);
	void removeParticles(DORParticles *p);
	void cleanParticles();
	void clearParticles();
	void setShader(shader_type *s, int ref);
	void flipX(bool v) { flip_x = v; if (next) return next->flipX(v); }
	void flipY(bool v) { flip_y = v; if (next) return next->flipY(v); }
	void invalidate() { valid = false; }
	void setTint(vec3 t) { tint = t; }
	void setMinimapColor(vec3 m) { mm = m; }
	inline bool isValid() { return valid; }
	inline bool isSeen() { return on_seen; }
	inline bool isRemember() { return on_remember; }
	inline bool isUnknown() { return on_unknown; }

	void resetMoveAnim();
	void setMoveAnim(int32_t startx, int32_t starty, float max, float blur, uint8_t twitch_dir, float twitch);
	vec2 computeMoveAnim(float nb_keyframes);

	void addMOR(MapObjectRenderer *mor);
	void removeMOR(MapObjectRenderer *mor);
	void notifyChangedMORs();
};

class MapObjectProcessor {
private:
	int32_t tile_w, tile_h;
	bool allow_cb, allow_do, allow_particles;
public:
	MapObjectProcessor(int32_t tile_w, int32_t tile_h, bool allow_cb, bool allow_do, bool allow_particles) : tile_w(tile_w), tile_h(tile_h), allow_cb(allow_cb), allow_do(allow_do), allow_particles(allow_particles) {}
	void processMapObject(RendererGL *renderer, MapObject *dm, float dx, float dy, vec4 color, mat4 *model = nullptr);
};

/****************************************************************************
 ** Map code & tools
 ****************************************************************************/

struct MapObjectSort {
	MapObject *m = nullptr;
	float dx, dy, dw, dh;
	float dy_sort;
	vec4 color;
};

class Map2D : public SubRenderer, public IRealtime, public MapObjectProcessor {
	friend Minimap2D;
private:
	// Map data
	int32_t tile_w, tile_h;
	int32_t z_off, w_off;
	int32_t zdepth, w, h;
	sMapObject *map;
	float *map_seens;
	bool *map_remembers;
	bool *map_lites;
	bool *map_important;

	// Viewport
	int32_t mwidth, mheight;
	ivec2 viewport_pos, viewport_size, viewport_dimension;

	// Scroll data
	int32_t mx = 0, my = 0;
	float scroll_anim_max = 0, scroll_anim_step = 0;
	float scroll_anim_start_x = 0, scroll_anim_start_y = 0;
	float scroll_anim_dx = 0, scroll_anim_dy = 0;

	// Sorter data
	vector<MapObjectSort*> sorting_mos;
	uint32_t sorting_mos_next = 0;
	uint8_t zdepth_sort_start = 0;

	// Shaders
	int default_shader_ref = LUA_NOREF;
	shader_type *default_shader = nullptr;

	// Z-layers
	DisplayObject **zobjects;

	// Visibility
	vec4 obscure = {0.6,0.6,0.6,1}, shown = {1,1,1,1}, tint = {1,1,1,1};
	bool mapchanged = true, seen_changed = true;

	// Vision data
	ivec2 seens_texture_size;
	GLuint seens_texture = 0;
	int8_t *seens_texture_data;
	VBO seens_vbo;
	int vision_shader_ref = LUA_NOREF;
	bool show_vision = true;

	// Grid lines
	VBO grid_lines_vbo;
	int grid_lines_shader_ref = LUA_NOREF;
	float show_grid_lines = 2;

	// Renderer
	float keyframes = 0;
	RendererGL renderer;

	// Minimap listing
	bool minimap_changed = true;
	unordered_set<Minimap2D*> minimap_dos;


public:
	Map2D(int32_t z, int32_t w, int32_t h, int32_t tile_w, int32_t tile_h, int32_t mwidth, int32_t mheight);
	virtual ~Map2D();
	virtual const char* getKind() { return "Map2D"; };

	/* Simple accessors */
	inline int32_t mapOffset(int32_t z, int32_t x, int32_t y) { return z * z_off + x * w_off + y; }
	inline bool checkBounds(int32_t z, int32_t x, int32_t y) {
		if (z < 0 || z >= zdepth || x < 0 || x >= w || y < 0 || y >= h) return false;
		else return true;
	}
	inline MapObject* at(int32_t z, int32_t x, int32_t y) {
		return map[mapOffset(z, x, y)].get();
	}
	inline MapObject* set(int32_t z, int32_t x, int32_t y, sMapObject mo) {
		int32_t off = mapOffset(z, x, y);
		MapObject *old = map[off].get();
		if (old == mo.get()) return old;

		map[off] = mo;
		if (mo) { mo->grid_x = x; mo->grid_y = y; }
		minimap_changed = true;
		return old;
	}
	inline void setSeen(int32_t x, int32_t y, float v) { map_seens[x * w_off + y] = v; minimap_changed = true; }
	inline void setRemember(int32_t x, int32_t y, bool v) { map_remembers[x * w_off + y] = v; minimap_changed = true; }
	inline void setLite(int32_t x, int32_t y, bool v) { map_lites[x * w_off + y] = v; minimap_changed = true; }
	inline void setImportant(int32_t x, int32_t y, bool v) { map_important[x * w_off + y] = v; }
	inline void cleanSeen(float v) { std::fill_n(map_seens, w * h, v); minimap_changed = true;}
	inline void cleanRemember(bool v) { std::fill_n(map_remembers, w * h, v); minimap_changed = true;}
	inline void cleanLite(bool v) { std::fill_n(map_lites, w * h, v); minimap_changed = true;}
	inline void cleanImportant(bool v) { std::fill_n(map_important, w * h, v); }
	inline float isSeen(int32_t x, int32_t y) { return map_seens[x * w_off + y]; }
	inline bool isRemember(int32_t x, int32_t y) { return map_remembers[x * w_off + y]; }
	inline bool isLite(int32_t x, int32_t y) { return map_lites[x * w_off + y]; }
	inline bool isImportant(int32_t x, int32_t y) { return map_important[x * w_off + y]; }
	inline vec2 getSize() { return {w, h}; }
	inline vec2 getTileSize() { return {tile_w, tile_h}; }
	inline uint8_t getDepth() { return zdepth; }
	void setShown(vec4 t) { shown = t; }
	void setObscure(vec4 t) { obscure = t; }
	void setTint(vec4 t) { tint = t; }
	void setDefaultShader(shader_type *s, int ref);

	/* Scrolling */
	void scroll(int32_t x, int32_t y, float smooth);
	vec2 getScroll();

	/* Z-layers */
	void setZCallback(int32_t z, int ref);

	/* MO sorter */
	void setZSortStart(uint8_t v) { zdepth_sort_start = v; }
	inline void initSorter() { sorting_mos_next = 0; }
	inline MapObjectSort* getSorter() {
		// When we lack space, we double it
		if (sorting_mos_next >= sorting_mos.size()) {
			sorting_mos.reserve(sorting_mos.size() * 2);
			while (sorting_mos.size() < sorting_mos.capacity()) sorting_mos.emplace_back(new MapObjectSort());
		}
		MapObjectSort *mos = sorting_mos[sorting_mos_next];
		sorting_mos_next++;
		return mos;
	};

	/* Compute visuals */
	void computeGrid(MapObject *m, int32_t dz, int32_t i, int32_t j);
	vec2 computeScrollAnim(float nb_keyframes);

	/* Vision handling */
	void setVisionShader(shader_type *s, int ref);
	void updateVision();
	void smoothVision(bool v);
	void enableVision(bool v) { show_vision = v; };

	/* Grid lines */
	void setGridLinesShader(shader_type *s, int ref);
	void setupGridLines();
	void enableGridLines(float size);

	/* Minimap */
	void addMinimap(Minimap2D *mm);
	void removeMinimap(Minimap2D *mm);

	/* Class superloads */
	virtual void toScreen(mat4 cur_model, vec4 color);
	virtual void onKeyframe(float nb_keyframes);
};

/****************************************************************************
 ** DO-inheriting direct renderer for MapObjects
 ****************************************************************************/
class MapObjectRenderer : public DORFlatSortable, public MapObjectProcessor {
private:
	vector<sMapObject> mos;
	bool allow_cb = false;
	bool allow_particles = false;
	float w, h;

	virtual void cloneInto(DisplayObject *into);

public:
	MapObjectRenderer(float w, float h, bool allow_cb, bool allow_particles);
	virtual ~MapObjectRenderer();
	virtual DisplayObject* clone(); // We dont use the standard definition, see .cpp file
	virtual const char* getKind() { return "MapObjectRenderer"; };

	void resetMapObjects();
	void addMapObject(sMapObject mo);
	void removeMapObject(MapObject *mo);

	virtual void render(RendererGL *container, mat4& cur_model, vec4& cur_color, bool cur_visible);
	// virtual void renderZ(RendererGL *container, mat4& cur_model, vec4& color, bool cur_visible);
	virtual void sortZ(RendererGL *container, mat4& cur_model);
};

void map2d_clean_particles();
void map2d_clean_particles_reset();

#endif
