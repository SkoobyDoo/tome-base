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
#ifndef _SPINE_H_
#define _SPINE_H_

#define SPINE_SHORT_NAMES
#include "spine/spine.h"

typedef struct {
	SkeletonData *skeleton_data;
	AnimationStateData *state_data;
} spine_data_type;

typedef struct {
	int data_ref;

	Skeleton* skeleton;
	AnimationState* state;
	float* worldVertices;
	float timeScale;

	GLfloat *vertices;
	GLfloat *colors;
	GLfloat *texcoords;
} spine_type;

extern int luaopen_spine(lua_State *L);
extern void spine_draw(spine_type *s, float x, float y, float nb_keyframes);

#endif

