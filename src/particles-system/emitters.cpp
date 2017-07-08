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
#include "SFMT.h"
}
#include "particles-system/system.hpp"

namespace particles {

void Emitter::addGenerator(System *sys, Generator *gen) {
	generators.emplace_back(gen);
	gen->useSlots(sys->list);
}

void Emitter::shift(float x, float y, bool absolute) {
	for (auto &gen : generators) {
		gen->shift(x, y, absolute);
	}
}

void Emitter::generate(ParticlesData &p, uint32_t nb) {
	uint32_t start = p.count;
	uint32_t end = std::min(start + nb, p.max);
	for (auto &gen : generators) {
		if (gen->use_limiter) end = gen->generateLimit(p, start, end);
		else gen->generate(p, start, end);
	}
	p.count = end;
}

void LinearEmitter::emit(ParticlesData &p, float dt) {
	if (!dt) return;
	if (startat > 0) {
		startat -= dt;
		return;
	}

	if (duration > -1) {
		duration -= dt;
		if (duration < 0) active = false;
	}
	accumulator += dt;
	while (accumulator >= rate) {
		accumulator -= rate;
		generate(p, nb);
	}
}

}
