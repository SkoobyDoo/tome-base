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

#define DEBUG_CHECKPARENTS

/*************************************************************************
 ** DisplayObject
 *************************************************************************/
void DisplayObject::removeFromParent() {
	if (!parent) return;
	DORContainer *p = dynamic_cast<DORContainer*>(parent);
	if (p) p->remove(this);
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
};

void DisplayObject::setChanged() {
	changed = true;
	DisplayObject *p = parent;
	while (p) {
#ifdef DEBUG_CHECKPARENTS
		if (p == this && L) {
			lua_pushstring(L, "setChanged recursing in loop");
			lua_error(L);
			return;
		}
#endif
		p->changed = true;
		if (p->stop_parent_recursing) break;
		p = p->parent;
	}
}

	// printf("%f, %f, %f, %f\n", model[0][0], model[0][1], model[0][2], model[0][3]);
	// printf("%f, %f, %f, %f\n", model[1][0], model[1][1], model[1][2], model[1][3]);
	// printf("%f, %f, %f, %f\n", model[2][0], model[2][1], model[2][2], model[2][3]);
	// printf("%f, %f, %f, %f\n", model[3][0], model[3][1], model[3][2], model[3][3]);

void DisplayObject::recomputeModelMatrix() {
	model = mat4();
	model = glm::translate(model, glm::vec3(x, y, z));
	model = glm::rotate(model, rot_x, glm::vec3(1, 0, 0));
	model = glm::rotate(model, rot_y, glm::vec3(0, 1, 0));
	model = glm::rotate(model, rot_z, glm::vec3(0, 0, 1));
	model = glm::scale(model, glm::vec3(scale_x, scale_y, scale_z));
	
	setChanged();
}

void DisplayObject::shown(bool v) {
	visible = v;
	setChanged();
}

void DisplayObject::setColor(float r, float g, float b, float a) {
	if (r != -1) color.r = r;
	if (g != -1) color.g = g;
	if (b != -1) color.b = b;
	if (a != -1) color.a = a;
	setChanged();
}

void DisplayObject::resetModelMatrix() {
	x = y = z = 0;
	rot_x = rot_y = rot_z = 0;
	scale_x = scale_y = scale_z = 1;
	recomputeModelMatrix();
}

void DisplayObject::translate(float x, float y, float z, bool increment) {
	if (increment) {
		this->x += x;
		this->y += y;
		this->z += z;
	} else {
		this->x = x;
		this->y = y;
		this->z = z;
	}
	recomputeModelMatrix();
}

void DisplayObject::rotate(float x, float y, float z, bool increment) {
	if (increment) {
		this->rot_x += x;
		this->rot_y += y;
		this->rot_z += z;
	} else {
		this->rot_x = x;
		this->rot_y = y;
		this->rot_z = z;
	}
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
	vertices.clear();
	setChanged();
}

void DORVertexes::cloneInto(DisplayObject *_into) {
	DisplayObject::cloneInto(_into);
	DORVertexes *into = dynamic_cast<DORVertexes*>(_into);
	into->vertices.insert(into->vertices.begin(), vertices.begin(), vertices.end());
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
		float r, float g, float b, float a
	) {
	return addQuad(
		x1, y1, 0, u1, v1,
		x2, y2, 0, u2, v2,
		x3, y3, 0, u3, v3,
		x4, y4, 0, u4, v4,
		r, g, b, a
	);
}

int DORVertexes::addQuad(
		float x1, float y1, float z1, float u1, float v1, 
		float x2, float y2, float z2, float u2, float v2, 
		float x3, float y3, float z3, float u3, float v3, 
		float x4, float y4, float z4, float u4, float v4, 
		float r, float g, float b, float a
	) {
	if (vertices.size() + 4 >= vertices.capacity()) {vertices.reserve(vertices.capacity() * 2);}

	vertices.push_back({{x1, y1, z1, 1}, {u1, v1}, {r, g, b, a}});
	vertices.push_back({{x2, y2, z2, 1}, {u2, v2}, {r, g, b, a}});
	vertices.push_back({{x3, y3, z3, 1}, {u3, v3}, {r, g, b, a}});
	vertices.push_back({{x4, y4, z4, 1}, {u4, v4}, {r, g, b, a}});

	setChanged();
	return 0;
}

int DORVertexes::addQuadPie(
		float x1, float y1, float x2, float y2,
		float u1, float v1, float u2, float v2,
		float angle,
		float r, float g, float b, float a
	) {
	if (angle < 0) angle = 0;
	else if (angle > 360) angle = 360;
	if (angle == 360) return 0;

	if (vertices.size() + 10 >= vertices.capacity()) {vertices.reserve(vertices.capacity() * 2);}

	float w = x2 - x1;
	float h = y2 - y1;
	float mw = w / 2, mh = h / 2;
	float xmid = x1 + mw, ymid = y1 + mh;

	float uw = u2 - u1;
	float vh = v2 - v1;
	float mu = uw / 2, mv = vh / 2;
	float umid = u1 + mu, vmid = v1 + mv;

	float scale = cos(M_PI / 4);

	int quadrant = angle / 45;
	float baseangle = (angle + 90) * M_PI / 180;
	// Now we project the circle coordinates on a bounding square thanks to scale
	float c = -cos(baseangle) / scale * mw;
	float s = -sin(baseangle) / scale * mh;
	float cu = -cos(baseangle) / scale * mu;
	float sv = -sin(baseangle) / scale * mv;

	if (quadrant >= 0 && quadrant < 2) {
		// Cover all the left
		vertices.push_back({{x1, y1, 0, 1}, {u1, v1}, {r, g, b, a}});
		vertices.push_back({{xmid, y1, 0, 1}, {umid, v1}, {r, g, b, a}});
		vertices.push_back({{xmid, y2, 0, 1}, {umid, v2}, {r, g, b, a}});
		vertices.push_back({{x1, y2, 0, 1}, {u1, v2}, {r, g, b, a}});
		// Cover bottom right
		vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
		vertices.push_back({{x2, ymid, 0, 1}, {u2, vmid}, {r, g, b, a}});
		vertices.push_back({{x2, y2, 0, 1}, {u2, v2}, {r, g, b, a}});
		vertices.push_back({{xmid, y2, 0, 1}, {umid, v2}, {r, g, b, a}});
		// Cover top right
		if (quadrant == 0) {
			vertices.push_back({{xmid + c, y1, 0, 1}, {umid +cu, v1}, {r, g, b, a}});
			vertices.push_back({{x2, y1, 0, 1}, {u2, v1}, {r, g, b, a}});
			vertices.push_back({{x2, ymid, 0, 1}, {u2, vmid}, {r, g, b, a}});
			vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
		} else {
			vertices.push_back({{x2, ymid + s, 0, 1}, {u2, vmid + sv}, {r, g, b, a}});
			vertices.push_back({{x2, ymid + s, 0, 1}, {u2, vmid + sv}, {r, g, b, a}});
			vertices.push_back({{x2, ymid, 0, 1}, {u2, vmid}, {r, g, b, a}});
			vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
		}
	}
	else if (quadrant >= 2 && quadrant < 4) {
		// Cover all the left
		vertices.push_back({{x1, y1, 0, 1}, {u1, v1}, {r, g, b, a}});
		vertices.push_back({{xmid, y1, 0, 1}, {umid, v1}, {r, g, b, a}});
		vertices.push_back({{xmid, y2, 0, 1}, {umid, v2}, {r, g, b, a}});
		vertices.push_back({{x1, y2, 0, 1}, {u1, v2}, {r, g, b, a}});
		// Cover bottom right
		if (quadrant == 2) {
			vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
			vertices.push_back({{x2, ymid + s, 0, 1}, {u2, vmid + sv}, {r, g, b, a}});
			vertices.push_back({{x2, y2, 0, 1}, {u2, v2}, {r, g, b, a}});
			vertices.push_back({{xmid, y2, 0, 1}, {umid, v2}, {r, g, b, a}});
		} else {
			vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
			vertices.push_back({{xmid + c, y2, 0, 1}, {umid + cu, v2}, {r, g, b, a}});
			vertices.push_back({{xmid + c, y2, 0, 1}, {umid + cu, v2}, {r, g, b, a}});
			vertices.push_back({{xmid, y2, 0, 1}, {umid, v2}, {r, g, b, a}});

		}
	}
	else if (quadrant >= 4 && quadrant < 6) {
		// Cover top left
		vertices.push_back({{x1, y1, 0, 1}, {u1, v1}, {r, g, b, a}});
		vertices.push_back({{xmid, y1, 0, 1}, {umid, v1}, {r, g, b, a}});
		vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
		vertices.push_back({{x1, ymid, 0, 1}, {u1, vmid}, {r, g, b, a}});
		// Cover bottom right
		if (quadrant == 4) {
			vertices.push_back({{x1, ymid, 0, 1}, {u1, vmid}, {r, g, b, a}});
			vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
			vertices.push_back({{xmid + c, y2, 0, 1}, {umid + cu, v2}, {r, g, b, a}});
			vertices.push_back({{x1, y2, 0, 1}, {u1, v2}, {r, g, b, a}});
		} else {
			vertices.push_back({{x1, ymid, 0, 1}, {u1, vmid}, {r, g, b, a}});
			vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
			vertices.push_back({{x1, ymid + s, 0, 1}, {u1, vmid + sv}, {r, g, b, a}});
			vertices.push_back({{x1, ymid + s, 0, 1}, {u1, vmid + sv}, {r, g, b, a}});
		}
	}
	else if (quadrant >= 6 && quadrant < 8) {
		// Cover top left
		if (quadrant == 6) {
			vertices.push_back({{x1, y1, 0, 1}, {u1, v1}, {r, g, b, a}});
			vertices.push_back({{xmid, y1, 0, 1}, {umid, v1}, {r, g, b, a}});
			vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
			vertices.push_back({{x1, ymid + s, 0, 1}, {u1, vmid + sv}, {r, g, b, a}});
		} else {
			vertices.push_back({{xmid + c, y1, 0, 1}, {umid + cu, v1}, {r, g, b, a}});
			vertices.push_back({{xmid, y1, 0, 1}, {umid, v1}, {r, g, b, a}});
			vertices.push_back({{xmid, ymid, 0, 1}, {umid, vmid}, {r, g, b, a}});
			vertices.push_back({{xmid + c, y1, 0, 1}, {umid + cu, v1}, {r, g, b, a}});
		}
	}

	setChanged();
	return 0;
}

void DORVertexes::render(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	if (!visible) return;
	cur_model *= model;
	cur_color *= color;
	auto dl = getDisplayList(container, tex, shader);

	// Make sure we do not have to reallocate each step
	int nb = vertices.size();
	int startat = dl->list.size();
	dl->list.reserve(startat + nb);

	// Copy & apply the model matrix
	// DGDGDGDG: is it better to first copy it all and then alter it ? most likely not, change me
	dl->list.insert(std::end(dl->list), std::begin(this->vertices), std::end(this->vertices));
	vertex *dest = dl->list.data();
	for (int di = startat; di < startat + nb; di++) {
		dest[di].pos = cur_model * dest[di].pos;
		dest[di].color = cur_color * dest[di].color;
	}

	resetChanged();
}

void DORVertexes::renderZ(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	if (!visible) return;
	cur_model *= model;
	cur_color *= color;

	// Make sure we do not have to reallocate each step
	int nb = vertices.size();
	int startat = container->zvertices.size();
	container->zvertices.resize(startat + nb);

	// Copy & apply the model matrix
	vertex *src = vertices.data();
	sortable_vertex *dest = container->zvertices.data();
	for (int di = startat, si = 0; di < startat + nb; di++, si++) {
		dest[di].sub = NULL;
		dest[di].tex = tex;
		dest[di].shader = shader;
		dest[di].v.tex = src[si].tex;
		dest[di].v.color = cur_color * src[si].color;
		dest[di].v.pos = cur_model * src[si].pos;
	}

	resetChanged();
}

/*************************************************************************
 ** IContainer
 *************************************************************************/
void IContainer::containerAdd(DisplayObject *self, DisplayObject *dob) {
	dos.push_back(dob);
	dob->setParent(self);
};

bool IContainer::containerRemove(DisplayObject *dob) {
	for (auto it = dos.begin() ; it != dos.end(); ++it) {
		if (*it == dob) {
			dos.erase(it);

			dob->setParent(NULL);
			if (L) {
				int ref = dob->unsetLuaRef();
				if (ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, ref);
			}
			return true;
		}
	}
	return false;
};

void IContainer::containerClear() {
	for (auto it = dos.begin() ; it != dos.end(); ++it) {
		// printf("IContainer clearing : %lx\n", (long int)*it);
		(*it)->setParent(NULL);
		if (L) {
			int ref = (*it)->unsetLuaRef();
			if (ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, ref);
		}
	}
	dos.clear();
}

void IContainer::containerRender(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	for (auto it = dos.begin() ; it != dos.end(); ++it) {
		DisplayObject *i = dynamic_cast<DisplayObject*>(*it);
		if (i) i->render(container, cur_model, cur_color);
	}
}

void IContainer::containerRenderZ(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	for (auto it = dos.begin() ; it != dos.end(); ++it) {
		DisplayObject *i = dynamic_cast<DisplayObject*>(*it);
		if (i) i->renderZ(container, cur_model, cur_color);
	}
}

/*************************************************************************
 ** DORContainer
 *************************************************************************/
void DORContainer::cloneInto(DisplayObject* _into) {
	DisplayObject::cloneInto(_into);
	DORContainer *into = dynamic_cast<DORContainer*>(_into);
	for (auto it = dos.begin() ; it != dos.end(); ++it) {
		into->add((*it)->clone());
	}	
}
void DORContainer::add(DisplayObject *dob) {
	containerAdd(this, dob);
	setChanged();
};

void DORContainer::remove(DisplayObject *dob) {
	if (containerRemove(dob)) setChanged();
};

void DORContainer::clear() {
	containerClear();
	setChanged();
}

DORContainer::~DORContainer() {
	clear();
}

void DORContainer::render(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	if (!visible) return;
	cur_model *= model;
	cur_color *= color;
	containerRender(container, cur_model, cur_color);
	resetChanged();
}

void DORContainer::renderZ(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	if (!visible) return;
	cur_model *= model;
	cur_color *= color;
	containerRenderZ(container, cur_model, cur_color);
	resetChanged();
}


/***************************************************************************
 ** SubRenderer
 ***************************************************************************/

void SubRenderer::cloneInto(DisplayObject* _into) {
	DORContainer::cloneInto(_into);
	SubRenderer *into = dynamic_cast<SubRenderer*>(_into);
	into->use_model = use_model;
	into->use_color = use_color;
	if (into->renderer_name) free((void*)into->renderer_name);
	into->renderer_name = strdup(renderer_name);
}

void SubRenderer::setRendererName(char *name, bool copy) {
	if (renderer_name) free((void*)renderer_name);
	if (copy) renderer_name = strdup(name);
	else renderer_name = name;
}
void SubRenderer::setRendererName(const char *name) {
	setRendererName((char*)name, true);
}

void SubRenderer::render(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	if (!visible) return;
	this->use_model = cur_model;
	this->use_color = cur_color;
	stopDisplayList(); // Needed to make sure we break texture chaining
	auto dl = getDisplayList(container);
	stopDisplayList(); // Needed to make sure we break texture chaining
	dl->sub = this;
	// resetChanged();
}

void SubRenderer::renderZ(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	if (!visible) return;
	this->use_model = cur_model;
	this->use_color = cur_color;
	int startat = container->zvertices.size();
	container->zvertices.resize(startat + 1);
	sortable_vertex *dest = container->zvertices.data();
	dest[startat].sub = this;
	// resetChanged();
}

void SubRenderer::toScreenSimple() {
	toScreen(mat4(), {1.0, 1.0, 1.0, 1.0});
}

/*************************************************************************
 ** DORTarget
 *************************************************************************/
DisplayObject* DORTarget::clone() {
	DORTarget *into = new DORTarget(w, h, nbt);
	this->cloneInto(into);
	return into;
}
void DORTarget::cloneInto(DisplayObject* _into) {
	DORVertexes::cloneInto(_into);
	DORTarget *into = dynamic_cast<DORTarget*>(_into);
	into->clear_r = clear_r;
	into->clear_g = clear_g;
	into->clear_b = clear_b;
	into->clear_a = clear_a;
}

DORTarget::DORTarget() : DORTarget(screen->w / screen_zoom, screen->h / screen_zoom, 1) {
}
DORTarget::DORTarget(int w, int h, int nbt) {
	this->nbt = nbt;
	this->w = w;
	this->h = h;

	view = new View(w, h);

	glGenFramebuffers(1, &fbo);
	tglBindFramebuffer(GL_FRAMEBUFFER, fbo);

	// Now setup a texture to render to
	int i;
	textures.resize(nbt);
	buffers.resize(nbt);
	glGenTextures(nbt, textures.data());
	for (i = 0; i < nbt; i++) {
		tfglBindTexture(GL_TEXTURE_2D, textures[i]);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8,  w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + i, GL_TEXTURE_2D, textures[i], 0);
		buffers[i] = GL_COLOR_ATTACHMENT0 + i;
	}

	tglBindFramebuffer(GL_FRAMEBUFFER, 0);

	// For display as a DO
	tex[0] = textures[0];
	// Default display quad, can be removed and altered if needed with clear & addQuad
	addQuad(
		0, 0, 0, 1,
		0, h, 0, 0,
		w, h, 1, 0,
		w, 0, 1, 1,
		1, 1, 1, 1
	);
}
DORTarget::~DORTarget() {
	delete view;

	if (subrender_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, subrender_lua_ref);

	tglBindFramebuffer(GL_FRAMEBUFFER, fbo);
	for (int i = 0; i < nbt; i++) glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + i, GL_TEXTURE_2D, 0, 0);
	tglBindFramebuffer(GL_FRAMEBUFFER, 0);

	glDeleteTextures(nbt, textures.data());
	glDeleteFramebuffers(1, &fbo);
}

void DORTarget::setTexture(GLuint tex, int lua_ref, int id) {
	if (id == 0) printf("Error, trying to set DORTarget texture 0.\n");
	else DORVertexes::setTexture(tex, lua_ref, id);
}

void DORTarget::displaySize(int w, int h, bool center) {
	clear();
	int x1 = 0, x2 = w;
	int y1 = 0, y2 = h;
	if (center) {
		w = w / 2;
		h = h / 2;
		x1 = -w; x2 = w;
		y1 = -h; y2 = h;
	}
	addQuad(
		x1, y1, 0, 1,
		x1, y2, 0, 0,
		x2, y2, 1, 0,
		x2, y1, 1, 1,
		1, 1, 1, 1
	);
}

void DORTarget::setClearColor(float r, float g, float b, float a) {
	clear_r = r;
	clear_g = g;
	clear_b = b;
	clear_a = a;
}

static stack<GLuint> fbo_stack;
void DORTarget::use(bool activate) {
	if (activate)
	{
		tglBindFramebuffer(GL_FRAMEBUFFER, fbo);
		if (nbt > 1) glDrawBuffers(nbt, buffers.data());

		tglClearColor(clear_r, clear_g, clear_b, clear_a);
		glClear(GL_COLOR_BUFFER_BIT);
		fbo_stack.push(fbo);
		view->use(true);
	}
	else
	{
		view->use(false);
		fbo_stack.pop();
		tglClearColor(0, 0, 0, 1);

		// Unbind texture from FBO and then unbind FBO
		if (!fbo_stack.empty()) {
			tglBindFramebuffer(GL_FRAMEBUFFER, fbo_stack.top());
		} else {
			tglBindFramebuffer(GL_FRAMEBUFFER, 0);
		}
	}
}

void DORTarget::setAutoRender(SubRenderer *o, int ref) {
	if (subrender_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, subrender_lua_ref);
	subrender_lua_ref = ref;
	subrender = o;
	setChanged();
}

void DORTarget::render(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	if (subrender) {
		stopDisplayList(); // Needed to make sure we break texture chaining
		auto dl = getDisplayList(container);
		dl->tick = this;
	}

	DORVertexes::render(container, cur_model, cur_color);
}

void DORTarget::renderZ(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	if (subrender) {
		int startat = container->zvertices.size();
		container->zvertices.resize(startat + 1);
		sortable_vertex *dest = container->zvertices.data();
		dest[startat].tick = this;
	}

	DORVertexes::renderZ(container, cur_model, cur_color);
}

void DORTarget::tick() {
	if (!subrender) return;
	use(true);
	subrender->toScreenSimple();
	use(false);
}

void DORTarget::onScreenResize(int w, int h) {

}

/***************************************************************************
 ** DORCallback class
 ***************************************************************************/
void DORCallback::cloneInto(DisplayObject* _into) {
	SubRenderer::cloneInto(_into);
	DORCallback *into = dynamic_cast<DORCallback*>(_into);
	if (L && cb_ref) {
		lua_rawgeti(L, LUA_REGISTRYINDEX, cb_ref);
		into->cb_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	}
}

void DORCallback::toScreen(mat4 cur_model, vec4 color) {
	lua_rawgeti(L, LUA_REGISTRYINDEX, cb_ref);
	if (lua_pcall(L, 0, 0, 0))
	{
		printf("DORCallback callback error: %s\n", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
}