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
#include "display_sdl.h"
#include "physfs.h"
}
#include "particles-system/system.hpp"
#include "core_loader.hpp"
#include <condition_variable>
#ifdef MINGW_WIN_THREAD_COMPAT
#include "mingw.condition_variable.h"
#endif

namespace particles {

int PC_lua_ref = LUA_NOREF;
int math_mt_lua_ref = LUA_NOREF;

/********************************************************************
 ** ThreadedRunner
 ********************************************************************/
class ThreadedRunner{
public:
	mutex mux;
	thread th;
	condition_variable cv;
	float keyframes_accumulator = 0;

	ThreadedRunner();
	void onKeyframe(float nb_keyframes);
};

static ThreadedRunner th_runner_singleton;
static inline bool check_frames() { return th_runner_singleton.keyframes_accumulator > 0; }

static void threaded_runner_thread() {
	while (true) {
		unique_lock<mutex> lock(th_runner_singleton.mux);
		th_runner_singleton.cv.wait(lock, check_frames);
		float kf = th_runner_singleton.keyframes_accumulator;
		th_runner_singleton.keyframes_accumulator = 0;
		
		for (auto e : Ensemble::all_ensembles) {
			e->update(kf);
		}
		lock.unlock();
	}
}

ThreadedRunner::ThreadedRunner() : th(threaded_runner_thread) {
	printf("[ParticlesCompose] started updater thread\n");
}

void ThreadedRunner::onKeyframe(float nb_keyframes) {
	lock_guard<mutex> guard(mux);
	keyframes_accumulator += nb_keyframes;
	cv.notify_all();
}

extern "C" void threaded_runner_keyframe(float nb_keyframes) {
	th_runner_singleton.onKeyframe(nb_keyframes);
}

/********************************************************************
 ** ParticlesData
 ********************************************************************/

// unordered_map<ParticlesSlots2, string> particles_slots2_names({
// 	{VEL, "vel"},
// 	{ACC, "acc"},
// 	{SIZE, "size"},
// 	{ORIGIN_POS, "origin pos"},
// });
// unordered_map<ParticlesSlots4, string> particles_slots4_names({
// 	{POS, "pos"},
// 	{TEXTURE, "texture"},
// 	{LIFE, "life"},
// 	{COLOR, "color"},
// 	{COLOR_START, "color_start"},
// 	{COLOR_STOP, "color_stop"},
// });


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
	// printf("ParticlesData:\n");
	// for (uint32_t i = 0; i < max; i++) {
	// 	printf(" - p%d\n", i);
	// 	uint8_t slotid = 0; for (auto &slot : slots2) {
	// 		if (slot) {
	// 			vec2 v = slot[i];
	// 			printf("   * %s : %f x %f\n", particles_slots2_names[(ParticlesSlots2)slotid].c_str(), v.x, v.y);
	// 		}
	// 		slotid++;
	// 	}
	// 	slotid = 0; for (auto &slot : slots4) {
	// 		if (slot) {
	// 			vec4 v = slot[i];
	// 			printf("   * %s : %f x %f x %f x %f\n", particles_slots4_names[(ParticlesSlots4)slotid].c_str(), v.x, v.y, v.z, v.w);
	// 		}
	// 		slotid++;
	// 	}
	// }
}

/********************************************************************
 ** System
 ********************************************************************/

System::System(uint32_t max, RendererBlend blend, RendererType type) {
	if (max > 1000000) max = 1000000;
	list.max = max;
	renderer_type = type;

	if (type == RendererType::Line) {
		renderer.reset(new RendererLine());
	} else {
		if (GLEW_VERSION_3_3) {
			renderer.reset(new RendererGL3());
			// printf("[ParticlesCompose] System using RendererGL3\n");
		} else {
			renderer.reset(new RendererGL2());
			// printf("[ParticlesCompose] System using RendererGL2\n");
		}
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
	lock_guard<mutex> guard(mux);

	for (auto &e : emitters) e->shift(x, y, absolute);
}

void System::displace(float x, float y) {
	lock_guard<mutex> lguard(list.mux);

	vec2 disp(x, y);

	vec2* origin = list.getSlot2(ORIGIN_POS);
	if (origin) {
		for (uint32_t i = 0; i < list.count; i++) {
			origin[i] = origin[i] + disp;
		}
	}

	vec4* pos = list.getSlot4(POS);
	if (pos) {
		for (uint32_t i = 0; i < list.count; i++) {
			pos[i].x = pos[i].x + x;
			pos[i].y = pos[i].y + y;
		}
	}
}

void System::fireTrigger(string &name) {
	lock_guard<mutex> guard(mux);

	for (auto &e : emitters) e->fireTrigger(name);
}

void System::update(float nb_keyframes) {
	lock_guard<mutex> lguard(list.mux);
	lock_guard<mutex> guard(mux);

	uint8_t emitters_active_not_dormant = 0;
	float dt = nb_keyframes / 30.0f;
	for (auto e = emitters.begin(); e != emitters.end(); ) {
		(*e)->emit(list, dt);
		if ((*e)->isActiveNotDormant()) emitters_active_not_dormant++;
		if (!(*e)->isActive()) {
			dead_emitters.push_back(std::move(*e));
			e = emitters.erase(e);
		}
		else e++;
	}
	for (auto &up : updaters) up->update(list, dt);

	dead = list.count == 0 && emitters_active_not_dormant == 0;
}

void System::print() {
	list.print();
}

void System::draw(mat4 &model) {
	if (hidden) return;
	renderer->update(list);
	renderer->draw(list, model);
}

/********************************************************************
 ** Ensemble
 ********************************************************************/
MT::MersenneTwist Ensemble::rng;
unordered_map<string, spTextureHolder> Ensemble::stored_textures;
unordered_map<string, spNoiseHolder> Ensemble::stored_noises;
unordered_map<string, spPointsListHolder> Ensemble::stored_points_lists;
unordered_map<string, spShaderHolder> Ensemble::stored_shaders;
unordered_map<string, spDefHolder> Ensemble::stored_defs;
unordered_set<Ensemble*> Ensemble::all_ensembles;

spTextureHolder Ensemble::getTexture(const char *tex_str) {
	auto it = stored_textures.find(tex_str);
	if (it != stored_textures.end()) {
		// printf("Reusing texture %s : %d\n", tex_str, it->second->tex->tex);
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
		// printf("Reusing noise %s\n", noise_str);
		return it->second;
	}

	noise_data *noise = new noise_data();
	loader_noise(noise_str, noise);
	spNoiseHolder nh = make_shared<NoiseHolder>(noise);
	stored_noises.insert({noise_str, nh});
	return nh;
}

spPointsListHolder Ensemble::getPointsList(const char *image_str) {
	auto it = stored_points_lists.find(image_str);
	if (it != stored_points_lists.end()) {
		printf("Reusing points list %s\n", image_str);
		return it->second;
	}

	points_list *list = new points_list();
	loader_points_list(image_str, list);
	spPointsListHolder nh = make_shared<PointsListHolder>(list);
	stored_points_lists.insert({image_str, nh});
	printf("Making points list %s\n", image_str);
	return nh;
}

spShaderHolder Ensemble::getShader(lua_State *L, const char *shader_str) {
	auto it = stored_shaders.find(shader_str);
	if (it != stored_shaders.end()) {
		// printf("Reusing shader %s : %d\n", shader_str, it->second->shader->shader);
		return it->second;
	}

	int ref = LUA_NOREF;
	shader_type *shader = NULL;
	spShaderHolder sh;

	// Get Shader.new
	int top = lua_gettop(L);
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
		printf("ParticlesComposer shader get error: %s\n", lua_tostring(L, -1));
	}
	lua_settop(L, top);

	stored_shaders.insert({shader_str, sh});
	return sh;
}

int Ensemble::getDefinition(lua_State *L, const char *def_str) {
	auto it = stored_defs.find(def_str);
	if (it != stored_defs.end()) {
		// printf("Reusing def %s : %d\n", def_str, it->second->ref);
		return it->second->ref;
	}

	string full_def(def_str);
	if (full_def[0] != '/') full_def.insert(0, "/data/gfx/particles/");

	if (!PHYSFS_exists(full_def.c_str())) {
		printf("[ParticlesCompose] file not found: %s\n", full_def.c_str());
		lua_newtable(L);
	} else {
		luaL_loadfile(L, full_def.c_str()); // Load file
		lua_newtable(L); // Make new env table
		lua_pushliteral(L, "PC"); // Push particle composer table into the env
		lua_rawgeti(L, LUA_REGISTRYINDEX, PC_lua_ref);
		lua_rawset(L, -3);
		lua_setfenv(L, -2); // Set the env

		// Get the data
		if (lua_pcall(L, 0, 1, 0)) {
			printf("[ParticlesComposer] file load error: %s\n", lua_tostring(L, -1));
			lua_pop(L, 1);
			lua_newtable(L);
		}
	}

	// Get a ref on it
	int ref = luaL_ref(L, LUA_REGISTRYINDEX);
	string def(def_str);
	spDefHolder dh = make_shared<DefHolder>(ref, def);

	stored_defs.insert({def_str, dh});
	return ref;
}

// void Ensemble::getExpression(lua_State *L, float *dst, const char *expr_str, int env_id) {
// 	auto it = stored_defs.find(expr_str);
// 	// printf("====tying to find %s (%d)\n", expr_str, it != stored_defs.end());
// 	// for (auto &it : stored_defs) printf("  - %d : %s\n", it.second->ref, it.first.c_str());
// 	if (it != stored_defs.end()) {
// 		printf("Reusing expr %s : %d\n", expr_str, it->second->ref);
// 		lua_rawgeti(L, LUA_REGISTRYINDEX, it->second->ref);
// 		lua_pushvalue(L, env_id);
// 		lua_setfenv(L, -2); // Set the env
// 		if (lua_pcall(L, 0, 1, 0)) printf("LUA EXPR ERROR: %s\n", lua_tostring(L, -1));
// 		*dst = lua_tonumber(L, -1);
// 		lua_pop(L, 1);
// 		parametrized_values.emplace_back(dst, it->second->ref);
// 		return;
// 	}

// 	string expr("return ");
// 	expr += expr_str;
// 	luaL_loadstring(L, expr.c_str()); // Load expression
// 	lua_pushvalue(L, env_id);
// 	lua_setfenv(L, -2); // Set the env

// 	// Get a ref on it
// 	lua_pushvalue(L, -1);
// 	int ref = luaL_ref(L, LUA_REGISTRYINDEX);
// 	spDefHolder dh = make_shared<DefHolder>(ref, expr);

// 	stored_defs.insert({expr_str, dh});

// 	// Call it
// 	if (lua_pcall(L, 0, 1, 0)) printf("LUA EXPR ERROR: %s\n", lua_tostring(L, -1));
// 	*dst = lua_tonumber(L, -1);
// 	lua_pop(L, 1);
// 	printf("Making new expr %s : %d\n", expr_str, ref);

// 	parametrized_values.emplace_back(dst, ref);
// }

void Ensemble::getExpression(lua_State *L, float *dst, const char *expr_str, int env_id) {
	string expr(expr_str);
	ExpressionID id = exprs.compile(expr);
	parametrized_values.emplace_back(dst, id);
	*dst = exprs.eval(id);
	// exprs.print();
	// printf("Compiled expression %s to id %d => %f\n", expr_str, id, *dst);
}

Ensemble::Ensemble() {
	printf("===Ensemble created, %lx\n", this);
	lock_guard<mutex> lock(th_runner_singleton.mux);
	all_ensembles.insert(this);
}

Ensemble::~Ensemble() {
	printf("===Ensemble destroyed, %lx\n", this);
	refcleaner(&event_cb_ref);
	refcleaner(&parameters_ref);
	lock_guard<mutex> lock(th_runner_singleton.mux);
	all_ensembles.erase(this);
}

void Ensemble::gcTextures() {
	stored_textures.clear();
	stored_noises.clear();
	stored_points_lists.clear();
	stored_shaders.clear();
	stored_defs.clear();
	default_particlescompose_shader.reset();
}

uint32_t Ensemble::countAlive() {
	uint32_t nb = 0;
	for (auto &s : systems) nb += s->list.count;
	return nb;	
}

void Ensemble::fireTrigger(string &name) {
	for (auto &s : systems) s->fireTrigger(name);
}

void Ensemble::add(System *system) {
	systems.emplace_back(system);
}
void Ensemble::shift(float x, float y, bool absolute) {
	for (auto &s : systems) s->shift(x / zoom, y / zoom, absolute);
}
void Ensemble::displace(float x, float y) {
	for (auto &s : systems) s->displace(x / zoom, y / zoom);
}
void Ensemble::update(float nb_keyframes) {
	nb_keyframes *= speed;
	for (auto &s : systems) {
		s->update(nb_keyframes);
	}
}

void Ensemble::setEventsCallback(int ref) {
	refcleaner(&event_cb_ref);
	event_cb_ref = ref;
}

void Ensemble::updateParameters(lua_State *L, int table_id) {
	if (!parametrized_values.size()) return;

	// Need to lock all, because we do not know which system owns the variable(s) being changed :/
	for (auto &s : systems) s->mux.lock();

	// Copy the new parameters
	if (lua_istable(L, table_id)) {
		lua_pushnil(L);
		while (lua_next(L, table_id) != 0) {
			exprs.set(lua_tostring(L, -2), lua_tonumber(L, -1));
			lua_pop(L, 1);
		}
	}

	for (auto &it : parametrized_values) {
		*get<0>(it) = exprs.eval(get<1>(it));
	}

	for (auto &s : systems) s->mux.unlock();
}

void Ensemble::draw(mat4 model) {
	dead = true;

	model = glm::scale(model, glm::vec3(zoom, zoom, zoom));
	for (auto &s : systems) {
		s->draw(model);
		if (!s->isDead()) dead = false;
	}
	if (event_cb_ref != LUA_NOREF && events_triggers.size()) {
		lua_rawgeti(L, LUA_REGISTRYINDEX, event_cb_ref);
		for (auto &it : events_triggers) {
			lua_pushvalue(L, -1);
			lua_pushstring(L, it.first.c_str());
			lua_pushnumber(L, it.second);
			if (lua_pcall(L, 2, 0, 0)) {
				printf("Ensemble::events callback error: %s\n", lua_tostring(L, -1));
				lua_pop(L, 1);
			}
		}
		events_triggers.clear();
	}
}
void Ensemble::draw(float x, float y) {
	mat4 model = mat4();
	model = glm::translate(model, glm::vec3(x, y, 0));
	draw(model);
}

}
