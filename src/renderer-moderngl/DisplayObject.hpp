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
#include "font.h"
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

class RendererGL;

/****************************************************************************
 ** Generic display object
 ****************************************************************************/
class DisplayObject {
protected:
	int lua_ref = LUA_NOREF;
	DisplayObject *parent = NULL;
	lua_State *L = NULL;
	mat4 model;
	float x = 0, y = 0, z = 0;
	float rot_x = 0, rot_y = 0, rot_z = 0;
	float scale_x = 1, scale_y = 1, scale_z = 1;
	bool changed = false;
public:
	DisplayObject() { model = mat4(); };
	virtual ~DisplayObject() {
		if (lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, lua_ref);
	};
	void setLuaState(lua_State *L) { this->L = L; };
	void setLuaRef(int ref) {lua_ref = ref; };
	int unsetLuaRef() { int ref = lua_ref; lua_ref = LUA_NOREF; return ref; };
	void setParent(DisplayObject *parent) { this->parent = parent; };
	void setChanged();
	bool isChanged() { return changed; };
	void resetChanged() { changed = false; };

	void recomputeModelMatrix();

	void translate(float x, float y, float z, bool increment);
	void rotate(float x, float y, float z, bool increment);
	void scale(float x, float y, float z, bool increment);

	virtual void render(RendererGL *container, mat4 cur_model) = 0;
	virtual void renderZ(RendererGL *container, mat4 cur_model) = 0;
};

/****************************************************************************
 ** DO that has a vertex list
 ****************************************************************************/
class DORVertexes : public DisplayObject{
protected:
	vector<vertex> vertices;
	int tex_lua_ref = LUA_NOREF;
	GLuint tex;
	shader_type *shader;

public:
	DORVertexes() {
		vertices.reserve(4);
		tex = 0;
		shader = default_shader;
	};
	virtual ~DORVertexes() {
		if (tex_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, tex_lua_ref);		
	};

	void clear();

	int addQuad(
		float x1, float y1, float u1, float v1, 
		float x2, float y2, float u2, float v2, 
		float x3, float y3, float u3, float v3, 
		float x4, float y4, float u4, float v4, 
		float r, float g, float b, float a
	);
	virtual void setTexture(GLuint tex, int lua_ref) {
		if (tex_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, tex_lua_ref);
		this->tex = tex;
		tex_lua_ref = lua_ref;
	};
	void setShader(shader_type *s) { shader = s; };

	virtual void render(RendererGL *container, mat4 cur_model);
	virtual void renderZ(RendererGL *container, mat4 cur_model);
};

/****************************************************************************
 ** DO that can contain others
 ****************************************************************************/
class DORContainer : public DisplayObject{
protected:
	vector<DisplayObject*> dos;
public:
	DORContainer() {};
	virtual ~DORContainer() {};

	void add(DisplayObject *dob);
	void remove(DisplayObject *dob);
	void clear();

	virtual void render(RendererGL *container, mat4 cur_model);
	virtual void renderZ(RendererGL *container, mat4 cur_model);
};

/****************************************************************************
 ** A FBO that masquerades as a DORVertexes, draw stuff in it and
 ** then add it to a renderer to use the content generated
 ****************************************************************************/
class DORTarget : public DORVertexes{
protected:
	int w, h;
	GLuint fbo;
	vector<GLuint> textures;
	vector<GLenum> buffers;
	int nbt = 0;
	float clear_r = 0, clear_g = 0, clear_b = 0, clear_a = 1; 

public:
	DORTarget();
	DORTarget(int w, int h, int nbt);
	virtual ~DORTarget();

	void setClearColor(float r, float g, float b, float a);
	void use(bool activate);
	virtual void setTexture(GLuint tex, int lua_ref) { printf("Error, trying to set DORTarget texture.\n"); }; // impossible
};

#endif
