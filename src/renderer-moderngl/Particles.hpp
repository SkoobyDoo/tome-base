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

#ifndef PARTICLES_GL_HPP
#define PARTICLES_GL_HPP

#include "renderer-moderngl/Renderer.hpp"
#include "../particles.hpp"
#include "../particles-system/system.hpp"

// This one is a little strange, it is not the master of particles_type it's a slave, as such it will never try to free it or anything, it is created by it
// This is, in essence, a DO warper around particle code
class DORParticles : public SubRenderer {
private:
	particles::Ensemble *e = NULL;
	particles_type *ps = NULL;
	int ps_lua_ref = LUA_NOREF;
	bool owned = false;

	virtual void cloneInto(DisplayObject *into);

public:
	DORParticles() { setRendererName("particles"); };
	virtual ~DORParticles();
	DO_STANDARD_CLONE_METHOD(DORParticles);
	virtual const char* getKind() { return "DORParticles"; };

	void setParticles(particles_type *ps, int ref) {
		refcleaner(&ps_lua_ref);
		ps_lua_ref = ref;
		this->ps = ps;
	};

	void setParticles(particles::Ensemble *e, int ref) {
		refcleaner(&ps_lua_ref);
		ps_lua_ref = ref;
		this->e = e;
	};

	void setParticlesOwn(particles::Ensemble *e) {
		refcleaner(&ps_lua_ref);
		ps_lua_ref = LUA_NOREF;
		this->e = e;
		owned = true;
	};

	inline void shift(float sx, float sy, bool absolute) { if (e) e->shift(sx, sy, absolute); else particles_shift(ps, sx, sy, absolute); }
	inline bool isDead() { if (e) return e->isDead(); else if (ps) return !ps->alive; return true; }
	inline uint32_t countAlive() { if (e) return e->countAlive(); else if (ps) return ps->nb; return true; }
	inline void setZoom(float zoom) { if (e) e->setZoom(zoom); }
	inline void setSpeed(float speed) { if (e) e->setSpeed(speed); }
	inline void fireTrigger(string &name) { if (e) e->fireTrigger(name); }
	inline void setEventsCallback(int lua_ref) { if (e) e->setEventsCallback(lua_ref); }
	inline void updateParameters(lua_State *L, int table_id) { if (e) e->updateParameters(L, table_id); }

	virtual void toScreen(mat4 cur_model, vec4 color);
};

#endif
