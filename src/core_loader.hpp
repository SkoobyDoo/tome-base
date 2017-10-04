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
#ifndef _CORELOADER_H_
#define _CORELOADER_H_

#include "tgl.h"
#include "tSDL.h"
#include <atomic>
#include <vector>
#define GLM_FORCE_INLINE
#include "glm/glm.hpp"

struct noise_data {
	float *data;
	int32_t w, h;
	~noise_data() { delete[] data; };
	void define(int32_t w, int32_t h);
	void set(SDL_Surface *s);
	inline float get(int32_t x, int32_t y) {
		x = abs(x % w);
		y = abs(y % h);
		return data[y * w + x];
	};
};

struct points_list_entry {
	glm::vec2 pos;
	glm::vec4 color;
	points_list_entry(glm::vec2 pos, glm::vec4 color) : pos(pos), color(color) {};
};
struct points_list {
	std::vector<points_list_entry> list;
	std::atomic_flag lock;
	bool finished = false;
	bool hasData();
	void set(SDL_Surface *s);
};

extern bool loader_png(const char *filename, texture_type *t, bool nearest, bool norepeat, bool exact_size);
extern bool loader_noise(const char *filename, noise_data *noise);
extern bool loader_points_list(const char *filename, points_list *list);

#endif
