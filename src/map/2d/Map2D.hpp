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
#ifndef _MAP2D_HPP_
#define _MAP2D_HPP_

#include <renderer-moderngl/Renderer.hpp>
#include <renderer-moderngl/VBO.hpp>
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
/****************************************************************************/

class Map2D;
class MapObjectRenderer;
class MapObjectProcessor;

/****************************************************************************
 ** An object on the map, at a given z/x/y coord
 ****************************************************************************/
class MapObject {
	friend Map2D;
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
	vec2 computed_screen_pos;

	float grid_x = 0, grid_y = 0; // Current position on the map (stored as float to avoid later convertion)

	float move_step = 0, move_max = 0, move_blur = 0;
	float move_twitch = 0;
	uint8_t move_twitch_dir = 0;
	int32_t move_start_x, move_start_y;
	float move_anim_dx = 0, move_anim_dy = 0;

	DisplayObject *displayobject = nullptr;
	int do_ref = LUA_NOREF;

	DORCallbackMap *cb = nullptr;

	MapObject *root = nullptr;
	MapObject *next = nullptr;
	int next_ref = LUA_NOREF;

public:
	MapObject(int64_t uid, uint8_t nb_textures, bool on_seen, bool on_remember, bool on_unknown, vec2 pos, vec2 size, float scale);
	~MapObject();

	void setCallback(int ref);
	void chain(MapObject *n, int ref);
	void setHidden(bool v) { hide = v; }
	void setSeen(bool v) { on_seen = v; }
	bool setTexture(uint8_t slot, GLuint tex, int ref, vec4 coords);
	void setDisplayObject(DisplayObject *d, int ref);
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
};

class MapObjectProcessor {
private:
	int32_t tile_w, tile_h;
public:
	MapObjectProcessor(int32_t tile_w, int32_t tile_h) : tile_w(tile_w), tile_h(tile_h) {}
	void processMapObject(RendererGL *renderer, MapObject *dm, float dx, float dy, vec4 color);
};

/****************************************************************************
 ** Map code & tools
 ****************************************************************************/

struct MapObjectSort {
	MapObject *m;
	float dx, dy, dw, dh;
	float dy_sort;
	vec4 color;
};

class Map2D : public SubRenderer, public IRealtime, public MapObjectProcessor {
private:
	int32_t tile_w, tile_h;
	int32_t z_off, w_off;
	int32_t zdepth, w, h;
	MapObject **map;
	int *map_ref;
	float *map_seens;
	bool *map_remembers;
	bool *map_lites;
	bool *map_important;

	vector<MapObjectSort*> sorting_mos;
	uint32_t sorting_mos_next = 0;
	uint8_t zdepth_sort_start = 0;

	int default_shader_ref = LUA_NOREF;
	shader_type *default_shader = nullptr;

	vec4 obscure = {0.6,0.6,0.6,1}, shown = {1,1,1,1}, tint = {1,1,1,1};

	vec2 viewport_top = vec2(0, 0);
	vec2 viewport_size = vec2(10, 10);

	bool mapchanged = true, seen_changed = true;

	float keyframes = 0;
	RendererGL renderer;

public:
	Map2D(int32_t z, int32_t w, int32_t h, int32_t tile_w, int32_t tile_h);
	virtual ~Map2D();
	virtual const char* getKind() { return "Map2D"; };

	inline int32_t mapOffset(int32_t z, int32_t x, int32_t y) { return z * z_off + x * w_off + y; }
	inline bool checkBounds(int32_t z, int32_t x, int32_t y) {
		if (z < 0 || z >= zdepth || x < 0 || x >= w || y < 0 || y >= h) return false;
		else return true;
	}
	inline MapObject* at(int32_t z, int32_t x, int32_t y) {
		return map[mapOffset(z, x, y)];
	}
	inline MapObject* set(int32_t z, int32_t x, int32_t y, MapObject *mo, int ref) {
		int32_t off = mapOffset(z, x, y);
		MapObject *old = map[off];
		if (old == mo) return old;

		if (map_ref[off] != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, map_ref[off]);
		map[off] = mo;
		map_ref[off] = ref;
		if (mo) { mo->grid_x = x; mo->grid_y = y; }
		return old;
	}
	inline void setSeen(int32_t x, int32_t y, float v) { map_seens[x * w_off + y] = v; }
	inline void setRemember(int32_t x, int32_t y, bool v) { map_remembers[x * w_off + y] = v; }
	inline void setLite(int32_t x, int32_t y, bool v) { map_lites[x * w_off + y] = v; }
	inline void setImportant(int32_t x, int32_t y, bool v) { map_important[x * w_off + y] = v; }
	inline void cleanSeen(float v) { std::fill_n(map_seens, w * h, v); }
	inline void cleanRemember(bool v) { std::fill_n(map_remembers, w * h, v); }
	inline void cleanLite(bool v) { std::fill_n(map_lites, w * h, v); }
	inline void cleanImportant(bool v) { std::fill_n(map_important, w * h, v); }
	inline float isSeen(int32_t x, int32_t y) { return map_seens[x * w_off + y]; }
	inline bool isRemember(int32_t x, int32_t y) { return map_remembers[x * w_off + y]; }
	inline bool isLite(int32_t x, int32_t y) { return map_lites[x * w_off + y]; }
	inline bool isImportant(int32_t x, int32_t y) { return map_important[x * w_off + y]; }
	inline vec2 getSize() { return {w, h}; }
	inline vec2 getTileSize() { return {tile_w, tile_h}; }
	inline uint8_t getDepth() { return zdepth; }

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

	void setShown(vec4 t) { shown = t; }
	void setObscure(vec4 t) { obscure = t; }
	void setTint(vec4 t) { tint = t; }
	void setDefaultShader(shader_type *s, int ref);

	void computeGrid(MapObject *m, int32_t dz, int32_t i, int32_t j, float seen);

	virtual void toScreen(mat4 cur_model, vec4 color);
	virtual void onKeyframe(float nb_keyframes);
};

/****************************************************************************
 ** DO-inheriting direct renderer for MapObjects
 ****************************************************************************/
class MapObjectRenderer : public SubRenderer, public MapObjectProcessor {
private:
	int32_t tile_w, tile_h;
	vector<tuple<MapObject*,int>> objs;

	RendererGL renderer;

public:
	MapObjectRenderer(int32_t tile_w, int32_t tile_h);
	virtual ~MapObjectRenderer();
	virtual const char* getKind() { return "MapObjectRenderer"; };

	void addMapObject(MapObject *dm, int ref);

	inline vec2 getTileSize() { return {tile_w, tile_h}; }

	virtual void toScreen(mat4 cur_model, vec4 color);
};

#endif
