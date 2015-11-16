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
#include "display.h"
#include "types.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "renderer.h"
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

int DOVertexes::addQuad(
		float x1, float y1, float u1, float v1, 
		float x2, float y2, float u2, float v2, 
		float x3, float y3, float u3, float v3, 
		float x4, float y4, float u4, float v4, 
		float r, float g, float b, float a
	) {
	if (vertices.size() + 4 < vertices.capacity()) vertices.reserve(vertices.size() * 2);

	vertex ve1 = {{x1, y1}, {u1, v1}, {r, g, b, a}};
	vertex ve2 = {{x2, y2}, {u2, v2}, {r, g, b, a}};
	vertex ve3 = {{x3, y3}, {u3, v3}, {r, g, b, a}};
	vertex ve4 = {{x4, y4}, {u4, v4}, {r, g, b, a}};
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
	for (vector<DisplayObject*>::iterator it = dos.begin() ; it != dos.end(); ++it) {
		if (*it == dob) {
			dos.erase(it);
			(*it)->setParent(NULL);
			return;
		}
	}
};
