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
#include "lua.h"
#include "lauxlib.h"
#include "display.h"
#include "types.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "main.h"
#include "core_lua.h"
#include "math.h"
}

#include "spriter/Spriter.hpp"
#include "spriter/SpriterCache.hpp"

map<string, texture_cache*> DORSpriterCache::tex_cache;
map<string, model_cache*> DORSpriterCache::models_cache;

texture_cache* DORSpriterCache::getTexture(string name) {
	auto it = tex_cache.find(name);
	if (it != tex_cache.end()) {
		texture_cache *tex = it->second;
		tex->used++;
		return tex;
	}

	texture_cache *tex = new texture_cache;
	tex_cache[name] = tex;

	SDL_Surface *s = IMG_Load_RW(PHYSFSRWOPS_openRead(name.c_str()), TRUE);
	if (!s) {
		printf("[SPRITER] texture file not found %s\n", name.c_str());
		tex->tex = 0;
		return tex;
	}

	glGenTextures(1, &tex->tex);
	tfglBindTexture(GL_TEXTURE_2D, tex->tex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

	GLint nOfColors = s->format->BytesPerPixel;
	GLenum texture_format = sdl_gl_texture_format(s);
	glTexImage2D(GL_TEXTURE_2D, 0, nOfColors, s->w, s->h, 0, texture_format, GL_UNSIGNED_BYTE, s->pixels);

	tex->w = s->w;
	tex->h = s->h;

	SDL_FreeSurface(s);
	printf("[SPRITER] New texture %s = %d\n", name.c_str(), tex->tex);
	return tex;
}

void DORSpriterCache::releaseTexture(texture_cache* tex) {
	for (auto it = tex_cache.begin(); it != tex_cache.end(); it++) {
		if (it->second == tex) {
			tex->used--;
			if (tex->used <= 0) {
				tex_cache.erase(it);
				printf("[SPRITER] Releasing texture %s = %d\n", it->first.c_str(), tex->tex);
				glDeleteTextures(1, &tex->tex);
				delete tex;
			}
			return;
		}
	}
}

SpriterModel* DORSpriterCache::getModel(string name) {
	auto it = models_cache.find(name);
	if (it != models_cache.end()) {
		model_cache *model = it->second;
		model->used++;
		return model->model;
	}

	model_cache *model = new model_cache;
	models_cache[name] = model;
	model->model = new SpriterModel(name, new TE4FileFactory(), new TE4ObjectFactory());
	printf("[SPRITER] New model %s\n", name.c_str());
	return model->model;
}

void DORSpriterCache::releaseModel(SpriterModel* model) {
	for (auto it = models_cache.begin(); it != models_cache.end(); it++) {
		if (it->second->model == model) {
			it->second->used--;
			if (it->second->used <= 0) {
				models_cache.erase(it);
				printf("[SPRITER] Releasing model %s\n", it->first.c_str());
				delete model;
			}
			return;
		}
	}
}
