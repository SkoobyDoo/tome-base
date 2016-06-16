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

void DORTileMap::toScreen(mat4 cur_model, vec4 color) {

}


DORTileObject::~DORTileObject() {
	resetMapObjects();
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
	for (auto it = dos.begin() ; it != dos.end(); ++it) {
		DisplayObject *i = dynamic_cast<DisplayObject*>(*it);
		if (i) delete i;
	}
	DORContainer::clear();
}

void DORTileObject::render(RendererGL *container, mat4 cur_model, vec4 color) {
	if (mos_changed) regenData();
	DORContainer::render(container, cur_model, color);
}

void DORTileObject::renderZ(RendererGL *container, mat4 cur_model, vec4 color) {
	if (mos_changed) regenData();
	DORContainer::renderZ(container, cur_model, color);
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

		if (allow_shader && m->shader) tglUseProgramObject(0);

		moid++;
	}
	mos_changed = false;
}
