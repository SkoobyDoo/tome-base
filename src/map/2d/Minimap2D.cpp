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
#include "types.h"
#include "display.h"
#include <math.h>
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "main.h"
#include "script.h"
#include "useshader.h"
#include "assert.h"
}

#include "map/2d/Minimap2D.hpp"


Minimap2D::Minimap2D() {
	glGenTextures(1, &tex[0]);
	tglBindTexture(GL_TEXTURE_2D, tex[0]);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	// printf("===tilemap %ld with texture %d\n", this, tex[0]);
}

Minimap2D::~Minimap2D() {
	glDeleteTextures(1, &tex[0]);
	if (map) map->removeMinimap(this);
}

void Minimap2D::mapDeath(Map2D *map) {
	if (this->map != map) return;
	this->map = NULL;
};

void Minimap2D::setMap(Map2D *map) {
	if (!map) { printf("[Minimap2D] ERROR: trying to setMap a NULL map\n"); return; }
	map->addMinimap(this);
	this->map = map;
};

void Minimap2D::cloneInto(DisplayObject *_into) {
	DisplayObject::cloneInto(_into);
	Minimap2D *into = dynamic_cast<Minimap2D*>(_into);
	into->map = map;
}

void Minimap2D::setTexture(GLuint tex, int lua_ref, int id) {
	if (id == 0) {
		printf("[Minimap2D] ERROR: Setting texture 0 is NOT ALLOWED\n");
		return;
	}
	DORVertexes::setTexture(tex, lua_ref, id);
}

void Minimap2D::setMinimapInfo(int mdx, int mdy, int mdw, int mdh, float transp) {
	if (info.mdx == mdx && info.mdy == mdy && info.mdw == mdw && info.mdh == mdh && info.transp == transp) return;
	next_update_full = (info.mdw != mdw || info.mdh != mdh);
	info.mdx = mdx;
	info.mdy = mdy;
	info.mdw = mdw;
	info.mdh = mdh;
	info.transp = transp;
	ready = true;
}

void Minimap2D::redrawMiniMap() {
	if (!map || !ready) return;

	int z = 0, i = 0, j = 0;
	GLfloat r, g, b, a;

	// Create/recreate the minimap data if needed
	printf("MM %d\n", next_update_full);
	if (next_update_full) {
		if (mm_data) delete mm_data;
		mm_data = new GLubyte[4 * info.mdw * info.mdh];
		clear();
		addQuad(
			0, 0, 0, 0,
			0, info.mdh, 0, 1,
			info.mdw, info.mdh, 1, 1,
			info.mdw, 0, 1, 0,
			1, 1, 1, 1
		);
	}

	if (!mm_data) return;

	std::fill_n(mm_data, info.mdw * info.mdh * 4, 0);

	int mini = info.mdx, maxi = info.mdx + info.mdw, minj = info.mdy, maxj = info.mdy + info.mdh;
	if (mini < 0) mini = 0;
	if (minj < 0) minj = 0;
	if (maxi > map->w) maxi = map->w;
	if (maxj > map->h) maxj = map->h;

	int ptr;
	for (z = 0; z < map->zdepth; z++) {
		for (j = minj; j < maxj; j++) {
			for (i = mini; i < maxi; i++) {
				if (!map->checkBounds(z, i, j)) continue;
				MapObject *mo = map->at(z, i, j);
				if (!mo || mo->mm.r < 0) continue;
				ptr = ((j-info.mdy) * info.mdw + (i-info.mdx)) * 4;

				if ((mo->isSeen() && map->isSeen(i, j)) || (mo->isRemember() && map->isRemember(i, j)) || mo->isUnknown()) {
					if (map->isSeen(i, j)) {
						r = mo->mm.r; g = mo->mm.g; b = mo->mm.b; a = info.transp;
					} else {
						r = mo->mm.r * 0.6; g = mo->mm.g * 0.6; b = mo->mm.b * 0.6; a = info.transp * 0.6;
					}
					mm_data[ptr] = b * 255;
					mm_data[ptr+1] = g * 255;
					mm_data[ptr+2] = r * 255;
					mm_data[ptr+3] = a * 255;
				}
			}
		}
	}

	tglBindTexture(GL_TEXTURE_2D, tex[0]);
	// Full texture update means we change size so we need a full call to glTexImage2D
	if (next_update_full) glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, info.mdw, info.mdh, 0, GL_BGRA, GL_UNSIGNED_BYTE, mm_data);
	else glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, info.mdw, info.mdh, GL_BGRA, GL_UNSIGNED_BYTE, mm_data);

	next_update_full = false;
}
