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

void Generator::shift(float x, float y, bool absolute) {
	if (absolute) shift_pos = vec2(x, y);
	else shift_pos += vec2(x, y);
	final_pos = base_pos + shift_pos;
};

void LifeGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* life = p.getSlot4(LIFE);
	for (uint32_t i = start; i < end; i++) {
		life[i].x = life[i].y = genrand_real(min, max);
		life[i].z = (float)0.0;
		life[i].w = (float)1.0 / life[i].x;
	}
}

void BasicTextureGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* tex = p.getSlot4(TEXTURE);
	for (uint32_t i = start; i < end; i++) {
		tex[i].s = 0;
		tex[i].t = 0;
		tex[i].p = 1;
		tex[i].q = 1;
	}
}

void DiskPosGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* pos = p.getSlot4(POS);
	for (uint32_t i = start; i < end; i++) {
		float a = genrand_real(0.0, M_PI * 2.0);
		float r = genrand_real(0, radius);
		pos[i].x = final_pos.x + cos(a) * r;
		pos[i].y = final_pos.y + sin(a) * r;
	}
}

void CirclePosGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* pos = p.getSlot4(POS);
	for (uint32_t i = start; i < end; i++) {
		float a = genrand_real(0.0, M_PI * 2.0);
		float r = genrand_real(radius - width, radius + width);
		pos[i].x = final_pos.x + cos(a) * r;
		pos[i].y = final_pos.y + sin(a) * r;
	}
}

TrianglePosGenerator::TrianglePosGenerator(vec2 p1, vec2 p2, vec2 p3) {
	start_pos = p1;
	u = vec2(p2.x - p1.x, p2.y - p1.y);
	v = vec2(p3.x - p1.x, p3.y - p1.y);
}
void TrianglePosGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* pos = p.getSlot4(POS);
	for (uint32_t i = start; i < end; i++) {
		// Find a random point in the *rectangle* of this coord system
		vec2 p(genrand_real(0, 1), genrand_real(0, 1));
		// But make sure we fall in the first half of it: AKA our triangle
		while (p.x + p.y > 1) { p.x=genrand_real(0, 1); p.y=genrand_real(0, 1); }
		// Matrix * vector compute: we return to the normal coords
		pos[i].x = final_pos.x + start_pos.x + p.x*u.x + p.y*v.x;
		pos[i].y = final_pos.y + start_pos.y + p.x*u.y + p.y*v.y;
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
