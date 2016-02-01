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

#include "renderer-moderngl/Renderer.hpp"

void DisplayObject::setChanged() {
	changed = true;
	DisplayObject *p = parent;
	while (p) {
		p->changed = true;
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
	color.r = r;
	color.g = g;
	color.b = b;
	color.a = a;
	setChanged();
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

void DORVertexes::clear() {
	vertices.clear();
	setChanged();
}

int DORVertexes::addQuad(
		float x1, float y1, float u1, float v1, 
		float x2, float y2, float u2, float v2, 
		float x3, float y3, float u3, float v3, 
		float x4, float y4, float u4, float v4, 
		float r, float g, float b, float a
	) {
	if (vertices.size() + 4 < vertices.capacity()) vertices.reserve(vertices.size() * 2);

	vertex ve1 = {{x1, y1, 0, 1}, {u1, v1}, {r, g, b, a}};
	vertex ve2 = {{x2, y2, 0, 1}, {u2, v2}, {r, g, b, a}};
	vertex ve3 = {{x3, y3, 0, 1}, {u3, v3}, {r, g, b, a}};
	vertex ve4 = {{x4, y4, 0, 1}, {u4, v4}, {r, g, b, a}};
	vertices.push_back(ve1);
	vertices.push_back(ve2);
	vertices.push_back(ve3);
	vertices.push_back(ve4);

	setChanged();
	return 0;
}

void DORContainer::add(DisplayObject *dob) {
	dos.push_back(dob);
	dob->setParent(this);
	setChanged();
};

void DORContainer::remove(DisplayObject *dob) {
	for (auto it = dos.begin() ; it != dos.end(); ++it) {
		if (*it == dob) {
			setChanged();

			dos.erase(it);

			dob->setParent(NULL);
			if (L) {
				int ref = dob->unsetLuaRef();
				if (ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, ref);
			}
			return;
		}
	}
};

void DORContainer::clear() {
	for (auto it = dos.begin() ; it != dos.end(); ++it) {
		(*it)->setParent(NULL);
		if (L) {
			int ref = (*it)->unsetLuaRef();
			if (ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, ref);
		}
	}
	dos.clear();
	setChanged();
}

DORTarget::DORTarget() : DORTarget(screen->w / screen_zoom, screen->h / screen_zoom, 1) {
}
DORTarget::DORTarget(int w, int h, int nbt) {
	this->nbt = nbt;
	this->w = w;
	this->h = h;

	glGenFramebuffers(1, &fbo);
	glBindFramebuffer(GL_FRAMEBUFFER, fbo);

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

	glBindFramebuffer(GL_FRAMEBUFFER, 0);

	// For display as a DO
	tex = textures[0];
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
	glBindFramebuffer(GL_FRAMEBUFFER, fbo);
	for (int i = 0; i < nbt; i++) glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + i, GL_TEXTURE_2D, 0, 0);
	glBindFramebuffer(GL_FRAMEBUFFER, 0);

	glDeleteTextures(nbt, textures.data());
	glDeleteFramebuffers(1, &fbo);
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
		glBindFramebuffer(GL_FRAMEBUFFER, fbo);
		if (nbt > 1) glDrawBuffers(nbt, buffers.data());

		tglClearColor(clear_r, clear_g, clear_b, clear_a);
		glClear(GL_COLOR_BUFFER_BIT);
		fbo_stack.push(fbo);
	}
	else
	{
		fbo_stack.pop();
		tglClearColor(0, 0, 0, 1);

		// Unbind texture from FBO and then unbind FBO
		if (!fbo_stack.empty()) {
			glBindFramebuffer(GL_FRAMEBUFFER, fbo_stack.top());
		} else {
			glBindFramebuffer(GL_FRAMEBUFFER, 0);
		}
	}
}
