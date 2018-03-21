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

#include "renderer-moderngl/Particles.hpp"

DORParticles::~DORParticles() {
	// printf("==================== DORParticles DYING %s linked to parent %lx\n", ps ? ps->name_def : (e ? "Ensemble" : "--"), parent);
	refcleaner(&ps_lua_ref);
	if (e && owned) {
		delete e;
	}
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
