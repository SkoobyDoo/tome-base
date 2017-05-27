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
#ifndef CPPMAPOBJECT_H
#define CPPMAPOBJECT_H

#include "renderer-moderngl/Renderer.hpp"
#include <string.h>

#include "map.hpp"

/***********************************************************************
 ** Map
 ***********************************************************************/
// This one is a little strange, it is not the master of map_type it's a slave, as such it will never try to free it or anything, it is created by it
// This is, in essence, a DO warper around map code
class DORTileMap : public SubRenderer{
private:
	map_type *map = NULL;
	virtual void cloneInto(DisplayObject *into);

public:
	DORTileMap();
	virtual ~DORTileMap();
	DO_STANDARD_CLONE_METHOD(DORTileMap);
	virtual const char* getKind() { return "DORTileMap"; };

	void setMap(map_type *map);
	virtual void toScreen(mat4 cur_model, vec4 color);
};

/***********************************************************************
 ** MiniMap
 ***********************************************************************/
// This one is a little strange, it is not the master of map_type it's a slave, as such it will never try to free it or anything, it is created by it
// This is, in essence, a DO warper around map code
class DORTileMiniMap : public DORVertexes{
private:
	map_type *map = NULL;
	struct {
		int mdx = -9999, mdy = -9999;
		int mdw = 500000, mdh = 500000;
		float transp = 1000;
	} info;
	bool redraw_mm = true;
	bool ready = false;

	GLubyte *mm_data = NULL;

	virtual void cloneInto(DisplayObject *into);

public:
	DORTileMiniMap();
	virtual ~DORTileMiniMap();
	DO_STANDARD_CLONE_METHOD(DORTileMiniMap);
	virtual const char* getKind() { return "DORTileMiniMap"; };

	virtual void setTexture(GLuint tex, int lua_ref, int id);

	void setMap(map_type *map);
	void redrawMiniMap(bool full_texture_update = false);
	void setMinimapInfo(int mdx, int mdy, int mdw, int mdh, float transp);
};

/***********************************************************************
 ** Map Object
 ***********************************************************************/
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

	virtual void cloneInto(DisplayObject *into);

public:
	DORTileObject(float w, float h, float a, bool allow_cb, bool allow_shader) {
		this->w = w; this->h = h; this->a = a; this->allow_cb = allow_cb; this->allow_shader = allow_shader;
	};
	virtual ~DORTileObject();
	virtual DisplayObject* clone(); // We dont use the standard definition, see .cpp file
	virtual const char* getKind() { return "DORTileObject"; };

	void resetMapObjects();
	void addMapObject(map_object *mo, int ref);

	virtual void clear();

	void regenData();
	virtual void render(RendererGL *container, mat4& cur_model, vec4& color, bool cur_visible);
	virtual void renderZ(RendererGL *container, mat4& cur_model, vec4& color, bool cur_visible);
	virtual void sortZ(RendererGL *container, mat4& cur_model);
};

#endif
