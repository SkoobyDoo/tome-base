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
	renderer.setBlend(blend);
}

void System::addEmitter(Emitter *emit) {
	emitters.emplace_back(emit);
}

void System::addUpdater(Updater *updater) {
	updaters.emplace_back(updater);
	updater->useSlots(list);
}

void System::setShader(shader_type *shader) {
	renderer.setShader(shader);
}
void System::setTexture(spTextureHolder &tex) {
	renderer.setTexture(tex);
}

void System::finish() {
	list.initSlot4(POS);
	list.initSlot4(TEXTURE);
	list.initSlot4(COLOR);
	shift(0, 0, true);
	renderer.setup(list);
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

void System::draw(float x, float y) {
	renderer.update(list);
	renderer.draw(list, x, y);
}

/********************************************************************
 ** Ensemble
 ********************************************************************/
unordered_map<string, spTextureHolder> Ensemble::stored_textures;

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

void Ensemble::gcTextures() {
	stored_textures.clear();
}

void Ensemble::add(System *system) {
	systems.emplace_back(system);
}
void Ensemble::shift(float x, float y, bool absolute) {
	for (auto &s : systems) s->shift(x, y, absolute);
}
void Ensemble::update(float nb_keyframes) {
	dead = true;
	for (auto &s : systems) {
		s->update(nb_keyframes);
		if (!s->isDead()) dead = false;
	}
}
void Ensemble::draw(float x, float y) {
	for (auto &s : systems) s->draw(x, y);
}

}


