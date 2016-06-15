/*
	TE4 - T-Engine 4
	Copyright (C) 2009 - 2015 Nicolas Casalini

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
#ifndef CPPMAPOBJECT_H
#define CPPMAPOBJECT_H

#include "renderer-moderngl/Renderer.hpp"
#include <string.h>

extern "C" {
#include "map.h"
}

class DORTileMap : public SubRenderer{
private:

public:
	DORTileMap() {
	};
	virtual ~DORTileMap() {
	};
	virtual const char* getKind() { return "DORTileMap"; };

	virtual void toScreen(mat4 cur_model, vec4 color);
};

typedef struct
{
	map_object *mo;
	int ref;
} map_object_ref;

class DORTileObject : public DORContainer{
private:
	vector<map_object_ref> mos;
	bool allow_cb = false;
	bool allow_shader = false;
	float w, h, a;	
	bool mos_changed = true;

public:
	DORTileObject(float w, float h, float a, bool allow_cb, bool allow_shader) {
		this->w = w; this->h = h; this->a = a; this->allow_cb = allow_cb; this->allow_shader = allow_shader;
	};
	virtual ~DORTileObject();
	virtual const char* getKind() { return "DORTileObject"; };

	void resetMapObjects();
	void addMapObject(map_object *mo, int ref);

	void regenData();
	virtual void render(RendererGL *container, mat4 cur_model, vec4 color);
	virtual void renderZ(RendererGL *container, mat4 cur_model, vec4 color);
};

#endif
