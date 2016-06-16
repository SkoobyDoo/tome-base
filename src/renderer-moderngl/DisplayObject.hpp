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

#define DO_STANDARD_CLONE_METHOD(class_name) virtual DisplayObject* clone() { DisplayObject *into = new class_name(); this->cloneInto(into); return into; }

typedef struct {
	vec4 pos;
	vec2 tex;
	vec4 color;
} vertex;

class RendererGL;
extern int donb;
/****************************************************************************
 ** Generic display object
 ****************************************************************************/
class DisplayObject {
protected:
	int lua_ref = LUA_NOREF;
	DisplayObject *parent = NULL;
	lua_State *L = NULL;
	mat4 model;
	vec4 color;
	bool visible = true;
	float x = 0, y = 0, z = 0;
	float rot_x = 0, rot_y = 0, rot_z = 0;
	float scale_x = 1, scale_y = 1, scale_z = 1;
	bool changed = false;
	
	virtual void cloneInto(DisplayObject *into);
public:
	DisplayObject() { donb++; printf("+DOs %d\n", donb); model = mat4(); color.r = 1; color.g = 1; color.b = 1; color.a = 1; };
	virtual ~DisplayObject() {
		donb--; printf("-DOs %d\n", donb);
		removeFromParent();
		if (lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, lua_ref);
	};
	virtual const char* getKind() = 0;
	virtual DisplayObject* clone() = 0;

	void setLuaState(lua_State *L) { this->L = L; };
	void setLuaRef(int ref) {lua_ref = ref; };
	int unsetLuaRef() { int ref = lua_ref; lua_ref = LUA_NOREF; return ref; };
	void setParent(DisplayObject *parent);
	void removeFromParent();
	// DGDGDGDG: setChanged repercutes over all the parents, but it should stop at RendererGLs
	void setChanged();
	bool isChanged() { return changed; };
	void resetChanged() { changed = false; };

	void recomputeModelMatrix();

	vec4 getColor() { return color; };
	void getRotate(float *dx, float *dy, float *dz) { *dx = rot_x; *dy = rot_y; *dz = rot_z; };
	void getTranslate(float *dx, float *dy, float *dz) { *dx = x; *dy = y; *dz = z; };
	void getScale(float *dx, float *dy, float *dz) { *dx = scale_x; *dy = scale_y; *dz = scale_z; };
	bool getShown() { return visible; };

	void setColor(float r, float g, float b, float a);
	void resetModelMatrix();
	void translate(float x, float y, float z, bool increment);
	void rotate(float x, float y, float z, bool increment);
	void scale(float x, float y, float z, bool increment);
	void shown(bool v);

	virtual void render(RendererGL *container, mat4 cur_model, vec4 color) = 0;
	virtual void renderZ(RendererGL *container, mat4 cur_model, vec4 color) = 0;
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

	virtual void cloneInto(DisplayObject *into);

public:
	DORVertexes() {
		vertices.reserve(4);
		tex = 0;
		shader = default_shader;
	};
	virtual ~DORVertexes() {
		if (tex_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, tex_lua_ref);		
	};
	DO_STANDARD_CLONE_METHOD(DORVertexes);
	virtual const char* getKind() { return "DORVertexes"; };

	void clear();

	int addQuad(
		float x1, float y1, float u1, float v1, 
		float x2, float y2, float u2, float v2, 
		float x3, float y3, float u3, float v3, 
		float x4, float y4, float u4, float v4, 
		float r, float g, float b, float a
	);
	int addQuad(
		float x1, float y1, float z1, float u1, float v1, 
		float x2, float y2, float z2, float u2, float v2, 
		float x3, float y3, float z3, float u3, float v3, 
		float x4, float y4, float z4, float u4, float v4, 
		float r, float g, float b, float a
	);
	virtual void setTexture(GLuint tex, int lua_ref) {
		if (tex_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, tex_lua_ref);
		this->tex = tex;
		tex_lua_ref = lua_ref;
	};
	void setShader(shader_type *s) { shader = s; };

	virtual void render(RendererGL *container, mat4 cur_model, vec4 color);
	virtual void renderZ(RendererGL *container, mat4 cur_model, vec4 color);
};

/****************************************************************************
 ** DO that can contain others
 ****************************************************************************/
class DORContainer : public DisplayObject{
protected:
	vector<DisplayObject*> dos;
	
	virtual void cloneInto(DisplayObject *into);
public:
	DORContainer() {};
	virtual ~DORContainer();
	DO_STANDARD_CLONE_METHOD(DORVertexes);
	virtual const char* getKind() { return "DORContainer"; };

	virtual void add(DisplayObject *dob);
	virtual void remove(DisplayObject *dob);
	virtual void clear();

	virtual void render(RendererGL *container, mat4 cur_model, vec4 color);
	virtual void renderZ(RendererGL *container, mat4 cur_model, vec4 color);
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

	virtual void cloneInto(DisplayObject *into);

public:
	DORTarget();
	DORTarget(int w, int h, int nbt);
	virtual ~DORTarget();
	virtual DisplayObject* clone(); // We dont use the standard definition, see .cpp file
	virtual const char* getKind() { return "DORTarget"; };

	void setClearColor(float r, float g, float b, float a);
	void displaySize(int w, int h, bool center);
	void use(bool activate);
	virtual void setTexture(GLuint tex, int lua_ref) { printf("Error, trying to set DORTarget texture.\n"); }; // impossible
};

#endif
