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
#ifndef DISPLAYOBJECTS_H
#define DISPLAYOBJECTS_H

extern "C" {
#include "tgl.h"
#include "useshader.h"
}

#include <vector>

#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"
#include "glm/ext.hpp"

using namespace glm;
using namespace std;

typedef struct {
	vec4 pos;
	vec2 tex;
	vec4 color;
} vertex;

class Renderer;
class DisplayObject;

class DisplayObject {
private:
	int lua_ref = LUA_NOREF;
	DisplayObject *parent = NULL;
protected:
	lua_State *L = NULL;
	mat4 model;
	bool changed = false;
public:
	DisplayObject() { model = mat4(); };
	virtual ~DisplayObject() {};
	void setLuaState(lua_State *L) { this->L = L; };
	void setLuaRef(int ref) {lua_ref = ref; };
	int unsetLuaRef() { int ref = lua_ref; lua_ref = LUA_NOREF; return ref; };
	void setParent(DisplayObject *parent) { this->parent = parent; };
	void setChanged();
	bool isChanged() { return changed; };
	void resetChanged() { changed = false; };

	void translate(float x, float y, float z);
	void rotate(float a, float x, float y, float z);
	void scale(float x, float y, float z);
};

class DOVertexes : public DisplayObject{
public:
	// static long next_id = 1;
	vector<long> ids;
	vector<vertex> vertices;
	int tex_lua_ref = LUA_NOREF;
	GLuint tex;
	shader_type *shader;

	DOVertexes() {
		ids.reserve(4);
		vertices.reserve(4);
		tex = 0;
		shader = default_shader;
	};
	virtual ~DOVertexes() {};

	int addQuad(
		float x1, float y1, float u1, float v1, 
		float x2, float y2, float u2, float v2, 
		float x3, float y3, float u3, float v3, 
		float x4, float y4, float u4, float v4, 
		float r, float g, float b, float a
	);
	void setTexture(GLuint tex, int lua_ref) {
		if (tex_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, tex_lua_ref);
		this->tex = tex;
		tex_lua_ref = lua_ref;
	};
	void setShader(shader_type *s) { shader = s; };
};

class DOContainer : public DisplayObject{
protected:
	vector<DisplayObject*> dos;
public:
	DOContainer() {};
	virtual ~DOContainer() {};

	void add(DisplayObject *dob);
	void remove(DisplayObject *dob);
	void clear();
};

#endif
