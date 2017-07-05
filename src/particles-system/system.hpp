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

using namespace std;
using namespace glm;

namespace particles {

extern shader_type *default_particlescompose_shader;

enum ParticlesSlots2 : uint8_t { VEL, ACC, TEX, SIZE, MAX2 };
enum ParticlesSlots4 : uint8_t { POS, LIFE, COLOR, COLOR_START, COLOR_STOP, MAX4 };

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

#include "particles-system/generators.hpp"
#include "particles-system/updaters.hpp"
#include "particles-system/emitters.hpp"
#include "particles-system/renderer.hpp"

class System {
	friend class Emitter;
private:
	ParticlesData list;

	vector<unique_ptr<Emitter>> emitters;
	vector<unique_ptr<Updater>> updaters;
	Renderer renderer;

public:
	System(uint32_t max, RendererBlend blend);
	inline bool isDead() { return list.count == 0; }

	void addEmitter(Emitter *emit);
	void addUpdater(Updater *updater);
	void finish();

	void setShader(shader_type *shader);
	void setTexture(texture_type *tex);

	void shift(float x, float y, bool absolute);
	void update(float nb_keyframes);
	void draw(float x, float y);
	void print();
};

class Ensemble {
private:
	bool dead = false;
	vector<unique_ptr<System>> systems;
public:
	inline bool isDead() { return dead; };
	void add(System *system);
	void shift(float x, float y, bool absolute);
	void update(float nb_keyframes);
	void draw(float x, float y);
};

}

#endif
