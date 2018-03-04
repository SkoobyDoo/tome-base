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
#include "math.h"
}

#include "core_lua.hpp"
#include "core_loader.hpp"
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

	if (!loader_png(name.c_str(), &tex->tex, false, false, true)) {
		printf("[SPRITER] texture file not found %s\n", name.c_str());
		tex->tex.tex = 0;
		return tex;
	}

	printf("[SPRITER] New texture %s = %d (%dx%d)\n", name.c_str(), tex->tex.tex, tex->tex.w, tex->tex.h);
	return tex;
}

void DORSpriterCache::releaseTexture(texture_cache* tex) {
	for (auto it = tex_cache.begin(); it != tex_cache.end(); it++) {
		if (it->second == tex) {
			tex->used--;
			if (tex->used <= 0) {
				tex_cache.erase(it);
				printf("[SPRITER] Releasing texture %s = %d\n", it->first.c_str(), tex->tex);
				glDeleteTextures(1, &tex->tex.tex);
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
