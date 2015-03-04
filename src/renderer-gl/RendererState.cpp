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
#include "main.h"
}

#include "renderer-gl.hpp"

RendererState::RendererState(int w, int h) {
	quad_pipe_enabled = false;

	/* Set the background black */
	tglClearColor( 0.0f, 0.0f, 0.0f, 1.0f );

	/* Depth buffer setup */
	// glClearDepth( 1.0f );

	/* The Type Of Depth Test To Do */
	glDepthFunc(GL_LEQUAL);

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	setViewport(0, 0, w, h);
	view = glm::ortho(0.f, (float)w, (float)h, 0.f, -1001.f, 1001.f);
	world = mat4();
	pipe_world = mat4();
#ifndef NO_OLD_GL
	if (!use_modern_gl) {
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrtho(0, w, h, 0, -1001, 1001);
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();

		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
		glEnableClientState(GL_COLOR_ARRAY);
	}
#endif
}

void RendererState::pushOrthoState(int w, int h) {
	pushViewport();
	setViewport(0, 0, w, h);

	pushState(false);
	pushState(true);

	view = glm::ortho(0.f, (float)w, (float)h, 0.f, -1001.f, 1001.f);
	world = mat4();
#ifndef NO_OLD_GL
	if (!use_modern_gl) {
		glMatrixMode(GL_PROJECTION);
		glPushMatrix();
		glLoadIdentity();
		glOrtho(0, w, h, 0, -1001, 1001);

		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
	}
#endif
}

void RendererState::popOrthoState() {
	popState(false);
	popState(true);
#ifndef NO_OLD_GL
	if (!use_modern_gl) {
		glMatrixMode(GL_PROJECTION);
		glPopMatrix();
		glMatrixMode(GL_MODELVIEW);
	}
#endif

	popViewport();
}

void RendererState::updateMVP(bool include_pipe_world) {
	if (include_pipe_world && quad_pipe_enabled) mvp = view * world * pipe_world;
	else mvp = view * world;
}

void RendererState::identity(bool isworld) {
	if (isworld) world = mat4();
	else view = mat4();
#ifndef NO_OLD_GL
	if (!use_modern_gl) {
		glLoadIdentity();
	}
#endif
}

void RendererState::setViewport(int x, int y, int w, int h) {
	viewport = vec4(x, y, w, h);
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
	if (quad_pipe_enabled && isworld) {
		saved_pipe_worlds.push(pipe_world);
	}
	if (isworld) saved_worlds.push(world);
	else saved_views.push(view);
#ifndef NO_OLD_GL
	if (!use_modern_gl) {
		glPushMatrix();
	}
#endif
}
void RendererState::popState(bool isworld) {
	if (quad_pipe_enabled && isworld) {
		pipe_world = saved_pipe_worlds.top(); saved_pipe_worlds.pop();
	}
	if (isworld) { world = saved_worlds.top(); saved_worlds.pop(); }
	else { view = saved_views.top(); saved_views.pop(); }
#ifndef NO_OLD_GL
	if (!use_modern_gl) {
		glPopMatrix();
	}
#endif
}

void RendererState::translate(float x, float y, float z) {
	if (quad_pipe_enabled) {
		pipe_world = glm::translate(pipe_world, glm::vec3(x, y, z));
		return;
	}
	world = glm::translate(world, glm::vec3(x, y, z));
#ifndef NO_OLD_GL
	if (!use_modern_gl) {
		glTranslatef(x, y, z);
	}
#endif
}

void RendererState::rotate(float a, float x, float y, float z) {
	if (quad_pipe_enabled) {
		pipe_world = glm::rotate(pipe_world, a, glm::vec3(x, y, z));
		return;
	}
	world = glm::rotate(world, a, glm::vec3(x, y, z));
#ifndef NO_OLD_GL
	if (!use_modern_gl) {
		glRotatef(a, x, y, z);
	}
#endif
}

void RendererState::scale(float x, float y, float z) {
	if (quad_pipe_enabled) {
		pipe_world = glm::scale(pipe_world, glm::vec3(x, y, z));
		return;
	}
	world = glm::scale(world, glm::vec3(x, y, z));
#ifndef NO_OLD_GL
	if (!use_modern_gl) {
		glScalef(x, y, z);
	}
#endif
}

void RendererState::enableQuadPipe(bool v) {
	quad_pipe_enabled += v ? 1 : -1;

	if (quad_pipe_enabled == 1) {
		pipe_world = mat4();
	} else if (quad_pipe_enabled == 0) {
		while (!saved_pipe_worlds.empty()) saved_pipe_worlds.pop();
	}
}

void RendererState::pushCutoff(float x, float y, float w, float h) {
	if (cutoffs.empty()) glEnable(GL_SCISSOR_TEST);
	
	updateMVP(false);

	vec4 p1(x, y, 0, 1), p2(x+w, y+h, 0, 1);
	p1 = world * p1;
	p2 = world * p2;

	vec4 c(p1.x, p1.y, p2.x, p2.y);
	cutoffs.push(c);

	glScissor(c.x, viewport.w - c.w, c.z - c.x, c.w - c.y);
}

void RendererState::popCutoff() {
	cutoffs.pop();
	if (cutoffs.empty()) {
		glDisable(GL_SCISSOR_TEST);
	} else {
		vec4 c = cutoffs.top();
		glScissor(c.x, viewport.w - c.y - c.w, c.z, c.w);
	}
}
