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

#include "displayobjects/DisplayObject.hpp"

void DisplayObject::setChanged() {
	changed = true;
	DisplayObject *p = parent;
	while (p) {
		p->changed = true;
		p = p->parent;
	}
}

	// printf("%f, %f, %f, %f\n", model[0][0], model[0][1], model[0][2], model[0][3]);
	// printf("%f, %f, %f, %f\n", model[1][0], model[1][1], model[1][2], model[1][3]);
	// printf("%f, %f, %f, %f\n", model[2][0], model[2][1], model[2][2], model[2][3]);
	// printf("%f, %f, %f, %f\n", model[3][0], model[3][1], model[3][2], model[3][3]);

void DisplayObject::translate(float x, float y, float z) {
	model = glm::translate(model, glm::vec3(x, y, z));
	setChanged();
}

void DisplayObject::rotate(float a, float x, float y, float z) {
	model = glm::rotate(model, a, glm::vec3(x, y, z));
	setChanged();
}

void DisplayObject::scale(float x, float y, float z) {
	model = glm::scale(model, glm::vec3(x, y, z));
	setChanged();
}

int DOVertexes::addQuad(
		float x1, float y1, float u1, float v1, 
		float x2, float y2, float u2, float v2, 
		float x3, float y3, float u3, float v3, 
		float x4, float y4, float u4, float v4, 
		float r, float g, float b, float a
	) {
	if (vertices.size() + 4 < vertices.capacity()) vertices.reserve(vertices.size() * 2);

	vertex ve1 = {{x1, y1, 0, 1}, {u1, v1}, {r, g, b, a}};
	vertex ve2 = {{x2, y2, 0, 1}, {u2, v2}, {r, g, b, a}};
	vertex ve3 = {{x3, y3, 0, 1}, {u3, v3}, {r, g, b, a}};
	vertex ve4 = {{x4, y4, 0, 1}, {u4, v4}, {r, g, b, a}};
	vertices.push_back(ve1);
	vertices.push_back(ve2);
	vertices.push_back(ve3);
	vertices.push_back(ve4);

	setChanged();
	return 0;
}

void DOContainer::add(DisplayObject *dob) {
	dos.push_back(dob);
	dob->setParent(this);
	setChanged();
};

void DOContainer::remove(DisplayObject *dob) {
	for (auto it = dos.begin() ; it != dos.end(); ++it) {
		if (*it == dob) {
			setChanged();

			dos.erase(it);

			dob->setParent(NULL);
			if (L) {
				int ref = dob->unsetLuaRef();
				if (ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, ref);
			}
			return;
		}
	}
};

void DOContainer::clear() {
	for (auto it = dos.begin() ; it != dos.end(); ++it) {
		(*it)->setParent(NULL);
		if (L) {
			int ref = (*it)->unsetLuaRef();
			if (ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, ref);
		}
	}
	dos.clear();
	setChanged();
}
