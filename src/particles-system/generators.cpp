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
#include <math.h>

namespace particles {

void LifeGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* life = p.getSlot4(LIFE);
	for (uint32_t i = start; i < end; i++) {
		life[i].x = life[i].y = genrand_real(min, max);
		life[i].z = (float)0.0;
		life[i].w = (float)1.0 / life[i].x;
	}
}

void BasicTextureGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
}

void DiskPosGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* pos = p.getSlot4(POS);
	for (uint32_t i = start; i < end; i++) {
		float a = genrand_real(0.0, M_PI * 2.0);
		float r = genrand_real(0, radius);
		pos[i].x = bx + cos(a) * r;
		pos[i].y = by + sin(a) * r;
	}
}

void CirclePosGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* pos = p.getSlot4(POS);
	for (uint32_t i = start; i < end; i++) {
		float a = genrand_real(0.0, M_PI * 2.0);
		float r = genrand_real(radius - width, radius + width);
		pos[i].x = bx + cos(a) * r;
		pos[i].y = by + sin(a) * r;
	}
}

void DiskVelGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec2* vel = p.getSlot2(VEL);
	for (uint32_t i = start; i < end; i++) {
		float a = genrand_real(0.0, M_PI * 2.0);
		float r = genrand_real(min_vel, max_vel);
		vel[i].x = cos(a) * r;
		vel[i].y = sin(a) * r;
	}
}

void BasicSizeGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* pos = p.getSlot4(POS);
	for (uint32_t i = start; i < end; i++) {
		pos[i].z = genrand_real(min_size, max_size);
	}
}

void BasicRotationGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* pos = p.getSlot4(POS);
	for (uint32_t i = start; i < end; i++) {
		pos[i].w = genrand_real(min_rot, max_rot);
	}
}

void StartStopColorGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* color = p.getSlot4(COLOR);
	vec4* cstart = p.getSlot4(COLOR_START);
	vec4* cstop = p.getSlot4(COLOR_STOP);
	for (uint32_t i = start; i < end; i++) {
		vec4 color_start = glm::mix(min_color_start, max_color_start, genrand_real(0, 1));
		vec4 color_stop = glm::mix(min_color_stop, max_color_stop, genrand_real(0, 1));
		color[i] = color_start;
		cstart[i] = color_start;
		cstop[i] = color_stop;
	}
}

void FixedColorGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* color = p.getSlot4(COLOR);
	vec4* cstart = p.getSlot4(COLOR_START);
	vec4* cstop = p.getSlot4(COLOR_STOP);
	for (uint32_t i = start; i < end; i++) {
		color[i] = color_start;
		cstart[i] = color_start;
		cstop[i] = color_stop;
	}}
}
