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
#include "display_sdl.h"
}
#include "particles-system/system.hpp"
#include "core_loader.hpp"

namespace particles {

/********************************************************************
 ** ParticlesData
 ********************************************************************/

unordered_map<ParticlesSlots2, string> particles_slots2_names({
	{VEL, "vel"},
	{ACC, "acc"},
	{SIZE, "size"},
	{ORIGIN_POS, "origin pos"},
});
unordered_map<ParticlesSlots4, string> particles_slots4_names({
	{POS, "pos"},
	{TEXTURE, "texture"},
	{LIFE, "life"},
	{COLOR, "color"},
	{COLOR_START, "color_start"},
	{COLOR_STOP, "color_stop"},
});


ParticlesData::ParticlesData() {
	for (uint8_t slot = 0; slot < ParticlesSlots2::MAX2; slot++) slots2[slot] = nullptr;
	for (uint8_t slot = 0; slot < ParticlesSlots4::MAX4; slot++) slots4[slot] = nullptr;
}

void ParticlesData::initSlot2(ParticlesSlots2 slot) {
	if (slots2[slot]) return;
	slots2[slot].reset(new vec2[max]);
}
void ParticlesData::initSlot4(ParticlesSlots4 slot) {
	if (slots4[slot]) return;
	slots4[slot].reset(new vec4[max]);
}

void ParticlesData::print() {
	printf("ParticlesData:\n");
	for (uint32_t i = 0; i < max; i++) {
		printf(" - p%d\n", i);
		uint8_t slotid = 0; for (auto &slot : slots2) {
			if (slot) {
				vec2 v = slot[i];
				printf("   * %s : %f x %f\n", particles_slots2_names[(ParticlesSlots2)slotid].c_str(), v.x, v.y);
			}
			slotid++;
		}
		slotid = 0; for (auto &slot : slots4) {
			if (slot) {
				vec4 v = slot[i];
				printf("   * %s : %f x %f x %f x %f\n", particles_slots4_names[(ParticlesSlots4)slotid].c_str(), v.x, v.y, v.z, v.w);
			}
			slotid++;
		}
	}
}

/********************************************************************
 ** System
 ********************************************************************/

System::System(uint32_t max, RendererBlend blend) {
	list.max = max;
	if (GLEW_VERSION_3_3) {
		renderer.reset(new RendererGL3());
		printf("[ParticlesCompose] System using RendererGL3\n");
	} else {
		renderer.reset(new RendererGL2());
		printf("[ParticlesCompose] System using RendererGL2\n");
	}
	renderer->setBlend(blend);
}

void System::addEmitter(Emitter *emit) {
	emitters.emplace_back(emit);
}

void System::addUpdater(Updater *updater) {
	updaters.emplace_back(updater);
	updater->useSlots(list);
}

void System::setShader(spShaderHolder &shader) {
	renderer->setShader(shader);
}
void System::setTexture(spTextureHolder &tex) {
	renderer->setTexture(tex);
}

void System::finish() {
	// Make sure the generators that need to go last, do go last
	for (auto &e : emitters) {
		std::stable_sort(e->generators.begin(), e->generators.end(), [](const uGenerator &a, const uGenerator &b) -> bool { 
			return a->weight() < b->weight(); 
		});
	}

	list.initSlot4(POS);
	list.initSlot4(TEXTURE);
	list.initSlot4(COLOR);
	shift(0, 0, true);
	renderer->setup(list);
}

void System::shift(float x, float y, bool absolute) {
	for (auto &s : emitters) s->shift(x, y, absolute);
}

void System::update(float nb_keyframes) {
	float dt = nb_keyframes / 30.0f;
	for (auto e = emitters.begin(); e != emitters.end(); ) {
		(*e)->emit(list, dt);
		if (!(*e)->isActive()) e = emitters.erase(e);
		else e++;
	}
	for (auto &up : updaters) up->update(list, dt);
}

void System::print() {
	list.print();
}

void System::draw(mat4 &model) {
	renderer->update(list);
	renderer->draw(list, model);
}

/********************************************************************
 ** Ensemble
 ********************************************************************/
unordered_map<string, spTextureHolder> Ensemble::stored_textures;
unordered_map<string, spNoiseHolder> Ensemble::stored_noises;
unordered_map<string, spShaderHolder> Ensemble::stored_shaders;

spTextureHolder Ensemble::getTexture(const char *tex_str) {
	auto it = stored_textures.find(tex_str);
	if (it != stored_textures.end()) {
		printf("Reusing texture %s : %d\n", tex_str, it->second->tex->tex);
		return it->second;
	}

	texture_type *tex = new texture_type;
	loader_png(tex_str, tex, false, false, true);
	spTextureHolder th = make_shared<TextureHolder>(tex);
	stored_textures.insert({tex_str, th});
	return th;
}

spNoiseHolder Ensemble::getNoise(const char *noise_str) {
	auto it = stored_noises.find(noise_str);
	if (it != stored_noises.end()) {
		printf("Reusing noise %s\n", noise_str);
		return it->second;
	}

	noise_data *noise = new noise_data();
	loader_noise(noise_str, noise);
	spNoiseHolder nh = make_shared<NoiseHolder>(noise);
	stored_noises.insert({noise_str, nh});
	return nh;
}

spShaderHolder Ensemble::getShader(lua_State *L, const char *shader_str) {
	auto it = stored_shaders.find(shader_str);
	if (it != stored_shaders.end()) {
		printf("Reusing shader %s : %d\n", shader_str, it->second->shader->shader);
		return it->second;
	}

	int ref = LUA_NOREF;
	shader_type *shader = NULL;
	spShaderHolder sh;

	// Get Shader.new
	lua_getglobal(L, "engine");
	lua_pushliteral(L, "Shader");
	lua_gettable(L, -2);
	lua_pushliteral(L, "new");
	lua_gettable(L, -2);
	
	// Pass parameters
	lua_pushstring(L, shader_str);
	lua_pushnil(L);
	lua_pushboolean(L, true);
	if (GLEW_VERSION_3_3) lua_pushstring(L, "gl3");
	else lua_pushstring(L, "gl2");

	if (!lua_pcall(L, 4, 1, 0)) {
		// Get shader.shad
		lua_pushliteral(L, "shad");
		lua_gettable(L, -2);
		if (lua_isuserdata(L, -1)) shader = (shader_type*)lua_touserdata(L, -1);
		lua_pop(L, 1);

		if (shader) {
			lua_pushvalue(L, -1);
			ref = luaL_ref(L, LUA_REGISTRYINDEX);
			sh = make_shared<ShaderHolder>(shader, ref);
		}
	} else {
		printf("PartcilesComposer shader get error: %s\n", lua_tostring(L, -1));
	}
	lua_pop(L, 1 + 1); // Engine table & result

	stored_shaders.insert({shader_str, sh});
	return sh;
}

void Ensemble::gcTextures() {
	stored_textures.clear();
	stored_shaders.clear();
}

uint32_t Ensemble::countAlive() {
	uint32_t nb = 0;
	for (auto &s : systems) nb += s->list.count;
	return nb;	
}

void Ensemble::add(System *system) {
	systems.emplace_back(system);
}
void Ensemble::shift(float x, float y, bool absolute) {
	for (auto &s : systems) s->shift(x / zoom, y / zoom, absolute);
}
void Ensemble::update(float nb_keyframes) {
	nb_keyframes *= speed;
	dead = true;
	for (auto &s : systems) {
		s->update(nb_keyframes);
		if (!s->isDead()) dead = false;
	}
}
void Ensemble::draw(mat4 model) {
	model = glm::scale(model, glm::vec3(zoom, zoom, zoom));
	for (auto &s : systems) s->draw(model);
}
void Ensemble::draw(float x, float y) {
	mat4 model = mat4();
	model = glm::translate(model, glm::vec3(x, y, 0));
	draw(model);
}

}


