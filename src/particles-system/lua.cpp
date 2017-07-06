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

extern "C" {
#include "auxiliar.h"
}
#include "core_loader.hpp"
using namespace particles;

static shader_type *lua_get_shader(lua_State *L, int idx) {
	if (lua_istable(L, idx)) {
		lua_pushliteral(L, "shad");
		lua_gettable(L, idx);
		shader_type *s = (shader_type*)lua_touserdata(L, -1);
		lua_pop(L, 1);
		return s;
	} else {
		return (shader_type*)lua_touserdata(L, idx);
	}
}

static int p_default_shader(lua_State *L)
{
	if (lua_isnil(L, 1)) {
		default_particlescompose_shader = NULL;
	} else {
		default_particlescompose_shader = lua_get_shader(L, 1);
	}
	return 0;
}

static int p_gc_textures(lua_State *L)
{
	Ensemble::gcTextures();
	return 0;
}

static int p_free(lua_State *L)
{
	Ensemble **ee = (Ensemble**)auxiliar_checkclass(L, "particles{compose}", 1);
	delete *ee;
	lua_pushnumber(L, 1);
	return 1;
}

static int p_shift(lua_State *L)
{
	Ensemble **ee = (Ensemble**)auxiliar_checkclass(L, "particles{compose}", 1);
	(*ee)->shift(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_toboolean(L, 4));
	return 0;
}

static int p_toscreen(lua_State *L)
{
	Ensemble **ee = (Ensemble**)auxiliar_checkclass(L, "particles{compose}", 1);
	(*ee)->update(lua_tonumber(L, 4));
	(*ee)->draw(lua_tonumber(L, 2), lua_tonumber(L, 3));
	return 0;
}

static inline float lua_float(lua_State *L, int table_idx, uint8_t field, float def) {
	float ret = def;
	lua_pushnumber(L, field);
	lua_rawget(L, table_idx < 0 ? (table_idx-1) : table_idx);
	if (lua_isnumber(L, -1)) ret = lua_tonumber(L, -1);
	lua_pop(L, 1);
	return ret;
}

static inline float lua_float(lua_State *L, int table_idx, const char *field, float def) {
	float ret = def;
	lua_pushstring(L, field);
	lua_rawget(L, table_idx < 0 ? (table_idx-1) : table_idx);
	if (lua_isnumber(L, -1)) ret = lua_tonumber(L, -1);
	lua_pop(L, 1);
	return ret;
}

static inline const char* lua_string(lua_State *L, int table_idx, const char *field, const char* def) {
	const char* ret = def;
	lua_pushstring(L, field);
	lua_rawget(L, table_idx < 0 ? (table_idx-1) : table_idx);
	if (lua_isstring(L, -1)) ret = lua_tostring(L, -1);
	lua_pop(L, 1);
	return ret;
}

static inline texture_type* lua_texture(lua_State *L, int table_idx, const char *field) {
	texture_type *ret = NULL;
	lua_pushstring(L, field);
	lua_rawget(L, table_idx < 0 ? (table_idx-1) : table_idx);
	if (lua_isuserdata(L, -1)) ret = (texture_type*)auxiliar_checkclass(L, "gl{texture}", -1);
	lua_pop(L, 1);
	return ret;
}

static inline shader_type* lua_shader(lua_State *L, int table_idx, const char *field) {
	shader_type *ret = NULL;
	lua_pushstring(L, field);
	lua_rawget(L, table_idx < 0 ? (table_idx-1) : table_idx);
	if (lua_isuserdata(L, -1) || lua_istable(L, -1)) ret = lua_get_shader(L, -1);
	lua_pop(L, 1);
	return ret;
}

static inline vec2 lua_vec2(lua_State *L, int table_idx, const char *field, vec2 def) {
	vec2 ret = def;
	lua_pushstring(L, field);
	lua_rawget(L, table_idx < 0 ? (table_idx-1) : table_idx);
	if (lua_istable(L, -1)) {
		lua_rawgeti(L, -1, 1);
		lua_rawgeti(L, -2, 2);
		ret.x = lua_tonumber(L, -2);
		ret.y = lua_tonumber(L, -1);
		lua_pop(L, 2);
	}
	lua_pop(L, 1);
	return ret;
}

static inline vec4 lua_vec4(lua_State *L, int table_idx, const char *field, vec4 def) {
	vec4 ret = def;
	lua_pushstring(L, field);
	lua_rawget(L, table_idx < 0 ? (table_idx-1) : table_idx);
	if (lua_istable(L, -1)) {
		lua_rawgeti(L, -1, 1);
		lua_rawgeti(L, -2, 2);
		lua_rawgeti(L, -3, 3);
		lua_rawgeti(L, -4, 4);
		ret.r = lua_tonumber(L, -4);
		ret.g = lua_tonumber(L, -3);
		ret.b = lua_tonumber(L, -2);
		ret.a = lua_tonumber(L, -1);
		lua_pop(L, 4);
	}
	lua_pop(L, 1);
	return ret;
}

static int p_new(lua_State *L) {
	Ensemble *e = new Ensemble();
	int nb_systems = lua_objlen(L, 1);
	for (int i = 1; i <= nb_systems; i++) {		
		lua_rawgeti(L, 1, i);
		System *sys = new System(lua_float(L, -1, "max_particles", 10), (RendererBlend)((uint8_t)lua_float(L, -1, "blend", static_cast<uint8_t>(RendererBlend::DefaultBlend))));

		const char *tex_str = lua_string(L, -1, "texture", NULL);
		if (tex_str){
			spTextureHolder th = Ensemble::getTexture(tex_str);
			sys->setTexture(th);
		}

		shader_type *shader = lua_shader(L, -1, "shader");
		if (shader) sys->setShader(shader);

		/** Emitters **/
		lua_pushliteral(L, "emitters");
		lua_rawget(L, -2);
		int nb_emitters = lua_objlen(L, -1);
		for (int ei = 1; ei <= nb_emitters; ei++) {
			lua_rawgeti(L, -1, ei);
			EmittersList e_id = (EmittersList)((uint8_t)lua_float(L, -1, 1, 0));
			Emitter *em;
			switch (e_id) {
				case EmittersList::LinearEmitter:
					em = new LinearEmitter(lua_float(L, -1, "rate", 0.1), lua_float(L, -1, "nb", 10));
					break;
				default:
					lua_pushliteral(L, "Unknown particles emitter"); lua_error(L);
					break;
			}


			/** Generators **/
			lua_pushnumber(L, 2);
			lua_rawget(L, -2);
			int nb_generators = lua_objlen(L, -1);
			for (int gi = 1; gi <= nb_generators; gi++) {
				lua_rawgeti(L, -1, gi);
				GeneratorsList g_id = (GeneratorsList)((uint8_t)lua_float(L, -1, 1, 0));
				Generator *g;
				switch (g_id) {
					case GeneratorsList::LifeGenerator:
						g = new LifeGenerator(lua_float(L, -1, "min", 0.3), lua_float(L, -1, "max", 3));
						break;
					case GeneratorsList::BasicTextureGenerator:
						g = new BasicTextureGenerator();
						break;
					case GeneratorsList::DiskPosGenerator:
						g = new DiskPosGenerator(lua_float(L, -1, "radius", 100));
						g->basePos(lua_float(L, -1, "sx", 0), lua_float(L, -1, "sy", 0));
						break;
					case GeneratorsList::CirclePosGenerator:
						g = new CirclePosGenerator(lua_float(L, -1, "radius", 100), lua_float(L, -1, "width", 10));
						g->basePos(lua_float(L, -1, "sx", 0), lua_float(L, -1, "sy", 0));
						break;
					case GeneratorsList::TrianglePosGenerator:
						g = new TrianglePosGenerator(lua_vec2(L, -1, "p1", vec2(0, 0)), lua_vec2(L, -1, "p2", vec2(0, 0)), lua_vec2(L, -1, "p3", vec2(0, 0)));
						g->basePos(lua_float(L, -1, "sx", 0), lua_float(L, -1, "sy", 0));
						break;
					case GeneratorsList::DiskVelGenerator:
						g = new DiskVelGenerator(lua_float(L, -1, "min_vel", 5), lua_float(L, -1, "max_vel", 10));
						break;
					case GeneratorsList::BasicSizeGenerator:
						g = new BasicSizeGenerator(lua_float(L, -1, "min_size", 10), lua_float(L, -1, "max_size", 30));
						break;
					case GeneratorsList::BasicRotationGenerator:
						g = new BasicRotationGenerator(lua_float(L, -1, "min_rot", 0), lua_float(L, -1, "max_rot", M_PI*2));
						break;
					case GeneratorsList::StartStopColorGenerator:
						g = new StartStopColorGenerator(lua_vec4(L, -1, "min_color_start", vec4(1, 0, 0, 1)), lua_vec4(L, -1, "max_color_start", vec4(0, 1, 0, 1)), lua_vec4(L, -1, "min_color_stop", vec4(1, 0, 0, 0)), lua_vec4(L, -1, "max_color_stop", vec4(0, 1, 0, 0)));
						break;
					case GeneratorsList::FixedColorGenerator:
						g = new FixedColorGenerator(lua_vec4(L, -1, "color_start", vec4(1, 0, 0, 1)), lua_vec4(L, -1, "color_stop", vec4(0, 1, 0, 1)));
						break;
					default:
						lua_pushliteral(L, "Unknown particles Generator"); lua_error(L);
						break;
				}
				em->addGenerator(sys, g);
				lua_pop(L, 1);
			}
			lua_pop(L, 1);


			sys->addEmitter(em);
			lua_pop(L, 1);
		}
		lua_pop(L, 1);


		/** Updaters **/
		lua_pushliteral(L, "updaters");
		lua_rawget(L, -2);
		int nb_updaters = lua_objlen(L, -1);
		for (int ui = 1; ui <= nb_updaters; ui++) {
			lua_rawgeti(L, -1, ui);
			UpdatersList u_id = (UpdatersList)((uint8_t)lua_float(L, -1, 1, 0));
			Updater *u;
			switch (u_id) {
				case UpdatersList::LinearColorUpdater:
					u = new LinearColorUpdater();
					break;
				case UpdatersList::BasicTimeUpdater:
					u = new BasicTimeUpdater();
					break;
				case UpdatersList::AnimatedTextureUpdater:
					u = new AnimatedTextureUpdater(lua_float(L, -1, "splitx", 1), lua_float(L, -1, "splity", 1), lua_float(L, -1, "firstframe", 0), lua_float(L, -1, "lastframe", 0), lua_float(L, -1, "repeat_over_life", 1));
					break;
				case UpdatersList::EulerPosUpdater:
					u = new EulerPosUpdater(lua_vec2(L, -1, "global_vel", vec2(0, 0)), lua_vec2(L, -1, "global_acc", vec2(0, 0)));
					break;
				default:
					lua_pushliteral(L, "Unknown particles updater"); lua_error(L);
					break;
			}
			sys->addUpdater(u);
			lua_pop(L, 1);
		}
		lua_pop(L, 1);

		sys->finish();
		e->add(sys);
		lua_pop(L, 1);
	}

	Ensemble **ee = (Ensemble**)lua_newuserdata(L, sizeof(Ensemble*));
	auxiliar_setclass(L, "particles{compose}", -1);
	*ee = e;
	return 1;
}

static int p_test(lua_State *L) {
	System *sys = new System(10000, RendererBlend::AdditiveBlend);
	LinearEmitter *emit = new LinearEmitter(0.3, 3);
	emit->addGenerator(sys, new LifeGenerator(1, 5));
	emit->addGenerator(sys, new CirclePosGenerator(100, 10));
	emit->addGenerator(sys, new DiskVelGenerator(12, 15));
	emit->addGenerator(sys, new BasicSizeGenerator(2, 9));
	emit->addGenerator(sys, new BasicRotationGenerator(0, M_PI*2));
	emit->addGenerator(sys, new FixedColorGenerator(vec4(1, 1, 0, 1), vec4(0, 0, 0, 1)));
	sys->addEmitter(emit);
	sys->addUpdater(new BasicTimeUpdater());
	sys->addUpdater(new LinearColorUpdater());
	sys->addUpdater(new EulerPosUpdater(vec2(0, 0), vec2(0, 0)));

	// texture_type *tex = new texture_type;
	// loader_png("/data/gfx/particle.png", tex, false, false, true);
	// sys->setTexture(tex);

	sys->finish();
	Ensemble *e = new Ensemble();
	e->add(sys);

	Ensemble **ee = (Ensemble**)lua_newuserdata(L, sizeof(Ensemble*));
	auxiliar_setclass(L, "particles{compose}", -1);
	*ee = e;
	return 1;
}

static const struct luaL_Reg pcompose[] =
{
	{"__gc", p_free},
	{"shift", p_shift},
	{"toScreen", p_toscreen},
	{NULL, NULL},
};

static const struct luaL_Reg plib[] =
{
	{"gcTextures", p_gc_textures},
	{"defaultShader", p_default_shader},
	{"new", p_new},
	{"test", p_test},
	{NULL, NULL},
};

extern "C" int luaopen_particles_system(lua_State *L) {
	auxiliar_newclass(L, "particles{compose}", pcompose);
	luaL_openlib(L, "core.particlescompose", plib, 0);

	lua_pushliteral(L, "DefaultBlend"); lua_pushnumber(L, static_cast<uint8_t>(RendererBlend::DefaultBlend)); lua_rawset(L, -3);
	lua_pushliteral(L, "AdditiveBlend"); lua_pushnumber(L, static_cast<uint8_t>(RendererBlend::AdditiveBlend)); lua_rawset(L, -3);
	lua_pushliteral(L, "MixedBlend"); lua_pushnumber(L, static_cast<uint8_t>(RendererBlend::MixedBlend)); lua_rawset(L, -3);
	lua_pushliteral(L, "ShinyBlend"); lua_pushnumber(L, static_cast<uint8_t>(RendererBlend::ShinyBlend)); lua_rawset(L, -3);

	lua_pushliteral(L, "LinearEmitter"); lua_pushnumber(L, static_cast<uint8_t>(EmittersList::LinearEmitter)); lua_rawset(L, -3);

	lua_pushliteral(L, "LinearColorUpdater"); lua_pushnumber(L, static_cast<uint8_t>(UpdatersList::LinearColorUpdater)); lua_rawset(L, -3);
	lua_pushliteral(L, "BasicTimeUpdater"); lua_pushnumber(L, static_cast<uint8_t>(UpdatersList::BasicTimeUpdater)); lua_rawset(L, -3);
	lua_pushliteral(L, "AnimatedTextureUpdater"); lua_pushnumber(L, static_cast<uint8_t>(UpdatersList::AnimatedTextureUpdater)); lua_rawset(L, -3);
	lua_pushliteral(L, "EulerPosUpdater"); lua_pushnumber(L, static_cast<uint8_t>(UpdatersList::EulerPosUpdater)); lua_rawset(L, -3);

	lua_pushliteral(L, "LifeGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::LifeGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "BasicTextureGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::BasicTextureGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "DiskPosGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::DiskPosGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "CirclePosGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::CirclePosGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "TrianglePosGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::TrianglePosGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "DiskVelGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::DiskVelGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "BasicSizeGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::BasicSizeGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "BasicRotationGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::BasicRotationGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "StartStopColorGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::StartStopColorGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "FixedColorGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::FixedColorGenerator)); lua_rawset(L, -3);

	lua_settop(L, 0);
	return 1;
}

