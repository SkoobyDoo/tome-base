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
#ifndef _PARTICLES_SYSTEM_HPP
#define _PARTICLES_SYSTEM_HPP

extern "C" {
#include "tgl.h"
#include "lua.h"
#include "auxiliar.h"
#include "useshader.h"
#include "refcleaner.h"
}

#include <memory>
#include <algorithm>
#include <vector>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <thread>
#include <mutex>
#ifdef MINGW_WIN_THREAD_COMPAT
#include "mingw.thread.h"
#include "mingw.mutex.h"
#endif
#include <atomic>
#include "muparser/include/muParser.h"

#define GLM_FORCE_INLINE
#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"
#include "glm/ext.hpp"

#include "displayobjects/Interfaces.hpp"

#include "core_loader.hpp"

extern lua_State *L;

using namespace std;
using namespace glm;

namespace particles {


enum ParticlesSlots2 : uint8_t { ORIGIN_POS, ROT_VEL, VEL, ACC, SIZE, LINKS, MAX2 };
enum ParticlesSlots4 : uint8_t { POS, LIFE, TEXTURE, COLOR, COLOR_START, COLOR_STOP, MAX4 };

class System;
class Ensemble;

class ParticlesData {
public:
	uint32_t count = 0, max = 0;
	array<unique_ptr<vec2[]>, ParticlesSlots2::MAX2> slots2;
	array<unique_ptr<vec4[]>, ParticlesSlots4::MAX4> slots4;
	vector<int32_t> pointdeleter;
	mutex mux;

	ParticlesData();

	void initSlot2(ParticlesSlots2 slot);
	void initSlot4(ParticlesSlots4 slot);

	inline vec2* getSlot2(ParticlesSlots2 slot) { return slots2[slot].get(); }
	inline vec4* getSlot4(ParticlesSlots4 slot) { return slots4[slot].get(); }

	inline void swapData(uint32_t a, uint32_t b) {
		for (auto &v : slots2) {
			if (v) std::swap(v[a], v[b]);
		}
		for (auto &v : slots4) {
			if (v) std::swap(v[a], v[b]);
		}
	}

	void dumpLinks() {
		vec2 *links = slots2[LINKS].get();
		printf("~~~~ DUMPING LINKS (%lx) ~~~~~\n", (long unsigned int)links);
		for (uint32_t i = 0; i < count; i++) {
			printf(" ~ [%d] : prev(%d), next(%d)\n", i, (int32_t)links[i].x, (int32_t)links[i].y);
		}
		printf("~~~~~~~~~~~~~~~~~~~~~~~~\n");
	}

	inline void kill(uint32_t id) {
		// Kill the whole chain at once
		if (slots2[LINKS]) {
			// dumpLinks();
			// printf("ParticlesData::kill() killing chain for %d\n", id);
			vec2 *links = slots2[LINKS].get();
			pointdeleter.clear();
			pointdeleter.push_back(id);

			int32_t curid = id;
			while (links[curid].x >= 0) {
				curid = links[curid].x;
				pointdeleter.push_back(curid);
			}
			curid = id;
			while (links[curid].y >= 0) {
				curid = links[curid].y;
				pointdeleter.push_back(curid);
			}
			sort(pointdeleter.rbegin(), pointdeleter.rend());

			// printf("pointDeleter contains:\n");
			// for (int32_t i : pointdeleter) printf(" - %d\n", i);

			for (int32_t i : pointdeleter) {
				count--;
				swapData(i, count);
				// Reindex the moved link
				vec2 &lcur = links[i];
				if (lcur.x >= 0) links[(uint32_t)lcur.x].y = i;
				if (lcur.y >= 0) links[(uint32_t)lcur.y].x = i;
			}
			// dumpLinks();
		} else {
			count--;
			swapData(id, count);
		}
	};

	void print();
};

class TextureHolder {
public:
	texture_type *tex;
	TextureHolder(texture_type *tex) : tex(tex) {
		printf("Creating particle texture %d\n", tex->tex);
	};
	~TextureHolder() {
		printf("Freeing particle texture %d\n", tex->tex);
		glDeleteTextures(1, &tex->tex);
		free((void*)tex);
	};
};
typedef shared_ptr<TextureHolder> spTextureHolder;

class NoiseHolder {
public:
	noise_data *noise;
	NoiseHolder(noise_data *noise) : noise(noise) {
		printf("Creating noise\n");
	};
	~NoiseHolder() {
		printf("Freeing noise\n");
		delete noise;
	};
};
typedef shared_ptr<NoiseHolder> spNoiseHolder;

class PointsListHolder {
public:
	points_list *list;
	PointsListHolder(points_list *list) : list(list) {
		printf("Creating points list\n");
	};
	~PointsListHolder() {
		printf("Freeing points list\n");
		delete list;
	};
};
typedef shared_ptr<PointsListHolder> spPointsListHolder;

class ShaderHolder {
public:
	shader_type *shader;
	int lua_shader_ref = LUA_NOREF;
	ShaderHolder(shader_type *shader, int ref) : shader(shader), lua_shader_ref(ref) {
		printf("Creating shader %d\n", shader->shader);
	};
	~ShaderHolder() {
		printf("Freeing shader %d\n", shader->shader);
		refcleaner(&lua_shader_ref);
	};
};
typedef shared_ptr<ShaderHolder> spShaderHolder;

class DefHolder {
public:
	int ref = LUA_NOREF;
	string expr;
	DefHolder(int ref, string &expr) : ref(ref), expr(expr) {
		printf("Creating def %d : %s\n", ref, expr.c_str());
	};
	~DefHolder() {
		printf("Freeing def %d : %s\n", ref, expr.c_str());
		refcleaner(&ref);
	};
};
typedef shared_ptr<DefHolder> spDefHolder;

extern spShaderHolder default_particlescompose_shader;

#include "particles-system/expr.hpp"
#include "particles-system/triggers.hpp"
#include "particles-system/events.hpp"
#include "particles-system/generators.hpp"
#include "particles-system/updaters.hpp"
#include "particles-system/emitters.hpp"
#include "particles-system/renderer.hpp"

enum class RendererType : uint8_t { Default, Line };

class System {
	friend class Emitter;
	friend class Ensemble;
private:
	mutex mux;

	bool dead = false;
	bool hidden = false;
	ParticlesData list;

	vector<unique_ptr<Emitter>> dead_emitters; // We keep them around because Ensemble::parametrized_values can refer to those still

	vector<unique_ptr<Emitter>> emitters;
	vector<unique_ptr<Updater>> updaters;

	RendererType renderer_type;
	unique_ptr<Renderer> renderer;

public:
	System(uint32_t max, RendererBlend blend, RendererType type = RendererType::Default);
	inline bool isDead() { return dead; }

	inline ParticlesData& getList() { return list; };

	void addEmitter(Emitter *emit);
	void addUpdater(Updater *updater);
	void finish();

	void fireTrigger(string &name);

	void setShader(spShaderHolder &shader);
	void setTexture(spTextureHolder &tex);
	void setHidden(bool hide) { hidden = hide; };

	void shift(float x, float y, bool absolute);
	void update(float nb_keyframes);
	void draw(mat4 &model);
	void print();
};

class ThreadedRunner;
class Ensemble {
	friend ThreadedRunner;
protected:
	static unordered_map<string, spTextureHolder> stored_textures;
	static unordered_map<string, spNoiseHolder> stored_noises;
	static unordered_map<string, spPointsListHolder> stored_points_lists;
	static unordered_map<string, spShaderHolder> stored_shaders;
	static unordered_map<string, spDefHolder> stored_defs;
public:
	static unordered_set<Ensemble*> all_ensembles;
	static spTextureHolder getTexture(const char *tex_str);
	static spNoiseHolder getNoise(const char *noise_str);
	static spPointsListHolder getPointsList(const char *image_str);
	static spShaderHolder getShader(lua_State *L, const char *shader_str);
	static int getDefinition(lua_State *L, const char *def_str);
	static void gcTextures();

private:
	int event_cb_ref = LUA_NOREF;
	unordered_map<string, uint32_t> events_triggers;

	bool dead = false;
	float speed = 1.0;
	float zoom = 1.0;
	vector<unique_ptr<System>> systems;

	int parameters_ref = LUA_NOREF;

	vector<tuple<float*, uint32_t>> parametrized_values;

public:
	Expression exprs;

	Ensemble();
	~Ensemble();

	inline bool isDead() { return dead; };
	uint32_t countAlive();
	System *getRawSystem(uint8_t id) { if (id < 0 || id >= systems.size()) return nullptr; else return systems[id].get(); };

	void getExpression(lua_State *L, float *dst, const char *expr_str, int env_id);

	void setZoom(float zoom) { this->zoom = zoom; };
	void setSpeed(float speed) { this->speed = speed; };

	void fireTrigger(string &name);
	inline void fireEvent(string *name) {
		auto it = events_triggers.find(*name);
		if (it != events_triggers.end()) it->second++;
		else events_triggers.emplace(*name, 1);
	}

	void setEventsCallback(int ref);

	void add(System *system);
	void storeParametersTable(int ref) { parameters_ref = ref; }
	void updateParameters(lua_State *L, int table_id);

	void shift(float x, float y, bool absolute);

	void update(float nb_keyframes);
	void draw(mat4 model);
	void draw(float x, float y);
};

extern int PC_lua_ref;
extern int math_mt_lua_ref;
extern void lua_particles_system_update_params(lua_State *L, Ensemble *e);

}

#endif
