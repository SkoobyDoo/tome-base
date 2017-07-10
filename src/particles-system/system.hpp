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
}

#include <memory>
#include <algorithm>
#include <vector>
#include <string>
#include <unordered_map>

#define GLM_FORCE_INLINE
#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"
#include "glm/ext.hpp"

#include "core_loader.hpp"

extern lua_State *L;

using namespace std;
using namespace glm;

namespace particles {


enum ParticlesSlots2 : uint8_t { ORIGIN_POS, ROT_VEL, VEL, ACC, SIZE, MAX2 };
enum ParticlesSlots4 : uint8_t { POS, LIFE, TEXTURE, COLOR, COLOR_START, COLOR_STOP, MAX4 };

class System;
class ParticlesData {
public:
	uint32_t count = 0, max = 0;
	array<unique_ptr<vec2[]>, ParticlesSlots2::MAX2> slots2;
	array<unique_ptr<vec4[]>, ParticlesSlots4::MAX4> slots4;

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

	inline void kill(uint32_t id) {
		swapData(id, count - 1);
		count--;
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

class ShaderHolder {
public:
	shader_type *shader;
	int lua_shader_ref = LUA_NOREF;
	ShaderHolder(shader_type *shader, int ref) : shader(shader), lua_shader_ref(ref) {
		printf("Creating shader %d\n", shader->shader);
	};
	~ShaderHolder() {
		printf("Freeing shader %d\n", shader->shader);
		if (lua_shader_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, lua_shader_ref);
	};
};
typedef shared_ptr<ShaderHolder> spShaderHolder;

extern spShaderHolder default_particlescompose_shader;

#include "particles-system/generators.hpp"
#include "particles-system/updaters.hpp"
#include "particles-system/emitters.hpp"
#include "particles-system/renderer.hpp"

class System {
	friend class Emitter;
	friend class Ensemble;
private:
	ParticlesData list;

	vector<unique_ptr<Emitter>> emitters;
	vector<unique_ptr<Updater>> updaters;
	unique_ptr<Renderer> renderer;

public:
	System(uint32_t max, RendererBlend blend);
	inline bool isDead() { return list.count == 0 && emitters.size() == 0; }

	inline ParticlesData& getList() { return list; };

	void addEmitter(Emitter *emit);
	void addUpdater(Updater *updater);
	void finish();

	void setShader(spShaderHolder &shader);
	void setTexture(spTextureHolder &tex);

	void shift(float x, float y, bool absolute);
	void update(float nb_keyframes);
	void draw(mat4 &model);
	void print();
};


class Ensemble {
private:
	static unordered_map<string, spTextureHolder> stored_textures;
	static unordered_map<string, spNoiseHolder> stored_noises;
	static unordered_map<string, spShaderHolder> stored_shaders;
public:
	static spTextureHolder getTexture(const char *tex_str);
	static spNoiseHolder getNoise(const char *noise_str);
	static spShaderHolder getShader(lua_State *L, const char *shader_str);
	static void gcTextures();

private:
	bool dead = false;
	float speed = 1.0;
	float zoom = 1.0;
	vector<unique_ptr<System>> systems;
public:
	inline bool isDead() { return dead; };
	uint32_t countAlive();
	System *getRawSystem(uint8_t id) { if (id < 0 || id >= systems.size()) return nullptr; else return systems[id].get(); };
	void setZoom(float zoom) { this->zoom = zoom; };
	void setSpeed(float speed) { this->speed = speed; };
	void add(System *system);
	void shift(float x, float y, bool absolute);
	void update(float nb_keyframes);
	void draw(mat4 model);
	void draw(float x, float y);
};

}

#endif
