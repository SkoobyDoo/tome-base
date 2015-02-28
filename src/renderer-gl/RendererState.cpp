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
#include "display.h"
#include "types.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "renderer.h"
}

#include "renderer-gl.hpp"

RendererState::RendererState(int w, int h) {
	/* Set the background black */
	tglClearColor( 0.0f, 0.0f, 0.0f, 1.0f );

	/* Depth buffer setup */
	glClearDepth( 1.0f );

	/* The Type Of Depth Test To Do */
	glDepthFunc(GL_LEQUAL);

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	if (use_modern_gl) {
		setViewport(0, 0, w, h);
		view = glm::ortho(0.f, (float)w, (float)h, 0.f, -1001.f, 1001.f);
		world = glm::mat4();
	} else {
#ifndef NO_OLD_GL
		setViewport(0, 0, w, h);
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrtho(0, w, h, 0, -1001, 1001);
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();

		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
		glEnableClientState(GL_COLOR_ARRAY);
#endif
	}
}

void RendererState::pushOrthoState(int w, int h) {
	pushViewport();
	setViewport(0, 0, w, h);

	if (use_modern_gl) {
		pushState(false);
		pushState(true);

		view = glm::ortho(0.f, (float)w, (float)h, 0.f, -1001.f, 1001.f);
		world = glm::mat4();
	} else {
#ifndef NO_OLD_GL
		setViewport(0, 0, w, h);

		glMatrixMode(GL_PROJECTION);
		glPushMatrix();
		glLoadIdentity();
		glOrtho(0, w, h, 0, -1001, 1001);

		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
#endif
	}
}

void RendererState::popOrthoState() {
	if (use_modern_gl) {
		popState(false);
		popState(true);
	} else {
#ifndef NO_OLD_GL
		glMatrixMode(GL_PROJECTION);
		glPopMatrix();
		glMatrixMode(GL_MODELVIEW);
#endif
	}

	popViewport();
}

void RendererState::updateMVP() {
	mvp = view * world;
}

void RendererState::identity(bool isworld) {
	if (use_modern_gl) {
		if (isworld) world = glm::mat4();
		else view = glm::mat4();
	} else {
#ifndef NO_OLD_GL
		glLoadIdentity();
#endif
	}
}

void RendererState::setViewport(int x, int y, int w, int h) {
	viewport = glm::vec4(x, y, w, h);
	glViewport(x, y, w, h);
}
void RendererState::pushViewport() {
	saved_viewports.push(viewport);
}
void RendererState::popViewport() {
	viewport = saved_viewports.top();
	saved_viewports.pop();
	setViewport(viewport.x, viewport.y, viewport.z, viewport.w);
}

void RendererState::pushState(bool isworld) {
	if (use_modern_gl) {
		if (isworld) saved_worlds.push(world);
		else saved_views.push(view);
	} else {
#ifndef NO_OLD_GL
		glPushMatrix();
#endif
	}
}
void RendererState::popState(bool isworld) {
	if (use_modern_gl) {
		if (isworld) { world = saved_worlds.top(); saved_worlds.pop(); }
		else { view = saved_views.top(); saved_views.pop(); }
	} else {
#ifndef NO_OLD_GL
		glPopMatrix();
#endif
	}
}

void RendererState::translate(float x, float y, float z) {
	if (use_modern_gl) {
		world = glm::translate(world, glm::vec3(x, y, z));
	} else {
#ifndef NO_OLD_GL
		glTranslatef(x, y, z);
#endif
	}
}

void RendererState::rotate(float a, float x, float y, float z) {
	if (use_modern_gl) {
		world = glm::rotate(world, a, glm::vec3(x, y, z));
	} else {
#ifndef NO_OLD_GL
		glRotatef(a, x, y, z);
#endif
	}
}

void RendererState::scale(float x, float y, float z) {
	if (use_modern_gl) {
		world = glm::scale(world, glm::vec3(x, y, z));
	} else {
#ifndef NO_OLD_GL
		glScalef(x, y, z);
#endif
	}
}
