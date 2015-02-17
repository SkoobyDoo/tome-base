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
	glGenBuffers(1, &vr->vbo);
	if (mode == VERTEX_STATIC) vr->mode = GL_STATIC_DRAW;
	if (mode == VERTEX_DYNAMIC) vr->mode = GL_DYNAMIC_DRAW;
	if (mode == VERTEX_STREAM) vr->mode = GL_STREAM_DRAW;
	return vr;
}

void vertexes_renderer_free(vertexes_renderer *vr) {
	glDeleteBuffers(1, &vr->vbo);
	free(vr);
}

void vertexes_renderer_toscreen(vertexes_renderer *vr, lua_vertexes *vx, float x, float y) {
	tglBindTexture(GL_TEXTURE_2D, vx->tex);
	glTranslatef(x, y, 0);

#if 1
	if (vx->changed) printf("UPDATING VO\n");

	shader_type *shader = vx->shader ? vx->shader : default_shader;
	useShader(shader, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1);
	GLint i = 0;
	glUniform1iv(shader->p_tex, 1, &i);

	glBindBuffer(GL_ARRAY_BUFFER, vr->vbo);
	if (vx->changed) {
		// glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_data) * vx->nb, vx->vertices, vr->mode);
		glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_data) * vx->nb, NULL, vr->mode);
		glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vertex_data) * vx->nb, vx->vertices);
	}

	glEnableVertexAttribArray(0);
	glEnableVertexAttribArray(1);
	glEnableVertexAttribArray(2);
	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(vertex_data), 0);
	glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(vertex_data), (void*)(sizeof(GLfloat) * 2));
	glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, sizeof(vertex_data), (void*)(sizeof(GLfloat) * 4));

	// glVertexPointer(2, GL_FLOAT, sizeof(vertex_data), 0);
	// glTexCoordPointer(2, GL_FLOAT, sizeof(vertex_data), (void*)(sizeof(GLfloat) * 2));
	// glColorPointer(4, GL_FLOAT, sizeof(vertex_data), (void*)(sizeof(GLfloat) * 4));

	glDrawArrays(GL_QUADS, 0, vx->nb);

	glDisableVertexAttribArray(0);
	glDisableVertexAttribArray(1);
	glDisableVertexAttribArray(2);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	useNoShader();
#else
	glVertexPointer(2, GL_FLOAT, sizeof(vertex_data), vx->vertices);
	glTexCoordPointer(2, GL_FLOAT, sizeof(vertex_data), &vx->vertices[0].u);
	glColorPointer(4, GL_FLOAT, sizeof(vertex_data), &vx->vertices[0].r);
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