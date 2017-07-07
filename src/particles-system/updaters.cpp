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
	if (bilinear) {
		for (uint32_t i = 0; i < p.count; i++) {
			float t = life[i].z;
			if (t < 0.5) color[i] = glm::mix(color_stop[i], color_start[i], t * 2.0);
			else color[i] = glm::mix(color_stop[i], color_start[i], 1.0 - (t - 0.5) * 2.0);
		}
	} else {
		for (uint32_t i = 0; i < p.count; i++) {
			color[i] = glm::mix(color_start[i], color_stop[i], life[i].z);
		}
	}
}

void EasingColorUpdater::update(ParticlesData &p, float dt) {
	vec4* color = p.getSlot4(COLOR);
	vec4* color_start = p.getSlot4(COLOR_START);
	vec4* color_stop = p.getSlot4(COLOR_STOP);
	vec4* life = p.getSlot4(LIFE);
	if (bilinear) {
		for (uint32_t i = 0; i < p.count; i++) {
			float t = life[i].z;
			if (t < 0.5) {
				t = t * 2.0;
				color[i].r = easing(color_stop[i].r, color_start[i].r, t);
				color[i].g = easing(color_stop[i].g, color_start[i].g, t);
				color[i].b = easing(color_stop[i].b, color_start[i].b, t);
				color[i].a = easing(color_stop[i].a, color_start[i].a, t);
			} else {
				t = 1.0 - (t - 0.5) * 2.0;
				color[i].r = easing(color_stop[i].r, color_start[i].r, t);
				color[i].g = easing(color_stop[i].g, color_start[i].g, t);
				color[i].b = easing(color_stop[i].b, color_start[i].b, t);
				color[i].a = easing(color_stop[i].a, color_start[i].a, t);
			}
		}
	} else {
		for (uint32_t i = 0; i < p.count; i++) {
			color[i].r = easing(color_start[i].r, color_stop[i].r, life[i].z);
			color[i].g = easing(color_start[i].g, color_stop[i].g, life[i].z);
			color[i].b = easing(color_start[i].b, color_stop[i].b, life[i].z);
			color[i].a = easing(color_start[i].a, color_stop[i].a, life[i].z);
		}
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

AnimatedTextureUpdater::AnimatedTextureUpdater(uint8_t splitx, uint8_t splity, uint8_t firstframe, uint8_t lastframe, float repeat_over_life) : repeat_over_life(repeat_over_life) {
	if (!splitx) splitx = 1;
	if (!splity) splity = 1;
	float p = 1.0 / (float)splitx;
	float q = 1.0 / (float)splity;
	frames.reserve(lastframe - firstframe + 1);
	for (int i = firstframe; i <= lastframe; i++) {
		int x = i % splitx;
		int y = i / splitx;
		float s = (float)x / (float)splitx;
		float t = (float)y / (float)splity;
		frames.emplace_back(s, t, s+p, t+q);
	}
	max = frames.size();
};

void AnimatedTextureUpdater::update(ParticlesData &p, float dt) {
	if (!max) return;
	vec4* life = p.getSlot4(LIFE);
	vec4* tex = p.getSlot4(TEXTURE);
	for (uint32_t i = 0; i < p.count; i++) {
		int frame_id = floorf(life[i].z * repeat_over_life * max);
		tex[i] = frames[frame_id % max];
	}
}

void EulerPosUpdater::update(ParticlesData &p, float dt) {
	vec4* pos = p.getSlot4(POS);
	vec2* vel = p.getSlot2(VEL);
	vec2* acc = p.getSlot2(ACC);
	for (uint32_t i = 0; i < p.count; i++) {
		acc[i] += global_acc * dt;
		vel[i] += acc[i] * dt;
		pos[i].x += vel[i].x * dt + global_vel.x * dt;
		pos[i].y += vel[i].y * dt + global_vel.y * dt;
	}
}

void EasingPosUpdater::update(ParticlesData &p, float dt) {
	vec4* pos = p.getSlot4(POS);
	vec2* vel = p.getSlot2(VEL);
	vec2* origin = p.getSlot2(ORIGIN_POS);
	vec4* life = p.getSlot4(LIFE);
	for (uint32_t i = 0; i < p.count; i++) {
		vec2 dist = vel[i] * life[i].y;
		pos[i].x = origin[i].x + easing(0, dist.x, life[i].z);
		pos[i].y = origin[i].y + easing(0, dist.y, life[i].z);
	}
}

void LinearSizeUpdater::update(ParticlesData &p, float dt) {
	vec4* pos = p.getSlot4(POS);
	vec2* size = p.getSlot2(SIZE);
	vec4* life = p.getSlot4(LIFE);
	for (uint32_t i = 0; i < p.count; i++) {
		pos[i].z = glm::mix(size[i].x, size[i].y, life[i].z);
	}
}

void EasingSizeUpdater::update(ParticlesData &p, float dt) {
	vec4* pos = p.getSlot4(POS);
	vec2* size = p.getSlot2(SIZE);
	vec4* life = p.getSlot4(LIFE);
	for (uint32_t i = 0; i < p.count; i++) {
		pos[i].z = easing(size[i].x, size[i].y, life[i].z);
	}
}

void LinearRotationUpdater::update(ParticlesData &p, float dt) {
	vec4* pos = p.getSlot4(POS);
	vec2* rot_vel = p.getSlot2(ROT_VEL);
	for (uint32_t i = 0; i < p.count; i++) {
		pos[i].w += rot_vel[i].x * dt;
	}
}

void EasingRotationUpdater::update(ParticlesData &p, float dt) {
	vec4* pos = p.getSlot4(POS);
	vec2* rot_vel = p.getSlot2(VEL);
	vec4* life = p.getSlot4(LIFE);
	for (uint32_t i = 0; i < p.count; i++) {
		float dist = rot_vel[i].x * life[i].y;
		pos[i].w = rot_vel[i].y + easing(0, dist, life[i].z);
	}
}

}
