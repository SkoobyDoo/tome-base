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
}

#include "renderer-moderngl/Renderer.hpp"
#include "renderer-moderngl/TileMap.hpp"


/*************************************************************************
 ** DORTileMap - a DO of a map
 *************************************************************************/

void DORTileMap::cloneInto(DisplayObject *_into) {
	DisplayObject::cloneInto(_into);
	DORTileMap *into = dynamic_cast<DORTileMap*>(_into);
	into->map = map;
}

void DORTileMap::toScreen(mat4 model, vec4 color) {
	switch (mode) {
		case TileMapMode::MAP:
			map_toscreen(L, map, 0, 0, 1, true, model, color);
		case TileMapMode::MINIMAP:
			minimap_toscreen(map, model, mm_info.gridsize, mm_info.mdx, mm_info.mdy, mm_info.mdw, mm_info.mdh, mm_info.transp);
	}
}

/*************************************************************************
 ** DORTileObject - a DO of an entity (kinda, more exactly of a list of MOs)
 *************************************************************************/

DORTileObject::~DORTileObject() {
	resetMapObjects();
	clear();
}

DisplayObject* DORTileObject::clone() {
	DORTileObject *into = new DORTileObject(w, h, a, allow_cb, allow_shader);
	this->cloneInto(into);
	return into;
}
void DORTileObject::cloneInto(DisplayObject *_into) {
	DORContainer::cloneInto(_into);
	DORTileObject *into = dynamic_cast<DORTileObject*>(_into);

	for (auto it = mos.begin() ; it != mos.end(); ++it) {
		int ref = LUA_NOREF;
		if (L && it->ref) {
			lua_rawgeti(L, LUA_REGISTRYINDEX, it->ref);
			ref = luaL_ref(L, LUA_REGISTRYINDEX);
		}
		into->addMapObject(it->mo, ref);
	}
}

void DORTileObject::resetMapObjects() {
	for (auto it = mos.begin() ; it != mos.end(); ++it) {
		if (it->ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, it->ref);
	}
	mos.clear();
	setChanged();
	mos_changed = true;
}

void DORTileObject::addMapObject(map_object *mo, int ref) {
	mos.push_back({mo, ref});
	setChanged();
	mos_changed = true;
}

// Normal clear, but also free the allocated objects, since they are not lua managed
// beware this means nothing besides regenData() should ::add() DOs
void DORTileObject::clear() {
	vector<DisplayObject*> olddos(dos);
	DORContainer::clear();
	for (auto it = olddos.begin() ; it != olddos.end(); ++it) {
		DisplayObject *i = dynamic_cast<DisplayObject*>(*it);
		if (i) delete i;
	}
}

void DORTileObject::render(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible) {
	if (mos_changed) regenData();
	DORContainer::render(container, cur_model, color, cur_visible);
}

void DORTileObject::renderZ(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible) {
	if (mos_changed) regenData();
	DORContainer::renderZ(container, cur_model, color, cur_visible);
}

void DORTileObject::sortZ(RendererGL *container, mat4 cur_model) {
	cur_model *= model;

	// We take a "virtual" point at zflat coordinates
	vec4 virtualz = cur_model * vec4(0, 0, 0, 1);
	sort_z = virtualz.z;
	sort_shader = NULL;
	sort_tex = {0,0,0};
	container->sorted_dos.push_back(this);
}


void DORTileObject::regenData() {
	clear();
	int moid = 6;
	for (auto it = mos.begin() ; it != mos.end(); ++it) {
		map_object *m = it->mo;
		map_object *dm = m;
		shader_type *shader = default_shader;
		int z;
		if (allow_shader && m->shader) shader = m->shader;

		while (dm)
		{
			int dx = dm->dx * w, dy = dm->dy * h;
			float dw = w * dm->dw;
			float dh = h * dm->dh;
			int dz = moid;

			GLuint tex = dm->textures[0];
			shader_type *use_shader = shader;
		 	if (m != dm && allow_shader && dm->shader) {
				if (allow_shader && m->shader) use_shader = dm->shader;
		 	}

		 	DORVertexes *v = new DORVertexes();
		 	v->setTexture(tex, LUA_NOREF);
		 	v->setShader(use_shader);
		 	v->addQuad(
				dx, dy, dz,  		dm->tex_x[0], dm->tex_y[0],
				dx+dw, dy, dz,  	dm->tex_x[0] + dm->tex_factorx[0], dm->tex_y[0],
				dx+dw, dy+dh, dz,  	dm->tex_x[0] + dm->tex_factorx[0], dm->tex_y[0] + dm->tex_factory[0],
				dx, dy+dh, dz,  	dm->tex_x[0], dm->tex_y[0] + dm->tex_factory[0],
				1, 1, 1, a
			);
			add(v);

			// DGDGDGDG
			// if (allow_cb && (dm->cb_ref != LUA_NOREF))
			// {
			// 	if (allow_shader && m->shader) tglUseProgramObject(0);
			// 	int dx = x + dm->dx * w, dy = y + dm->dy * h;
			// 	float dw = w * dm->dw;
			// 	float dh = h * dm->dh;
			// 	lua_rawgeti(L, LUA_REGISTRYINDEX, dm->cb_ref);
			// 	lua_pushnumber(L, dx);
			// 	lua_pushnumber(L, dy);
			// 	lua_pushnumber(L, dw);
			// 	lua_pushnumber(L, dh);
			// 	lua_pushnumber(L, 1);
			// 	lua_pushboolean(L, FALSE);
			// 	if (lua_pcall(L, 6, 1, 0))
			// 	{
			// 		printf("Display callback error: UID %ld: %s\n", dm->uid, lua_tostring(L, -1));
			// 		lua_pop(L, 1);
			// 	}
			// 	if (lua_isboolean(L, -1)) {
			// 		glTexCoordPointer(2, GL_FLOAT, 0, texcoords);
			// 		glColorPointer(4, GL_FLOAT, 0, colors);
			// 		glVertexPointer(3, GL_FLOAT, 0, vertices);
			// 	}
			// 	lua_pop(L, 1);

			// 	if (allow_shader && m->shader) useShader(m->shader, 0, 0, w, h, 0, 0, 1, 1, 1, 1, 1, a);
			// }

			dm = dm->next;
		}

		moid++;
	}
	mos_changed = false;
}
