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

void OriginPosGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec2* origin = p.getSlot2(ORIGIN_POS);
	vec4* pos = p.getSlot4(POS);
	for (uint32_t i = start; i < end; i++) {
		origin[i].x = pos[i].x;
		origin[i].y = pos[i].y;
	}
}

void DiskPosGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* pos = p.getSlot4(POS);
	for (uint32_t i = start; i < end; i++) {
		float a = genrand_real(min_angle, max_angle);
		float r = genrand_real(0, radius);
		pos[i].x = final_pos.x + cos(a) * r;
		pos[i].y = final_pos.y + sin(a) * r;
	}
}

void CirclePosGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* pos = p.getSlot4(POS);
	for (uint32_t i = start; i < end; i++) {
		float a = genrand_real(min_angle, max_angle);
		float r = genrand_real(radius - width, radius + width);
		pos[i].x = final_pos.x + cos(a) * r;
		pos[i].y = final_pos.y + sin(a) * r;
	}
}

void TrianglePosGenerator::finish() {
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

void LinePosGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* pos = p.getSlot4(POS);
	for (uint32_t i = start; i < end; i++) {
		pos[i].x = (p2.x - p1.x) * genrand_real(0, 1) + p1.x;
		pos[i].y = (p1.y - p2.y) / (p1.x - p2.x) * (pos[i].x - p1.x) + p1.y;
		pos[i].x += final_pos.x;
		pos[i].y += final_pos.y;
	}
}

void JaggedLineGeneratorBase::generateStrands(ParticlesData &p, uint32_t &start, uint32_t &end, vec2 p1, vec2 p2, vec4 &c1, vec4 &c2) {
	// printf("--generating at %d to %d\n", start, end);
	if (end - start < 2 || !strands) { end = start; return; }
	printf("===4\n");
	uint32_t nb_gen = end - start;

	vec4* pos = p.getSlot4(POS);
	vec4* color = p.getSlot4(COLOR);
	vec4* cstart = p.getSlot4(COLOR_START);
	vec4* cstop = p.getSlot4(COLOR_STOP);
	vec2* links = p.getSlot2(LINKS);

	vec2 tangent = p2 - p1;
	vec2 normal = glm::normalize(vec2(tangent.y, -tangent.x));
	float length = glm::length(tangent);
 
 	// printf("@stranding start %d\n", (int)strands);
 	if (strands < 1) strands = 1;
 	for (uint32_t strand = 0; strand < strands; strand++) {
	 	// printf("@stranding exec %d / %d\n", strand, (int)strands);
		vector<float> positions;
		positions.push_back((float)0);
		if (nb_gen > 2) {
			// Randomly choose spots
		 	for (int i = 0; i < nb_gen - 2; i++) positions.push_back((float)genrand_real(0, 1)); 
			std::sort(positions.begin(), positions.end());
		}
	 
	 
		pos[start].x = p1.x;
		pos[start].y = p1.y;
		color[start] = cstart[start] = cstop[start] = c1;
		links[start].x = -1; links[start].y = start + 1;

		float jaggedness = 1 / sway;
		float prevDisplacement = 0;
		// printf("=== morphing color from %0.2fx%0.2fx%0.2fx%0.2f or %0.2fx%0.2fx%0.2fx%0.2f\n", c1.r, c1.g, c1.b, c1.a, c2.r, c2.g, c2.b, c2.a);
		for (uint32_t i = 1; i < positions.size(); i++)
		{
			float curpos = positions[i];
	 
			// used to prevent sharp angles by ensuring very close positions also have small perpendicular variation.
			float scale = (length * jaggedness) * (curpos - positions[i - 1]);
	 
			// defines an envelope. Points near the middle of the bolt can be further from the central line.
			float envelope = curpos > 0.95f ? 20 * (1 - curpos) : 1;
	 
			float displacement = genrand_real(-sway, sway);
			displacement -= (displacement - prevDisplacement) * (1 - scale);
			displacement *= envelope;
	 
			vec2 point = p1 + curpos * tangent + displacement * normal;

			pos[start + i].x = point.x;
			pos[start + i].y = point.y;
			color[start + 1] = cstart[start + 1] = cstop[start + 1] = mix(c2, c1, curpos);
			// printf("  - morphing color as %0.2fx%0.2fx%0.2fx%0.2f\n", color[start + 1].r, color[start + 1].g, color[start + 1].b, color[start + 1].a);

			links[start + i].x = start + i - 1; links[start + i].y = start + i + 1;
			// printf("- filling %d with parents %d : %d\n", start+i, start+i-1,start+i+1);
			// printf("=== %d < %d < %d\n", start, start + i , end);
			
			prevDisplacement = displacement;
		} 

		pos[end-1].x = p2.x;
		pos[end-1].y = p2.y;
		color[end-1] = cstart[end-1] = cstop[end-1] = c2;
		links[end-1].x = end - 2; links[end-1].y = -1;

		if ((strand < strands - 1) && (end + nb_gen < p.max)) {
			start += nb_gen;
			end += nb_gen;
		} else {
			// printf("__ return cut %d -> %d (%d)\n", start, end, end-start);
			return;
		}
	}
	// printf("__ return %d -> %d (%d)\n", start, end, end-start);
}

uint32_t JaggedLinePosGenerator::generateLimit(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4 c;
	generateStrands(p, start, end, p1 + final_pos, p2 + final_pos, c, c);
	return end;
}

ImagePosGenerator::ImagePosGenerator(spPointsListHolder lph) : lph(lph) {
	use_limiter = true;
	// loader_points_list("/data/gfx/particles_masks/test.png", &list);
	// loader_points_list("/data/gfx/particles_masks/tome.png", &list);
	// loader_points_list("/data/gfx/particles_masks/tome-logo.png", &list);
}

uint32_t ImagePosGenerator::generateLimit(ParticlesData &p, uint32_t start, uint32_t end) {
	if (!lph->list->hasData()) { printf("==computing list..\n"); return start; }
	// printf("===== OK!\n");

	vector<points_list_entry> &list = lph->list->list;
	vec4* pos = p.getSlot4(POS);
	vec4* color = p.getSlot4(COLOR);
	vec4* cstart = p.getSlot4(COLOR_START);
	vec4* cstop = p.getSlot4(COLOR_STOP);

	for (uint32_t i = start; i < end; i++) {
		uint32_t id = rand_div(list.size());
		pos[i].x = list[id].pos.x + final_pos.x;
		pos[i].y = list[id].pos.y + final_pos.y;
		color[i] = list[id].color;
		cstart[i] = list[id].color;
		cstop[i] = list[id].color;
		// printf("computed list! generated point %f x %f :: %fx%fx%fx%f\n", pos[i].x, pos[i].x, color[i].r, color[i].g, color[i].b, color[i].a);
	}
	return end;
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

void DirectionVelGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* pos = p.getSlot4(POS);
	vec4* life = p.getSlot4(LIFE);
	vec2* vel = p.getSlot2(VEL);
	for (uint32_t i = start; i < end; i++) {
		float a = atan2f(pos[i].y - from.y - final_pos.y, pos[i].x - from.x - final_pos.x) + genrand_real(min_rot, max_rot);
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

void StartStopSizeGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* pos = p.getSlot4(POS);
	vec2* size = p.getSlot2(SIZE);
	for (uint32_t i = start; i < end; i++) {
		float size_start = genrand_real(min_start_size, max_start_size);
		float size_stop = genrand_real(min_stop_size, max_stop_size);
		pos[i].z = size_start;
		size[i].x = size_start;
		size[i].y = size_stop;
	}
}

void BasicRotationGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* pos = p.getSlot4(POS);
	for (uint32_t i = start; i < end; i++) {
		pos[i].w = genrand_real(min_rot, max_rot);
	}
}

void RotationByVelGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* pos = p.getSlot4(POS);
	vec2* vel = p.getSlot2(VEL);
	for (uint32_t i = start; i < end; i++) {
		float a = atan2f(vel[i].y, vel[i].x);
		pos[i].w = a + genrand_real(min_rot, max_rot);
	}
}

void SwapPosByVelGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* life = p.getSlot4(LIFE);
	vec2* origin = p.getSlot2(ORIGIN_POS);
	vec4* pos = p.getSlot4(POS);
	vec2* vel = p.getSlot2(VEL);
	for (uint32_t i = start; i < end; i++) {
		pos[i].x = pos[i].x + vel[i].x * life[i].x;
		pos[i].y = pos[i].y + vel[i].y * life[i].x;
		if (origin) origin[i] = origin[i] + vel[i] * life[i].x;
		vel[i] = -vel[i];
	}
}

void BasicRotationVelGenerator::generate(ParticlesData &p, uint32_t start, uint32_t end) {
	vec4* pos = p.getSlot4(POS);
	vec2* rot_vel = p.getSlot2(ROT_VEL);
	for (uint32_t i = start; i < end; i++) {
		rot_vel[i].x = genrand_real(min_rot, max_rot);
		rot_vel[i].y = pos[i].w; // Store initial rotation
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
	}
}

void CopyGenerator::useSlots(ParticlesData &p) {
	if (copy_pos) p.initSlot4(POS);
	if (copy_color) { p.initSlot4(COLOR); p.initSlot4(COLOR_START); p.initSlot4(COLOR_STOP); }
}
uint32_t CopyGenerator::generateLimit(ParticlesData &p, uint32_t start, uint32_t end) {
	ParticlesData &sp = source_system->getList();

	vec4* spos = sp.getSlot4(POS);
	vec4* scolor = sp.getSlot4(COLOR);
	vec4* scstart = sp.getSlot4(COLOR_START);
	vec4* scstop = sp.getSlot4(COLOR_STOP);

	vec4* pos = p.getSlot4(POS);
	vec4* color = p.getSlot4(COLOR);
	vec4* cstart = p.getSlot4(COLOR_START);
	vec4* cstop = p.getSlot4(COLOR_STOP);
	
	uint32_t si, i;
	for (si = 0, i = start; i < end && si < sp.count; i++, si++) {
		if (copy_pos) pos[i] = spos[si];
		if (copy_color) {
			color[i] = scolor[si];
			cstart[i] = scstart[si];
			cstop[i] = scstop[si];
		}
	}
	return i;
}

void JaggedLineBetweenGenerator::useSlots(ParticlesData &p) {
	p.initSlot2(LINKS);
	p.initSlot4(POS);
	if (copy_color) {
		p.initSlot4(COLOR);
		p.initSlot4(COLOR_START);
		p.initSlot4(COLOR_STOP);
	}
}
uint32_t JaggedLineBetweenGenerator::generateLimit(ParticlesData &p, uint32_t start, uint32_t end) {
	ParticlesData &sp1 = source_system1->getList();
	ParticlesData &sp2 = source_system2->getList();
	printf("===1\n");
	if (sp1.count < 2 || sp2.count < 2) { return start; }
	printf("===2\n");

	vec4* spos1 = sp1.getSlot4(POS);
	vec4* spos2 = sp2.getSlot4(POS);
	vec4* scol1 = sp1.getSlot4(COLOR);
	vec4* scol2 = sp2.getSlot4(COLOR);

	uint32_t nb_gen = end - start;

	for (uint32_t r = 0; r < repeat_times; r++) {
		uint32_t p1i = rand_div(sp1.count);
		vec2 p1(spos1[p1i].x, spos1[p1i].y);
		vec4 c1 = scol1[p1i];

		uint32_t p2i = rand_div(sp2.count);
		vec2 p2(spos2[p2i].x, spos2[p2i].y);
		vec4 c2 = scol2[p2i];
		for (uint8_t tries = 0; tries < close_tries; tries++) {
			uint32_t p2t = rand_div(sp2.count);
			vec2 pt(spos2[p2t].x, spos2[p2t].y);
			// printf("test for %d to %d\n", start, end);
			if (glm::length(pt-p1) < glm::length(p2-p1)) {
				// printf("using closer %f to %f\n", glm::length(pt-p1), glm::length(p2-p1));
				p2 = pt;
				c2 = scol2[p2t];
			}
		}
		c1.a = c2.a = 1;
		printf("===3\n");
		generateStrands(p, start, end, p1, p2, c1, c2);
		if (r < repeat_times - 1 && end + nb_gen < p.max) {
			start += nb_gen;
			end += nb_gen;
		} else break;
	}
	return end;
}


}
