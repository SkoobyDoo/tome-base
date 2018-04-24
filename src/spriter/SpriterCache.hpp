/*
	TE4 - T-Engine 4
	Copyright (C) 2009 - 2018 Nicolas Casalini

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
#ifndef TE4SPRITER_CACHE_H
#define TE4SPRITER_CACHE_H

#include <string.h>
#include <string>
#include <map>

#include "displayobjects/Renderer.hpp"
#include "spriterengine/spriterengine.h"

using namespace std;
using namespace SpriterEngine;

struct texture_cache
{
	texture_type tex;
	int used = 0;
};

struct model_cache
{
	SpriterModel *model;
	int used = 0;
};

class DORSpriterCache
{
private:
	static map<string, texture_cache*> tex_cache;
	static map<string, model_cache*> models_cache;

public:
	static texture_cache* getTexture(string name);
	static void releaseTexture(texture_cache* t);

	static SpriterModel *getModel(string name);
	static void releaseModel(SpriterModel* model);
};

#endif
