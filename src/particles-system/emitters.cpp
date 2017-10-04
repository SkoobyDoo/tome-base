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

void Emitter::triggered(TriggerableKind kind) {
	switch (kind) {
		case TriggerableKind::DESTROY:
			active = false;
			triggerEvent(EventKind::STOP);
			break;
		case TriggerableKind::WAKEUP:
			dormant = false;
			break;
		case TriggerableKind::FORCE:
			next_tick_force_generate++;
			break;
	}
}

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
	// DGDGDGDG : make a particles density setting here as a divider (use ceil ! )
	uint32_t start = p.count;
	uint32_t end = std::min(start + nb, p.max);
	if (start >= end) return;
	for (auto &gen : generators) {
		if (gen->use_limiter) {
			end = gen->generateLimit(p, start, end);
			if (end == start) break;
		}
		else gen->generate(p, start, end);
	}
	p.count = end;
	triggerEvent(EventKind::EMIT);
	// if (p.getSlots2(LINKS)) p.dumpLinks();
}

void LinearEmitter::emit(ParticlesData &p, float dt) {
	// We are not dead, but very sleepy
	if (dormant) return;

	// We are not at start yet
	if (startat > 0) { startat -= dt; return; }

	// A trigger forced use to fire
	if (next_tick_force_generate) { for (uint16_t i = 0; i < next_tick_force_generate; i++) generate(p, nb); next_tick_force_generate = 0; return; }

	// No time passed
	if (!dt) return;

	// Are we done yet ?
	if (duration > -1) {
		duration -= dt;
		if (duration < 0) {
			active = false;
			triggerEvent(EventKind::STOP);
		}
	}

	// Are we fully triggers controlled?
	if (!rate) return;

	if (first_tick) { first_tick = false; triggerEvent(EventKind::START); }

	// Accumulate time and if needed call our generators
	accumulator += dt;
	while (accumulator >= rate) {
		accumulator -= rate;
		generate(p, nb);
	}
}

void BurstEmitter::emit(ParticlesData &p, float dt) {
	// We are not dead, but very sleepy
	if (dormant) return;

	// We are not at start yet
	if (startat > 0) { startat -= dt; return; }

	// A trigger forced use to fire
	if (next_tick_force_generate) { bursting = burst; }

	// No time passed
	if (!dt) return;

	// Are we done yet ?
	if (duration > -1) {
		duration -= dt;
		if (duration < 0) {
			active = false;
			triggerEvent(EventKind::STOP);
		}
	}

	// Are we fully triggers controlled?
	if (!rate && !bursting) return;

	if (first_tick) { first_tick = false; triggerEvent(EventKind::START); }

	// Accumulate time and if needed call our generators
	accumulator += dt;
	if (accumulator >= rate) {
		accumulator -= rate;
		bursting = burst;
	}

	if (bursting > 0) {
		bursting -= dt;
		generate(p, ceil(nb * dt / burst));
	}
}


void BuildupEmitter::emit(ParticlesData &p, float dt) {
	// We are not dead, but very sleepy
	if (dormant) return;

	// We are not at start yet
	if (startat > 0) { startat -= dt; return; }

	// A trigger forced use to fire
	if (next_tick_force_generate) { for (uint16_t i = 0; i < next_tick_force_generate; i++) generate(p, nb); next_tick_force_generate = 0; return; }

	// No time passed
	if (!dt) return;

	// Are we done yet ?
	if (duration > -1) {
		duration -= dt;
		if (duration < 0) {
			active = false;
			triggerEvent(EventKind::STOP);
		}
	}

	rate += rate_sec * dt;
	nb += nb_sec * dt;
	if (rate_sec && rate < 0.01) rate = 0.0001;

	// Are we fully triggers controlled?
	if (rate <= 0) return;

	if (first_tick) { first_tick = false; triggerEvent(EventKind::START); }

	// Accumulate time and if needed call our generators
	accumulator += dt;
	while (accumulator >= rate) {
		accumulator -= rate;
		generate(p, nb);
	}
}

}
