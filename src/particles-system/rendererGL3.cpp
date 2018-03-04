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
#include "displayobjects/Renderer.hpp"
#include "particles-system/system.hpp"

namespace particles {

GLuint RendererGL3::vbo_shape = 0;
void RendererGL3::init() {
	const GLfloat shape[] = {
		-0.5f, -0.5f,
		0.5f, -0.5f,
		-0.5f, 0.5f,
		0.5f, 0.5f,
	};
	glGenBuffers(1, &vbo_shape);
	glBindBuffer(GL_ARRAY_BUFFER, vbo_shape);
	glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat) * 8, shape, GL_STATIC_DRAW);
}

void RendererGL3::setup(ParticlesData &p) {
	if (!vbo_shape) init();
	glGenBuffers(1, &vbo_pos);
	glGenBuffers(1, &vbo_color);
	glGenBuffers(1, &vbo_texture);
	vertexes.reserve(4 * p.max);

	glGenVertexArrays(1, &vao);
	glBindVertexArray(vao);

	shader_type *shader = this->shader.get() ? this->shader->shader : default_particlescompose_shader->shader;

	glBindBuffer(GL_ARRAY_BUFFER, vbo_shape);
	glEnableVertexAttribArray(shader->shape_vertex_attrib);
	glVertexAttribPointer(shader->shape_vertex_attrib, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 2, (void*)0);
	glVertexAttribDivisor(shader->shape_vertex_attrib, 0);
	
	glBindBuffer(GL_ARRAY_BUFFER, vbo_pos);
	glEnableVertexAttribArray(shader->vertex_attrib);
	glVertexAttribPointer(shader->vertex_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(vec4), (void*)0);
	glVertexAttribDivisor(shader->vertex_attrib, 1);

	glBindBuffer(GL_ARRAY_BUFFER, vbo_color);
	glEnableVertexAttribArray(shader->color_attrib);
	glVertexAttribPointer(shader->color_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(vec4), (void*)0);
	glVertexAttribDivisor(shader->color_attrib, 1);

	glBindBuffer(GL_ARRAY_BUFFER, vbo_texture);
	glEnableVertexAttribArray(shader->texcoord_attrib);
	glVertexAttribPointer(shader->texcoord_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(vec4), (void*)0);
	glVertexAttribDivisor(shader->texcoord_attrib, 1);

	glBindVertexArray(0);
}

RendererGL3::~RendererGL3() {
	glDeleteVertexArrays(1, &vao);
	glDeleteBuffers(1, &vbo_texture);
	glDeleteBuffers(1, &vbo_pos);
	glDeleteBuffers(1, &vbo_color);
}

void RendererGL3::update(ParticlesData &p) {
}

void RendererGL3::draw(ParticlesData &p, mat4 &model) {
	mat4 mvp = View::getCurrent()->get() * model;

	switch (blend) {
		case RendererBlend::DefaultBlend: break;
		case RendererBlend::AdditiveBlend: glBlendFunc(GL_ONE, GL_ONE); break;
		case RendererBlend::MixedBlend: glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;
		case RendererBlend::ShinyBlend: glBlendFunc(GL_SRC_ALPHA,GL_ONE); break;
	}

	if (tex.get()) {
		tglActiveTexture(GL_TEXTURE0);
		tglBindTexture(GL_TEXTURE_2D, tex->tex->tex);
	}

	shader_type *shader = this->shader.get() ? this->shader->shader : default_particlescompose_shader->shader;
	useShaderSimple(shader);

	vec4 color(1, 1, 1, 1);
	glUniformMatrix4fv(shader->p_mvp, 1, GL_FALSE, glm::value_ptr(mvp));
	if (shader->p_color != -1) { glUniform4fv(shader->p_color, 1, glm::value_ptr(color)); }

	// Upload data, do it in a sub-block to auto unlock the mutex
	{
		lock_guard<mutex> guard(p.mux);
		glBindBuffer(GL_ARRAY_BUFFER, vbo_pos);
		glBufferData(GL_ARRAY_BUFFER, sizeof(vec4) * p.count, NULL, GL_STREAM_DRAW);
		glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vec4) * p.count, p.getSlot4(POS));

		glBindBuffer(GL_ARRAY_BUFFER, vbo_color);
		glBufferData(GL_ARRAY_BUFFER, sizeof(vec4) * p.count, NULL, GL_STREAM_DRAW);
		glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vec4) * p.count, p.getSlot4(COLOR));

		glBindBuffer(GL_ARRAY_BUFFER, vbo_texture);
		glBufferData(GL_ARRAY_BUFFER, sizeof(vec4) * p.count, NULL, GL_STREAM_DRAW);
		glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vec4) * p.count, p.getSlot4(TEXTURE));
	}

	// Draw!!!!
	glBindVertexArray(vao);
	glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 4, p.count);
	glBindVertexArray(0);

	switch (blend) {
		case RendererBlend::DefaultBlend: break;
		default: glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA); break;
	}
}

}
