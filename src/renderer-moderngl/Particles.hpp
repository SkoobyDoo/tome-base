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

#ifndef PARTICLES_GL_HPP
#define PARTICLES_GL_HPP

#include "renderer-moderngl/Renderer.hpp"
#include "../particles.hpp"

// This one is a little strange, it is not the master of particles_type it's a slave, as such it will never try to free it or anything, it is created by it
// This is, in essence, a DO warper around particle code
class DORParticles : public SubRenderer{
private:
	particles_type *ps = NULL;
	int ps_lua_ref = LUA_NOREF;

	virtual void cloneInto(DisplayObject *into);

public:
	DORParticles() { setRendererName("particles"); };
	virtual ~DORParticles() { };
	DO_STANDARD_CLONE_METHOD(DORParticles);
	virtual const char* getKind() { return "DORParticles"; };

	void setParticles(particles_type *ps, int ref) {
		if (ps_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, ps_lua_ref);
		ps_lua_ref = ref;
		this->ps = ps;
	};

	virtual void toScreen(mat4 cur_model, vec4 color);
};

#endif
