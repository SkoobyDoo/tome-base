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

#include "RendererGL.hpp"

RendererGL::RendererGL() {
	glGenBuffers(1, &vbo);
	if (mode == VERTEX_STATIC) mode = GL_STATIC_DRAW;
	if (mode == VERTEX_DYNAMIC) mode = GL_DYNAMIC_DRAW;
	if (mode == VERTEX_STREAM) mode = GL_STREAM_DRAW;
	if (kind == VO_POINTS) kind = GL_POINTS;
	if (kind == VO_QUADS) kind = GL_TRIANGLES;
	if (kind == VO_TRIANGLE_FAN) kind = GL_TRIANGLE_FAN;
}

~RendererGL::RendererGL() {
	glDeleteBuffers(1, vbo);
}

void RendererGL::render(DisplayObject *dob) {

}

void RendererGL::update() {
	// Release old un-needed buffer, this way the GL driver does not have to lock the memory
	glBufferData(GL_ARRAY_BUFFER, sizeof(vertex) * vx->nb, NULL, vr->mode);
	glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vertex) * vx->nb, vx->vertices);

	if (vx->kind == VO_QUADS) {
		int nb_quads = vx->nb / 4;

		if (nb_quads > vbo_elements_nb) {
			vbo_elements_data = (GLuint*)realloc((void*)vbo_elements_data, nb_quads * 6 * sizeof(GLuint));
			for (; vbo_elements_nb < nb_quads; vbo_elements_nb++) {
				// printf("Initing a quad elements %d\n", vbo_elements_nb);
				vbo_elements_data[vbo_elements_nb * 6 + 0] = vbo_elements_nb * 4 + 0;
				vbo_elements_data[vbo_elements_nb * 6 + 1] = vbo_elements_nb * 4 + 1;
				vbo_elements_data[vbo_elements_nb * 6 + 2] = vbo_elements_nb * 4 + 2;

				vbo_elements_data[vbo_elements_nb * 6 + 3] = vbo_elements_nb * 4 + 0;
				vbo_elements_data[vbo_elements_nb * 6 + 4] = vbo_elements_nb * 4 + 2;
				vbo_elements_data[vbo_elements_nb * 6 + 5] = vbo_elements_nb * 4 + 3;
			}

			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_elements);
			// Release old un-needed buffer, this way the GL driver does not have to lock the memory
			glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(GLuint) * vbo_elements_nb * 6, NULL, GL_DYNAMIC_DRAW);
			glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, 0, sizeof(GLuint) * vbo_elements_nb * 6, vbo_elements_data);
		}
	}
}

void vertexes_renderer_toscreen(vertexes_renderer *vr, lua_vertexes *vx, float x, float y, float r, float g, float b, float a) {
	if (vx != renderer_quad_pipe && renderer_quad_pipe->nb) renderer_pipe_flush();

	tglBindTexture(GL_TEXTURE_2D, vx->tex);
	state->translate(x, y, 0);

	shader_type *shader;

	if (!current_shader) {
		useNoShader();
		if (!current_shader) return;
	}

	shader = current_shader;
	if (shader->vertex_attrib == -1) return;

	if (shader->p_color != -1) {
		GLfloat d[4];
		d[0] = r;
		d[1] = g;
		d[2] = b;
		d[3] = a;
		glUniform4fv(shader->p_color, 1, d);
	}

	if (shader->p_mvp != -1) {
		if (vx == renderer_quad_pipe && state->quad_pipe_enabled) {
			glUniformMatrix4fv(shader->p_mvp, 1, GL_FALSE, glm::value_ptr(state->view));
		} else {
			state->updateMVP(vx != renderer_quad_pipe);
			glUniformMatrix4fv(shader->p_mvp, 1, GL_FALSE, glm::value_ptr(state->mvp));
		}
	}

	glBindBuffer(GL_ARRAY_BUFFER, vr->vbo);
	if (vx->changed) {
		vertexes_renderer_update(vr, vx);
	}

	glEnableVertexAttribArray(shader->vertex_attrib);
	glVertexAttribPointer(shader->vertex_attrib, 2, GL_FLOAT, GL_FALSE, sizeof(vertex), (void*)0);
	if (shader->texcoord_attrib != -1) {
		glEnableVertexAttribArray(shader->texcoord_attrib);
		glVertexAttribPointer(shader->texcoord_attrib, 2, GL_FLOAT, GL_FALSE, sizeof(vertex), (void*)offsetof(vertex, u));
	}
	if (shader->color_attrib != -1) {
		glEnableVertexAttribArray(shader->color_attrib);
		glVertexAttribPointer(shader->color_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(vertex), (void*)offsetof(vertex, r));
	}

	if (vx->kind == VO_QUADS) {
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_elements);
		glDrawElements(vr->kind, vx->nb / 4 * 6, GL_UNSIGNED_INT, (void*)0);
	} else {
		glDrawArrays(vr->kind, 0, vx->nb);
	}

	glDisableVertexAttribArray(shader->vertex_attrib);
	glDisableVertexAttribArray(shader->texcoord_attrib);
	glDisableVertexAttribArray(shader->color_attrib);
	glBindBuffer(GL_ARRAY_BUFFER, 0);

	state->translate(-x, -y, 0);
	vx->changed = FALSE;
}
