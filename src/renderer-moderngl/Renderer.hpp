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

#ifndef RENDERER_H
#define RENDERER_H

extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "display.h"
#include "types.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "main.h"
}

#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"
#include "glm/ext.hpp"

#include <memory>
#include <stack>
#include <queue>
#include <vector>

using namespace glm;
using namespace std;

#include "renderer-moderngl/Interfaces.hpp"
#include "renderer-moderngl/View.hpp"
#include "renderer-moderngl/DisplayObject.hpp"
// #include "renderer-moderngl/TextObject.hpp"
#include "renderer-moderngl/RendererGL.hpp"
//#include "renderer-moderngl/TileMap.hpp"

extern DisplayList* getDisplayList(RendererGL *container, GLuint tex, shader_type *shader);
extern void releaseDisplayList(DisplayList *dl);

template<class T=DisplayObject> extern T* userdata_to_DO(const char *caller, lua_State *L, int index, const char *auxclass = nullptr);

#endif
