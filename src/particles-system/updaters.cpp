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

namespace particles {

void LinearColorUpdater::update(ParticlesData &p, float dt) {
	vec4* color = p.getSlot4(COLOR);
	vec4* color_start = p.getSlot4(COLOR_START);
	vec4* color_stop = p.getSlot4(COLOR_STOP);
	vec4* life = p.getSlot4(LIFE);
	for (uint32_t i = 0; i < p.count; i++) {
		color[i] = glm::mix(color_start[i], color_stop[i], life[i].z);
	}
}

void BasicTimeUpdater::update(ParticlesData &p, float dt) {
	uint32_t end = p.count;
	vec4* life = p.getSlot4(LIFE);

	for (uint32_t i = 0; i < end; i++) {
		life[i].x -= dt;
		// interpolation: from 0 (start of life) till 1 (end of life)
		life[i].z = (float)1.0 - (life[i].x * life[i].w); // .w is 1.0/max life time		

		if (life[i].x < (float)0.0) {
			p.kill(i);
			end = p.count < p.max ? p.count : p.max;
			// printf("p died, %d left\n", p.count);
		}
	}
}

void EulerPosUpdater::update(ParticlesData &p, float dt) {
	vec4* pos = p.getSlot4(POS);
	vec2* vel = p.getSlot2(VEL);
	vec2* acc = p.getSlot2(ACC);
	for (uint32_t i = 0; i < p.count; i++) {
		acc[i] += global_acc * dt;
		vel[i] += (acc[i] + global_vel) * dt;
		pos[i].x += vel[i].x * dt;
		pos[i].y += vel[i].y * dt;
	}
}

}
