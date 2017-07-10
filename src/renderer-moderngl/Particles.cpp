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

#include "renderer-moderngl/Particles.hpp"

DORParticles::~DORParticles() {
	if (ps_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, ps_lua_ref);
};

void DORParticles::cloneInto(DisplayObject *_into) {
	DisplayObject::cloneInto(_into);
	DORParticles *into = dynamic_cast<DORParticles*>(_into);
	into->ps = ps;
}

void DORParticles::toScreen(mat4 cur_model, vec4 color) {
	if (ps) {
		// If we are dead, our parent has no more uses for us
		if (!ps->alive) {
			removeFromParent();
			return;
		}
		particles_to_screen(ps, cur_model * model);
	} else if (e) {
		if (e->isDead()) {
			removeFromParent();
			return;
		}
		e->draw(cur_model * model);
	}
}

// MAKE THE PC MULTITHREAD BY HOOKING IN EXISTING THREAD AND REMOVE THAT
void DORParticles::onKeyframe(float nb_keyframes) {
	if (e) e->update(nb_keyframes);
}
