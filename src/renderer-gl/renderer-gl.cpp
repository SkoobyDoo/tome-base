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

// static RendererState *state;

vertexes_renderer* vertexes_renderer_new(render_mode mode) {
	vertexes_renderer *vr = (vertexes_renderer*)malloc(sizeof(vertexes_renderer));
	glGenBuffers(3, vr->vbo);
	if (mode == VERTEX_STATIC) vr->mode = GL_STATIC_DRAW;
	if (mode == VERTEX_DYNAMIC) vr->mode = GL_DYNAMIC_DRAW;
	if (mode == VERTEX_STREAM) vr->mode = GL_STREAM_DRAW;
	return vr;
}

void vertexes_renderer_free(vertexes_renderer *vr) {
	free(vr);
}

void vertexes_renderer_toscreen(vertexes_renderer *vr, lua_vertexes *vx, float x, float y) {
	tglBindTexture(GL_TEXTURE_2D, vx->tex);
	glTranslatef(x, y, 0);

#if 0
	if (vx->changed) printf("UPDATING VO\n");

	glBindBuffer(GL_ARRAY_BUFFER, vr->vbo[0]);
	if (vx->changed) glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat) * 2 * vx->nb, vx->vertices, vr->mode);
	glVertexPointer(2, GL_FLOAT, 0, 0);

	glBindBuffer(GL_ARRAY_BUFFER, vr->vbo[1]);
	if (vx->changed) glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat) * 4 * vx->nb, vx->colors, vr->mode);
	glColorPointer(4, GL_FLOAT, 0, 0);

	glBindBuffer(GL_ARRAY_BUFFER, vr->vbo[2]);
	if (vx->changed) glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat) * 2 * vx->nb, vx->textures, vr->mode);
	glTexCoordPointer(2, GL_FLOAT, 0, 0);

	glDrawArrays(GL_QUADS, 0, vx->nb);

	glBindBuffer(GL_ARRAY_BUFFER, 0);
#else
	glVertexPointer(2, GL_FLOAT, 0, vx->vertices);
	glColorPointer(4, GL_FLOAT, 0, vx->colors);
	glTexCoordPointer(2, GL_FLOAT, 0, vx->textures);
	glDrawArrays(GL_QUADS, 0, vx->nb);
#endif

	glTranslatef(-x, -y, 0);

	vx->changed = FALSE;
}
/*
RendererState::RendererState(int w, int h) {
	view = glm::ortho(0.f, (float)w, (float)h, 0.f, -1001.f, 1001.f);
	world = glm::mat4();
}

void RendererState::translate(float x, float y, float z) {
	glm::mat4 t = glm::translate(glm::mat4(), glm::vec3(x, y, z));
	world *= t;
}

void renderer_init(int w, int h) {
	state = new RendererState(w, h);
}
*/