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

#ifndef RENDERER_H
#define RENDERER_H

extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "auxiliar.h"
#include "display.h"
#include "types.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "main.h"
}

#define GLM_FORCE_INLINE
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

#include "displayobjects/Interfaces.hpp"
#include "displayobjects/View.hpp"
#include "displayobjects/DisplayObject.hpp"
// #include "displayobjects/TextObject.hpp"
#include "displayobjects/RendererGL.hpp"
//#include "displayobjects/TileMap.hpp"

extern DisplayList* getDisplayList(RendererGL *container, GLuint tex, shader_type *shader);
extern void releaseDisplayList(DisplayList *dl);

template<class T=DisplayObject>T* userdata_to_DO(const char *caller, lua_State *L, int index, const char *auxclass=nullptr) {
	DisplayObject **ptr;
	if (auxclass) {
		ptr = reinterpret_cast<DisplayObject**>(auxiliar_checkclass(L, auxclass, index));
	} else {
		ptr = reinterpret_cast<DisplayObject**>(lua_touserdata(L, index));
		if (!ptr) {
			printf("invalid display object passed ! %s expected\n", typeid(T).name());
			traceback(L);
			luaL_error(L, "invalid display object passed");
		}
	}
	T* result = dynamic_cast<T*>(*ptr);
	if (!result) {
		printf("display object of wrong class! %s / %s (expected) !=! %s (actual) from %s\n", typeid(T).name(), auxclass ? auxclass : "", (*ptr)->getKind(), caller);
		traceback(L);
		luaL_error(L, "display object of wrong class");
	}
	return result;
}

#endif
