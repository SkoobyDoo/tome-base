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
#include "lauxlib.h"
#include "display.h"
#include "types.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "main.h"
}
int donb = 0;
#include "renderer-moderngl/Renderer.hpp"
#include "renderer-moderngl/Physic.hpp"
#include "tinyobjloader/tiny_obj_loader.h"
#include <string>

// Lol or what ? Mingw64 on windows seems to not find it ..
#ifndef M_PI
#define M_PI                3.14159265358979323846
#endif

#define DEBUG_CHECKPARENTS

/*************************************************************************
 ** DisplayObject
 *************************************************************************/
int DisplayObject::weak_registry_ref = LUA_NOREF;
bool DisplayObject::pixel_perfect = true;

DisplayObject::DisplayObject() {
	changed.set();
	donb++;
	// printf("+DOs %d\n", donb);
	model = mat4(); color.r = 1; color.g = 1; color.b = 1; color.a = 1;
}
DisplayObject::~DisplayObject() {
	donb--;
	// printf("-DOs %d\n", donb);
	removeFromParent();
	if (lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, lua_ref);
	if (tweener) delete tweener;
	tweener = NULL;
	for (int pid = 0; pid < physics.size(); pid++) delete physics[pid];
	physics.clear();
}

void DisplayObject::removeFromParent() {
	if (!parent) return;
	DORContainer *p = dynamic_cast<DORContainer*>(parent);
	if (p) p->remove(this);
	parent = renderer = NULL;
}

void DisplayObject::setParent(DisplayObject *parent) {
#ifdef DEBUG_CHECKPARENTS
	if (parent && this->parent && L) {
		lua_pushstring(L, "Setting DO parent when already set");
		lua_error(L);
		return;
	}
#endif
	this->parent = parent;
	if (!parent) renderer = NULL;
};

void DisplayObject::setChanged(ChangedSet what) {
	switch (what) {
		case ChangedSet::PARENTS:
			if (!changed[ChangedSet::PARENTS] && renderer) {
				renderer->setChanged(ChangedSet::REBUILD);
				changed.set(ChangedSet::PARENTS);
			}
			break;
		case ChangedSet::CHILDS:
				// printf("!!!! %s : %d\n", getKind(), renderer?1:0);
			if (renderer) {
				renderer->update_dos.insert(this);
			}
				// changed.set(ChangedSet::CHILDS);
			break;
		case ChangedSet::RESORT:
			changed.set(ChangedSet::RESORT);
		case ChangedSet::REBUILD:
			changed.set(ChangedSet::REBUILD);
			break;
	}
}

void DisplayObject::setSortingChanged() {
	if (!renderer) return;
	// printf("=!!!!!!!!!!SORTING CHANGED\n");
	renderer->setChanged(ChangedSet::RESORT);
	renderer->setChanged(ChangedSet::REBUILD);
}

void DisplayObject::recomputeModelMatrix() {
	model = mat4();
	if (pixel_perfect) {
		model = glm::translate(model, glm::vec3(floor(x), floor(y), floor(z)));
	} else {
		model = glm::translate(model, glm::vec3(x, y, z));
	}
	model = glm::rotate(model, rot_x, glm::vec3(1, 0, 0));
	model = glm::rotate(model, rot_y, glm::vec3(0, 1, 0));
	model = glm::rotate(model, rot_z, glm::vec3(0, 0, 1));
	model = glm::scale(model, glm::vec3(scale_x, scale_y, scale_z));
}

recomputematrix DisplayObject::computeParentCompositeMatrix(DisplayObject *stop_at, recomputematrix cur) {
	if (!parent || this == stop_at) return cur;
	recomputematrix p = parent->computeParentCompositeMatrix(stop_at, cur);
	cur.model = p.model * model;
	cur.color = p.color * color;
	cur.visible = p.visible && visible;
	return cur;
}

int DisplayObject::enablePhysic() {
	physics.push_back(new DORPhysic(this));
}

DORPhysic *DisplayObject::getPhysic(int pid) {
	if (pid < 0 or pid > physics.size()) pid = 0;
	return physics[pid];
}

void DisplayObject::destroyPhysic(int pid) {
	if (pid == -1) {
		for (auto it : physics) delete it;
			physics.clear();
	} else {
		delete physics[pid];
		physics.erase(physics.begin() + pid);
	}
}

void DisplayObject::shown(bool v) {
	if (visible == v) return;
	visible = v;
	setChanged(ChangedSet::CHILDS);
}

void DisplayObject::setColor(float r, float g, float b, float a) {
	if (r != -1) color.r = r;
	if (g != -1) color.g = g;
	if (b != -1) color.b = b;
	if (a != -1) color.a = a;
	setChanged(ChangedSet::CHILDS);
}

void DisplayObject::resetModelMatrix() {
	if (z) setSortingChanged();
	x = y = z = 0;
	rot_x = rot_y = rot_z = 0;
	scale_x = scale_y = scale_z = 1;
	recomputeModelMatrix();
}

void DisplayObject::updateFull(mat4 cur_model, vec4 cur_color, bool cur_visible, bool cleanup) {
	// recomputeModelMatrix(); // DGDGDGDG Make matric recompiting happen only here
	computed_model = cur_model * model;
	computed_color = cur_color * color;
	computed_visible = cur_visible && visible;
}


DORTweener::DORTweener(DisplayObject *d) {
	who = d;
	for (short slot = 0; slot < TweenSlot::MAX; slot++) {
		auto &t = tweens[slot];
		t.time = 0;
		t.on_end_ref = LUA_NOREF;
		t.on_change_ref = LUA_NOREF;
	}
}
DORTweener::~DORTweener() {
	for (short slot = 0; slot < TweenSlot::MAX; slot++) {
		auto &t = tweens[slot];
		if (t.on_end_ref != LUA_NOREF) { luaL_unref(L, LUA_REGISTRYINDEX, t.on_end_ref); t.on_end_ref = LUA_NOREF; }
		if (t.on_change_ref != LUA_NOREF) { luaL_unref(L, LUA_REGISTRYINDEX, t.on_change_ref); t.on_change_ref = LUA_NOREF; }
	}
}

void DORTweener::onKeyframe(float nb_keyframes) {
	if (!nb_keyframes) return;

	bool mat = false, changed = false;
	int nb_tweening = 0;
	for (short slot = 0; slot < TweenSlot::MAX; slot++) {
		auto &t = tweens[slot];
		if (t.time) {
			nb_tweening++;
			t.cur += nb_keyframes / (float)NORMALIZED_FPS;
			if (t.cur > t.time) t.cur = t.time;
			float val = t.easing(t.from, t.to, t.cur / t.time);
			// printf("=== %f => %f over %f / %f == %f\n", t.from, t.to, t.cur, t.time, val);
			switch (slot) {
				case TweenSlot::TX:
					who->x = val; mat = true;
					break;
				case TweenSlot::TY:
					who->y = val; mat = true;
					break;
				case TweenSlot::TZ:
					who->z = val; mat = true;
					who->setSortingChanged();
					break;
				case TweenSlot::RX:
					who->rot_x = val; mat = true;
					break;
				case TweenSlot::RY:
					who->rot_y = val; mat = true;
					break;
				case TweenSlot::RZ:
					who->rot_z = val; mat = true;
					break;
				case TweenSlot::SX:
					who->scale_x = val; mat = true;
					break;
				case TweenSlot::SY:
					who->scale_y = val; mat = true;
					break;
				case TweenSlot::SZ:
					who->scale_z = val; mat = true;
					break;
				case TweenSlot::R:
					who->color.r = val; changed = true;
					break;
				case TweenSlot::G:
					who->color.g = val; changed = true;
					break;
				case TweenSlot::B:
					who->color.b = val; changed = true;
					break;
				case TweenSlot::A:
					who->color.a = val; changed = true;
					break;
			}

			if (t.on_change_ref != LUA_NOREF) {
				lua_rawgeti(L, LUA_REGISTRYINDEX, DisplayObject::weak_registry_ref);
				lua_rawgeti(L, LUA_REGISTRYINDEX, t.on_change_ref);
				lua_rawgeti(L, -2, who->weak_self_ref);
				lua_pushnumber(L, val);
				lua_call(L, 2, 0);
				lua_pop(L, 1); // the weak registry
			}

			if (t.cur >= t.time) {
				t.time = 0;
				if (t.on_end_ref != LUA_NOREF) {
					lua_rawgeti(L, LUA_REGISTRYINDEX, DisplayObject::weak_registry_ref);
					lua_rawgeti(L, LUA_REGISTRYINDEX, t.on_end_ref);
					lua_rawgeti(L, -2, who->weak_self_ref);
					lua_call(L, 1, 0);
					lua_pop(L, 1); // the weak registry
				}
				// Check time == 0, if it is not it means the on_end callback reassigned the slot, we dont want to touch it then, it's not "us" anymore
				if (!t.time) {
					if (t.on_end_ref != LUA_NOREF) { luaL_unref(L, LUA_REGISTRYINDEX, t.on_end_ref); t.on_end_ref = LUA_NOREF; }
					if (t.on_change_ref != LUA_NOREF) { luaL_unref(L, LUA_REGISTRYINDEX, t.on_change_ref); t.on_change_ref = LUA_NOREF; }
				}
			}
		}
	}
	if (mat) who->recomputeModelMatrix();
	if (changed || mat) who->setChanged(ChangedSet::CHILDS);
	if (!nb_tweening) {
		killMe();
		return; // Just safety in case something is added later. "delete this" must always be the last thing done
	}
}

float DisplayObject::getDefaultTweenSlotValue(TweenSlot slot) {
	switch (slot) {
		case TweenSlot::TX: return x;
		case TweenSlot::TY: return y;
		case TweenSlot::TZ: return z;
		case TweenSlot::RX: return rot_x;
		case TweenSlot::RY: return rot_y;
		case TweenSlot::RZ: return rot_z;
		case TweenSlot::SX: return scale_x;
		case TweenSlot::SY: return scale_y;
		case TweenSlot::SZ: return scale_z;
		case TweenSlot::R: return color.r;
		case TweenSlot::G: return color.g;
		case TweenSlot::B: return color.b;
		case TweenSlot::A: return color.a;
	}
}

void DORTweener::setTween(TweenSlot slot, easing_ptr easing, float from, float to, float time, int on_end_ref, int on_change_ref) {
	auto &t = tweens[(short)slot];
	t.easing = easing;
	t.from = from;
	t.to = to;
	t.cur = 0;
	t.time = time / (float)NORMALIZED_FPS;
	t.on_end_ref = on_end_ref;
	t.on_change_ref = on_change_ref;
}

void DORTweener::cancelTween(TweenSlot slot) {
	if (slot == TweenSlot::MAX) {
		killMe();
		return; // Just safety in case something is added later. "delete this" must always be the last thing done		
	} else {
		auto &t = tweens[(short)slot];
		t.time = 0;
		if (t.on_end_ref != LUA_NOREF) { luaL_unref(L, LUA_REGISTRYINDEX, t.on_end_ref); t.on_end_ref = LUA_NOREF; }
		if (t.on_change_ref != LUA_NOREF) { luaL_unref(L, LUA_REGISTRYINDEX, t.on_change_ref); t.on_change_ref = LUA_NOREF; }
	}
}

void DORTweener::killMe() {
	who->tweener = NULL;
	IRealtime::killMe();
}

void DisplayObject::tween(TweenSlot slot, easing_ptr easing, float from, float to, float time, int on_end_ref, int on_change_ref) {
	// if (to == getDefaultTweenSlotValue(slot)) return; // If we want to go to a value we already have, no need to botehr at all
	if (!tweener) tweener = new DORTweener(this);
	tweener->setTween(slot, easing, from, to, time, on_end_ref, on_change_ref);
}

void DisplayObject::cancelTween(TweenSlot slot) {
	if (!tweener) return;
	tweener->cancelTween(slot);
}


void DisplayObject::translate(float x, float y, float z, bool increment) {
	if (physics.size()) {
		if (!increment) {
			this->z = z;
			for (auto physic : physics) physic->setPos(x, y);
			if (z != this->z) setSortingChanged();
			setChanged(ChangedSet::CHILDS);
			recomputeModelMatrix();
			return;
		} else {
			increment = false;
		}
	}

	if (increment) {
		this->x += x;
		this->y += y;
		this->z += z;
		if (z) setSortingChanged();
	} else {
		if (z != this->z) setSortingChanged();
		this->x = x;
		this->y = y;
		this->z = z;
	}
	setChanged(ChangedSet::CHILDS);
	recomputeModelMatrix();
}

void DisplayObject::rotate(float x, float y, float z, bool increment) {
	if (physics.size()) {
		if (!increment) {
			this->rot_x = x;
			this->rot_y = y;
			for (auto physic : physics) physic->setAngle(z);
			setChanged(ChangedSet::CHILDS);
			recomputeModelMatrix();
			return;
		} else {
			increment = false;
		}
	}

	if (increment) {
		this->rot_x += x;
		this->rot_y += y;
		this->rot_z += z;
	} else {
		this->rot_x = x;
		this->rot_y = y;
		this->rot_z = z;
	}
	setChanged(ChangedSet::CHILDS);
	recomputeModelMatrix();
}

void DisplayObject::scale(float x, float y, float z, bool increment) {
	if (increment) {
		this->scale_x += x;
		this->scale_y += y;
		this->scale_z += z;
	} else {
		this->scale_x = x;
		this->scale_y = y;
		this->scale_z = z;
	}
	recomputeModelMatrix();
	setChanged(ChangedSet::CHILDS);
}

void DisplayObject::cloneInto(DisplayObject *into) {
	// into->L = L;

	// No parent
	into->parent = NULL;

	// Clone reference
	if (L && lua_ref) {
		lua_rawgeti(L, LUA_REGISTRYINDEX, lua_ref);
		into->lua_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	}

	into->model = model;
	into->color = color;
	into->visible = visible;
	into->x = x;
	into->y = y;
	into->z = z;
	into->rot_x = rot_x;
	into->rot_y = rot_y;
	into->rot_z = rot_z;
	into->scale_x = scale_x;
	into->scale_y = scale_y;
	into->scale_z = scale_z;

	into->changed = true;
}

/*************************************************************************
 ** DORVertexes
 *************************************************************************/
DORVertexes::~DORVertexes() {
	for (int i = 0; i < DO_MAX_TEX; i++) {
		if (tex_lua_ref[i] != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, tex_lua_ref[i]);
	}
};

void DORVertexes::setTexture(GLuint tex, int lua_ref, int id) {
	if (id >= DO_MAX_TEX) id = DO_MAX_TEX - 1;
	if (tex_lua_ref[id] != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, tex_lua_ref[id]);
	this->tex[id] = tex;
	tex_lua_ref[id] = lua_ref;

	for (int i = 0; i < DO_MAX_TEX; i++) {
		if (this->tex[i]) tex_max = i + 1;
	}
}

void DORVertexes::clear() {
	faces.clear();
	computed_vertices.clear();
	setChanged(ChangedSet::PARENTS);
}

void DORVertexes::cloneInto(DisplayObject *_into) {
	DisplayObject::cloneInto(_into);
	DORVertexes *into = dynamic_cast<DORVertexes*>(_into);
	into->faces.insert(into->faces.begin(), faces.begin(), faces.end());
	into->tex_max = tex_max;
	into->tex = tex;
	into->shader = shader;
	// Clone reference
	for (int i = 0; i < DO_MAX_TEX; i++) {
		if (L && tex_lua_ref[i] != LUA_NOREF) {
			lua_rawgeti(L, LUA_REGISTRYINDEX, tex_lua_ref[i]);
			into->tex_lua_ref[i] = luaL_ref(L, LUA_REGISTRYINDEX);
		}
	}
}

int DORVertexes::addQuad(
		float x1, float y1, float u1, float v1, 
		float x2, float y2, float u2, float v2, 
		float x3, float y3, float u3, float v3, 
		float x4, float y4, float u4, float v4, 
		float z,
		float r, float g, float b, float a
	) {
	int size = faces.size();
	if (size >= faces.capacity()) {faces.reserve(faces.capacity() * 2); computed_vertices.reserve(computed_vertices.capacity() * 2);}

	// This really shouldnt happend from the lua side as we dont even expose the addQuad version with z positions
	if ((size && (z != zflat))) {
		printf("Warning making non flat DORVertexes::addQuad!\n");
		is_zflat = false;
	}
	if (!size) zflat = z;

	faces.push_back({
		{r, g, b, a},		
		{ {x1, y1}, {x2, y2}, {x3, y3}, {x4, y4} },
		z,
	});
	computed_vertices.push_back({{0,0,0,0}, {u1, v1}});
	computed_vertices.push_back({{0,0,0,0}, {u2, v2}});
	computed_vertices.push_back({{0,0,0,0}, {u3, v3}});
	computed_vertices.push_back({{0,0,0,0}, {u4, v4}});

	setChanged(ChangedSet::PARENTS);
	return 0;
}

int DORVertexes::addQuad(vertex v1, vertex v2, vertex v3, vertex v4) {
	int size = faces.size();
	if (size >= faces.capacity()) {faces.reserve(faces.capacity() * 2); computed_vertices.reserve(computed_vertices.capacity() * 2);}

	if ((v1.pos.z != v2.pos.z) || (v1.pos.z != v3.pos.z) || (v1.pos.z != v4.pos.z) || (v3.pos.z != v4.pos.z)) {
		printf("ERROR: DORVertexes:addQuad(vertex list): tried to add vertexes of different z.\n");
		exit(2);
	}
	// This really shouldnt happend from the lua side as we dont even expose the addQuad version with z positions
	if ((size && (v1.pos.z != zflat))) {
		printf("Warning making non flat DORVertexes::addQuad(vertex list)!\n");
		is_zflat = false;
	}
	if (!size) zflat = v1.pos.z;

	faces.push_back({
		v1.color,
		{ {v1.pos.x, v1.pos.y}, {v2.pos.x, v2.pos.y}, {v3.pos.x, v3.pos.y}, {v4.pos.x, v4.pos.y} },
		v1.pos.z,
	});
	computed_vertices.push_back(v1);
	computed_vertices.push_back(v2);
	computed_vertices.push_back(v3);
	computed_vertices.push_back(v4);

	setChanged(ChangedSet::PARENTS);
	return 0;
}

int DORVertexes::addQuadPie(
		float x1, float y1, float x2, float y2,
		float u1, float v1, float u2, float v2,
		float angle,
		float r, float g, float b, float a
	) {
	// DGDGDGDG reimplement me
	// if (angle < 0) angle = 0;
	// else if (angle > 360) angle = 360;
	// if (angle == 360) return 0;

	// int size = vertices.size();
	// if (size + 10 >= vertices.capacity()) {vertices.reserve(vertices.capacity() * 2);}

	// if ((size && (0 != zflat))) {
	// 	printf("Warning making non flat DORVertexes::addQuadPie!\n");
	// 	is_zflat = false;
	// }
	// if (!size) zflat = 0;


	// float w = x2 - x1;
	// float h = y2 - y1;
	// float mw = w / 2, mh = h / 2;
	// float xmid = x1 + mw, ymid = y1 + mh;

	// float uw = u2 - u1;
	// float vh = v2 - v1;
	// float mu = uw / 2, mv = vh / 2;
	// float umid = u1 + mu, vmid = v1 + mv;

	// float scale = cos(M_PI / 4);

	// int quadrant = angle / 45;
	// float baseangle = (angle + 90) * M_PI / 180;
	// // Now we project the circle coordinates on a bounding square thanks to scale
	// float c = -cos(baseangle) / scale * mw;
	// float s = -sin(baseangle) / scale * mh;
	// float cu = -cos(baseangle) / scale * mu;
	// float sv = -sin(baseangle) / scale * mv;

	// if (quadrant >= 0 && quadrant < 2) {
	// 	// Cover all the left
	// 	vertices.push_back({{x1, y1, 0, 1}, {u1, v1}, {r, g, b, a}});
	// 	vertices.push_back({{xmid, y1, 0, 1}, {umid, v1}, {r, g, b, a}});
	// 	vertices.push_back({{xmid, y2, 0, 1}, {umid, v2}, {r, g, b, a}});
	// 	vertices.push_back({{x1, y2, 0, 1}, {u1, v2}, {r, g, b, a}});
	// 	// Cover bottom right
	// 	vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
	// 	vertices.push_back({{x2, ymid, 0, 1}, {u2, vmid}, {r, g, b, a}});
	// 	vertices.push_back({{x2, y2, 0, 1}, {u2, v2}, {r, g, b, a}});
	// 	vertices.push_back({{xmid, y2, 0, 1}, {umid, v2}, {r, g, b, a}});
	// 	// Cover top right
	// 	if (quadrant == 0) {
	// 		vertices.push_back({{xmid + c, y1, 0, 1}, {umid +cu, v1}, {r, g, b, a}});
	// 		vertices.push_back({{x2, y1, 0, 1}, {u2, v1}, {r, g, b, a}});
	// 		vertices.push_back({{x2, ymid, 0, 1}, {u2, vmid}, {r, g, b, a}});
	// 		vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
	// 	} else {
	// 		vertices.push_back({{x2, ymid + s, 0, 1}, {u2, vmid + sv}, {r, g, b, a}});
	// 		vertices.push_back({{x2, ymid + s, 0, 1}, {u2, vmid + sv}, {r, g, b, a}});
	// 		vertices.push_back({{x2, ymid, 0, 1}, {u2, vmid}, {r, g, b, a}});
	// 		vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
	// 	}
	// }
	// else if (quadrant >= 2 && quadrant < 4) {
	// 	// Cover all the left
	// 	vertices.push_back({{x1, y1, 0, 1}, {u1, v1}, {r, g, b, a}});
	// 	vertices.push_back({{xmid, y1, 0, 1}, {umid, v1}, {r, g, b, a}});
	// 	vertices.push_back({{xmid, y2, 0, 1}, {umid, v2}, {r, g, b, a}});
	// 	vertices.push_back({{x1, y2, 0, 1}, {u1, v2}, {r, g, b, a}});
	// 	// Cover bottom right
	// 	if (quadrant == 2) {
	// 		vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
	// 		vertices.push_back({{x2, ymid + s, 0, 1}, {u2, vmid + sv}, {r, g, b, a}});
	// 		vertices.push_back({{x2, y2, 0, 1}, {u2, v2}, {r, g, b, a}});
	// 		vertices.push_back({{xmid, y2, 0, 1}, {umid, v2}, {r, g, b, a}});
	// 	} else {
	// 		vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
	// 		vertices.push_back({{xmid + c, y2, 0, 1}, {umid + cu, v2}, {r, g, b, a}});
	// 		vertices.push_back({{xmid + c, y2, 0, 1}, {umid + cu, v2}, {r, g, b, a}});
	// 		vertices.push_back({{xmid, y2, 0, 1}, {umid, v2}, {r, g, b, a}});

	// 	}
	// }
	// else if (quadrant >= 4 && quadrant < 6) {
	// 	// Cover top left
	// 	vertices.push_back({{x1, y1, 0, 1}, {u1, v1}, {r, g, b, a}});
	// 	vertices.push_back({{xmid, y1, 0, 1}, {umid, v1}, {r, g, b, a}});
	// 	vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
	// 	vertices.push_back({{x1, ymid, 0, 1}, {u1, vmid}, {r, g, b, a}});
	// 	// Cover bottom right
	// 	if (quadrant == 4) {
	// 		vertices.push_back({{x1, ymid, 0, 1}, {u1, vmid}, {r, g, b, a}});
	// 		vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
	// 		vertices.push_back({{xmid + c, y2, 0, 1}, {umid + cu, v2}, {r, g, b, a}});
	// 		vertices.push_back({{x1, y2, 0, 1}, {u1, v2}, {r, g, b, a}});
	// 	} else {
	// 		vertices.push_back({{x1, ymid, 0, 1}, {u1, vmid}, {r, g, b, a}});
	// 		vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
	// 		vertices.push_back({{x1, ymid + s, 0, 1}, {u1, vmid + sv}, {r, g, b, a}});
	// 		vertices.push_back({{x1, ymid + s, 0, 1}, {u1, vmid + sv}, {r, g, b, a}});
	// 	}
	// }
	// else if (quadrant >= 6 && quadrant < 8) {
	// 	// Cover top left
	// 	if (quadrant == 6) {
	// 		vertices.push_back({{x1, y1, 0, 1}, {u1, v1}, {r, g, b, a}});
	// 		vertices.push_back({{xmid, y1, 0, 1}, {umid, v1}, {r, g, b, a}});
	// 		vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
	// 		vertices.push_back({{x1, ymid + s, 0, 1}, {u1, vmid + sv}, {r, g, b, a}});
	// 	} else {
	// 		vertices.push_back({{xmid + c, y1, 0, 1}, {umid + cu, v1}, {r, g, b, a}});
	// 		vertices.push_back({{xmid, y1, 0, 1}, {umid, v1}, {r, g, b, a}});
	// 		vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
	// 		vertices.push_back({{xmid + c, y1, 0, 1}, {umid + cu, v1}, {r, g, b, a}});
	// 	}
	// }

	// setChanged(ChangedSet::PARENTS);
	// return 0;
}

void DORVertexes::computeFaces() {
	int_fast32_t idx = 0;
	for (auto &f : faces) {
		for (int_fast8_t fi = 0; fi < 4; fi++) {
			vec4 p{ f.points[fi].x, f.points[fi].y, f.z, 1 };
			computed_vertices[idx].pos = computed_model * p;
			// if (!computed_visible) {
			// 	computed_vertices[idx].color.a = 0;
			// } else {
				computed_vertices[idx].color = computed_color * f.color;
			// }
			idx++;
		}
	}
	// printf("recomputed faces on %lx : %d\n", this, idx);
	if (dl_dest) {
		// printf("Reuse of DL %d at %ld in computeFaces\n", dl_dest->vbo, dl_dest_start);
		std::copy(computed_vertices.begin(), computed_vertices.end(), dl_dest->list.begin() + dl_dest_start);
		dl_dest->changed = true;
	}
}

void DORVertexes::updateFull(mat4 cur_model, vec4 cur_color, bool cur_visible, bool cleanup) {
	if (cleanup) dl_dest = NULL;
	DisplayObject::updateFull(cur_model, cur_color, cur_visible, cleanup);
	computeFaces();
}

void DORVertexes::render(RendererGL *container, mat4 cur_model, vec4 cur_color, bool cur_visible) {
	// if (!computed_visible) return;
	auto dl = getDisplayList(container, tex, shader);

	// Make sure we do not have to reallocate each step
	int nb = computed_vertices.size();
	int startat = dl->list.size();
	dl->list.reserve(startat + nb);

	// Copy
	dl->list.insert(dl->list.end(), computed_vertices.begin(), computed_vertices.end());
	dl->changed = true;
	dl_dest = dl;
	dl_dest_start = startat;
	// printf("Full rebuild of DL %d with tex %d\n", dl_dest->vbo, tex[0]);

	resetChanged();
}

void DORVertexes::renderZ(RendererGL *container, mat4 cur_model, vec4 cur_color, bool cur_visible) {
	if (!computed_visible) return;
	// cur_model *= model;
	// cur_color *= color;

	// // Make sure we do not have to reallocate each step
	// int nb = vertices.size();
	// int startat = container->zvertices.size();
	// container->zvertices.resize(startat + nb);

	// // Copy & apply the model matrix
	// vertex *src = vertices.data();
	// sortable_vertex *dest = container->zvertices.data();
	// for (int di = startat, si = 0; di < startat + nb; di++, si++) {
	// 	dest[di].sub = NULL;
	// 	dest[di].tex = tex;
	// 	dest[di].shader = shader;
	// 	dest[di].v.tex = src[si].tex;
	// 	dest[di].v.color = cur_color * src[si].color;
	// 	dest[di].v.pos = cur_model * src[si].pos;
	// }

	// resetChanged();
}

void DORVertexes::sortZ(RendererGL *container, mat4 cur_model) {
	if (!is_zflat) {
		printf("[DORVertexes::sortZ] ERROR! trying to sort a non zflat vertices list!\n");
		return;
	}

	// We take a "virtual" point at zflat coordinates
	vec4 virtualz = computed_model * vec4(0, 0, zflat, 1);
	sort_z = virtualz.z;
	sort_shader = shader;
	sort_tex = tex;
	container->sorted_dos.push_back(this);
}

/*************************************************************************
 ** DORContainer
 *************************************************************************/
void DORContainer::cloneInto(DisplayObject* _into) {
	DisplayObject::cloneInto(_into);
	DORContainer *into = dynamic_cast<DORContainer*>(_into);
	for (auto it : dos) {
		into->add(it->clone());
	}	
}
void DORContainer::add(DisplayObject *dob) {
	dos.push_back(dob);
	dob->setParent(this);
	setChanged(ChangedSet::PARENTS);
	setSortingChanged();
};

void DORContainer::remove(DisplayObject *dob) {
	for (auto it = dos.begin() ; it != dos.end(); ++it) {
		if (*it == dob) {
			dos.erase(it);

			function<void(DisplayObject*)> fct = [this](DisplayObject *o) { o->renderer = NULL; };
			dob->traverse(fct);
			dob->setParent(NULL);
			if (L) {
				int ref = dob->unsetLuaRef();
				if (ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, ref);
			}
			setChanged(ChangedSet::PARENTS);
			setSortingChanged();
			return;
		}
	}
};

void DORContainer::clear() {
	function<void(DisplayObject*)> fct = [this](DisplayObject *o) { o->renderer = NULL; };
	traverse(fct);

	for (auto it : dos) {
		// printf("IContainer clearing : %lx\n", (long int)*it);
		it->setParent(NULL);
		if (L) {
			int ref = it->unsetLuaRef();
			if (ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, ref);
		}
	}
	dos.clear();
	setChanged(ChangedSet::PARENTS);
	setSortingChanged();
}

void DORContainer::setParent(DisplayObject *parent) {
	if (!parent){
		function<void(DisplayObject*)> fct = [this](DisplayObject *o) { o->renderer = NULL; };
		traverse(fct);
	}
	DisplayObject::setParent(parent);
}

void DORContainer::removeFromParent() {
	function<void(DisplayObject*)> fct = [this](DisplayObject *o) { o->renderer = NULL; };
	traverse(fct);
	DisplayObject::removeFromParent();
}

void DORContainer::setChanged(ChangedSet what) {
	if (what == ChangedSet::CHILDS) {
		for (auto it : dos) {
			it->setChanged(what);
		}		
	}
	DisplayObject::setChanged(what);
}

DORContainer::~DORContainer() {
	clear();
}

void DORContainer::traverse(function<void(DisplayObject*)> &traverser) {
	traverser(this);
	for (auto it : dos) {
		it->traverse(traverser);
	}
}

void DORContainer::updateFull(mat4 cur_model, vec4 cur_color, bool cur_visible, bool cleanup) {
	DisplayObject::updateFull(cur_model, color, cur_visible, cleanup);
	for (auto it : dos) {
		it->updateFull(computed_model, computed_color, computed_visible, cleanup);
	}
}

void DORContainer::render(RendererGL *container, mat4 cur_model, vec4 cur_color, bool cur_visible) {
	for (auto it : dos) {
		it->render(container, cur_model, cur_color, cur_visible);
	}
	resetChanged();
}

void DORContainer::renderZ(RendererGL *container, mat4 cur_model, vec4 cur_color, bool cur_visible) {
	cur_model *= model;
	cur_color *= color;
	for (auto it : dos) {
		it->renderZ(container, cur_model, cur_color, cur_visible);
	}
	resetChanged();
}

void DORContainer::sortZ(RendererGL *container, mat4 cur_model) {
	// if (!visible) return; // DGDGDGDG: If you want :shown() to not trigger a Z rebuild we need to remove that. But to do that visible needs to be able to propagate like model & color; it does not currently
	for (auto it : dos) {
		it->sortZ(container, cur_model);
	}
}


/***************************************************************************
 ** ISubRenderer
 ***************************************************************************/

void ISubRenderer::cloneInto(DisplayObject* _into) {
	DORContainer::cloneInto(_into);
	ISubRenderer *into = dynamic_cast<ISubRenderer*>(_into);
	into->use_model = use_model;
	into->use_color = use_color;
	if (into->renderer_name) free((void*)into->renderer_name);
	into->renderer_name = strdup(renderer_name);
}

void ISubRenderer::setRendererName(char *name, bool copy) {
	if (renderer_name) free((void*)renderer_name);
	if (copy) renderer_name = strdup(name);
	else renderer_name = name;
}
void ISubRenderer::setRendererName(const char *name) {
	setRendererName((char*)name, true);
}

void ISubRenderer::render(RendererGL *container, mat4 cur_model, vec4 cur_color, bool cur_visible) {
	if (!computed_visible) return;
	stopDisplayList(); // Needed to make sure we break texture chaining
	auto dl = getDisplayList(container);
	stopDisplayList(); // Needed to make sure we break texture chaining
	dl->sub = this;
	// resetChanged(); // DGDGDGDG: investigate why things break if this is on
}

void ISubRenderer::renderZ(RendererGL *container, mat4 cur_model, vec4 cur_color, bool cur_visible) {
	if (!computed_visible) return;
	this->use_model = cur_model;
	this->use_color = cur_color;
	int startat = container->zvertices.size();
	container->zvertices.resize(startat + 1);
	sortable_vertex *dest = container->zvertices.data();
	dest[startat].sub = this;
	// resetChanged(); // DGDGDGDG: investigate why things break if this is on
}

void ISubRenderer::sortZ(RendererGL *container, mat4 cur_model) {
	// We take a "virtual" point at zflat coordinates
	vec4 virtualz = computed_model * vec4(0, 0, 0, 1);
	sort_z = virtualz.z;
	sort_shader = NULL;
	sort_tex = {0, 0, 0};
	container->sorted_dos.push_back(this);
}

void ISubRenderer::toScreenSimple() {
	toScreen(mat4(), {1.0, 1.0, 1.0, 1.0});
}

/***************************************************************************
 ** StaticSubRenderer class
 ***************************************************************************/
void StaticSubRenderer::cloneInto(DisplayObject* _into) {
	ISubRenderer::cloneInto(_into);
	StaticSubRenderer *into = dynamic_cast<StaticSubRenderer*>(_into);
	into->cb = cb;
}

void StaticSubRenderer::toScreen(mat4 cur_model, vec4 color) {
	if (cb) cb(cur_model, color);
}

/***************************************************************************
 ** DORCallback class
 ***************************************************************************/
void DORCallback::cloneInto(DisplayObject* _into) {
	ISubRenderer::cloneInto(_into);
	DORCallback *into = dynamic_cast<DORCallback*>(_into);
	if (L && cb_ref) {
		lua_rawgeti(L, LUA_REGISTRYINDEX, cb_ref);
		into->cb_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	}
}

void DORCallback::onKeyframe(float nb_keyframes) {
	keyframes += nb_keyframes;
}

void DORCallback::toScreen(mat4 cur_model, vec4 color) {
	lua_rawgeti(L, LUA_REGISTRYINDEX, cb_ref);
	lua_pushnumber(L, keyframes);
	if (lua_pcall(L, 1, 0, 0))
	{
		printf("DORCallback callback error: %s\n", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
	keyframes = 0;
}
