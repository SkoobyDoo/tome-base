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
extern lua_State *L;
}

#include <vector>

#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"
#include "glm/ext.hpp"

using namespace glm;
using namespace std;

class View;
class RendererGL;
class DisplayObject;
class DORPhysic;

#define DO_STANDARD_CLONE_METHOD(class_name) virtual DisplayObject* clone() { DisplayObject *into = new class_name(); this->cloneInto(into); return into; }

const int DO_MAX_TEX = 3;

typedef struct {
	vec4 pos;
	vec2 tex;
	vec4 color;

	// DGDGDGDG: really if that could be split off and only "tacked on" when needed it'd rule ..
	// We could even exclude color when unwanted, and to make it all configurable maybe use C++ <bitset> which
	// converts to a long int, making display list invalidation very easy for any combo
	vec4 texcoords;
	vec4 mapcoords;
 	float kind;
} vertex;

struct recomputematrix {
	mat4 model;
	vec4 color;
	bool visible;
};

enum TweenSlot : unsigned char {
	TX = 0, TY = 1, TZ = 2, 
	SX = 3, SY = 4, SZ = 5, 
	RX = 6, RY = 7, RZ = 8, 
	R = 9, G = 10, B = 11, A = 12,
	WAIT = 13,
	MAX = 14
};

typedef float (*easing_ptr)(float,float,float);

struct TweenState {
	easing_ptr easing;
	float from, to;
	float cur, time;
	int on_end_ref, on_change_ref;
};

class DORTweener : public IRealtime {
protected:
	DisplayObject *who = NULL;
	array<TweenState, (short)TweenSlot::MAX> tweens;

public:
	DORTweener(DisplayObject *d);
	virtual ~DORTweener();
	virtual void killMe();
	void setTween(TweenSlot slot, easing_ptr easing, float from, float to, float time, int on_end_ref, int on_change_ref);
	void cancelTween(TweenSlot slot);
	virtual void onKeyframe(float nb_keyframes);
};

extern int donb;
/****************************************************************************
 ** Generic display object
 ****************************************************************************/
class DisplayObject {
	friend class DORPhysic;
	friend class DORTweener;
	friend class View;
public:
	static int weak_registry_ref;
protected:
	int weak_self_ref = LUA_NOREF;
	int lua_ref = LUA_NOREF;
	// lua_State *L = NULL;
	mat4 model;
	vec4 color;
	bool visible = true;
	float x = 0, y = 0, z = 0;
	float rot_x = 0, rot_y = 0, rot_z = 0;
	float scale_x = 1, scale_y = 1, scale_z = 1;
	bool changed = true;
	bool changed_children = true;
	bool stop_parent_recursing = false;

	DORTweener *tweener = NULL;
	DORPhysic *physic = NULL;
	
	virtual void cloneInto(DisplayObject *into);
public:
	DisplayObject *parent = NULL;
	DisplayObject();
	virtual ~DisplayObject();
	virtual const char* getKind() = 0;
	virtual DisplayObject* clone() = 0;

	// void setLuaState(lua_State *L) { this->L = L; };
	void setWeakSelfRef(int ref) {weak_self_ref = ref; };
	void setLuaRef(int ref) {lua_ref = ref; };
	int unsetLuaRef() { int ref = lua_ref; lua_ref = LUA_NOREF; return ref; };
	void setParent(DisplayObject *parent);
	void removeFromParent();
	void setChanged(bool force=false);
	virtual void setSortingChanged();
	bool isChanged() { return changed; };
	void resetChanged() { changed = false; changed_children = false; };
	bool independantRenderer() { return stop_parent_recursing; };

	void enablePhysic();
	DORPhysic *getPhysic();

	void recomputeModelMatrix();
	recomputematrix computeParentCompositeMatrix(DisplayObject *stop_at, recomputematrix cur);

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

	void tween(TweenSlot slot, easing_ptr easing, float from, float to, float time, int on_end_ref, int on_change_ref);
	void cancelTween(TweenSlot slot);
	float getDefaultTweenSlotValue(TweenSlot slot);

	virtual void tick() {}; // Overload that and register your object into a display list's tick to interrupt display list chain and call tick() before your first one is displayed

	virtual void render(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible) = 0;
	virtual void renderZ(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible) = 0;
	virtual void sortZ(RendererGL *container, mat4 cur_model) = 0;
};

/****************************************************************************
 ** All childs of that can be sorted in fast mode by RendererGl
 ****************************************************************************/
class DORFlatSortable : public DisplayObject {
public:
	shader_type *sort_shader;
	array<GLuint, DO_MAX_TEX> sort_tex;
	float sort_z;
};

/****************************************************************************
 ** DO that has a vertex list
 ****************************************************************************/
class DORVertexes : public DORFlatSortable{
protected:
	vector<vertex> vertices;
	array<int, DO_MAX_TEX> tex_lua_ref{{ LUA_NOREF, LUA_NOREF, LUA_NOREF}};
	array<GLuint, DO_MAX_TEX> tex{{0, 0, 0}};
	int tex_max = 1;
	bool is_zflat = true;
	float zflat = 0;

	shader_type *shader;

	virtual void cloneInto(DisplayObject *into);

public:
	DORVertexes() {
		vertices.reserve(4);
		shader = default_shader;
	};
	virtual ~DORVertexes();
	DO_STANDARD_CLONE_METHOD(DORVertexes);
	virtual const char* getKind() { return "DORVertexes"; };

	void clear();

	void reserveQuads(int nb) { vertices.reserve(4 * nb); };

	int addQuadPie(
		float x1, float y1, float x2, float y2,
		float u1, float v1, float u2, float v2,
		float angle,
		float r, float g, float b, float a
	);
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
	void loadObj(const string &filename);
	GLuint getTexture(int id) { return tex[id]; };
	virtual void setTexture(GLuint tex, int lua_ref, int id);
	virtual void setTexture(GLuint tex, int lua_ref) { setTexture(tex, lua_ref, 0); };
	void setShader(shader_type *s) { shader = s ? s : default_shader; };

	virtual void render(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible);
	virtual void renderZ(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible);
	virtual void sortZ(RendererGL *container, mat4 cur_model);
};

/****************************************************************************
 ** DO that can contain others
 ****************************************************************************/
class IContainer{
protected:
	vector<DisplayObject*> dos;
public:
	IContainer() {};
	virtual ~IContainer() {};

	virtual void containerAdd(DisplayObject *self, DisplayObject *dob);
	virtual bool containerRemove(DisplayObject *dob);
	virtual void containerClear();

	virtual void containerRender(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible);
	virtual void containerRenderZ(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible);
	virtual void containerSortZ(RendererGL *container, mat4 cur_model);
};
class DORContainer : public DORFlatSortable, public IContainer{
protected:
	virtual void cloneInto(DisplayObject *into);
public:
	DORContainer() {};
	virtual ~DORContainer();
	DO_STANDARD_CLONE_METHOD(DORContainer);
	virtual const char* getKind() { return "DORContainer"; };

	virtual void add(DisplayObject *dob);
	virtual void remove(DisplayObject *dob);
	virtual void clear();

	virtual void render(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible);
	virtual void renderZ(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible);
	virtual void sortZ(RendererGL *container, mat4 cur_model);
};


/****************************************************************************
 ** Interface to make a DisplayObject be a sub-renderer: breaking chaining
 ** and using it's own render method
 ****************************************************************************/
class SubRenderer : public DORContainer {
	friend class RendererGL;
protected:
	vec4 use_color;
	mat4 use_model;
	char *renderer_name = NULL;

	virtual void cloneInto(DisplayObject *into);
public:
	SubRenderer() { renderer_name = strdup(getKind()); stop_parent_recursing = true; };
	~SubRenderer() { free((void*)renderer_name); };
	const char* getRendererName() { return renderer_name ? renderer_name : "---unknown---"; };
	void setRendererName(const char *name);
	void setRendererName(char *name, bool copy);

	virtual void render(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible);
	virtual void renderZ(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible);
	virtual void sortZ(RendererGL *container, mat4 cur_model);

	virtual void toScreenSimple();
	virtual void toScreen(mat4 cur_model, vec4 color) = 0;
};


/****************************************************************************
 ** A Dummy DO taht displays nothing and instead calls a lua callback
 ****************************************************************************/
class DORCallback : public SubRenderer {
protected:
	int cb_ref = LUA_NOREF;
	bool enabled = true;

	virtual void cloneInto(DisplayObject *into);

public:
	DORCallback() { };
	virtual ~DORCallback() { if (cb_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, cb_ref); };
	DO_STANDARD_CLONE_METHOD(DORCallback);
	virtual const char* getKind() { return "DORCallback"; };

	void setCallback(int ref) {
		if (cb_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, cb_ref);
		cb_ref = ref;
	};
	void enable(bool v) { enabled = v; setChanged(); };

	virtual void toScreen(mat4 cur_model, vec4 color);
};

#endif
