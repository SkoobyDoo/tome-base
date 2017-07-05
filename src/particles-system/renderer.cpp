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
#include "renderer-moderngl/Renderer.hpp"
#include "particles-system/system.hpp"

namespace particles {

shader_type *default_particlescompose_shader = NULL;

GLuint Renderer::vbo_shape = 0;
void Renderer::init() {
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

void Renderer::setup(ParticlesData &p) {
	if (!vbo_shape) init();
	glGenBuffers(1, &vbo_pos);
	glGenBuffers(1, &vbo_color);
	vertexes.reserve(4 * p.max);

	glGenBuffers(2, vbos);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbos[0]);
	GLuint *vbo_elements_data = new GLuint[p.max * 6];
	for (uint32_t i = 0; i < p.max; i++) {
		vbo_elements_data[i * 6 + 0] = i * 4 + 0;
		vbo_elements_data[i * 6 + 1] = i * 4 + 1;
		vbo_elements_data[i * 6 + 2] = i * 4 + 2;

		vbo_elements_data[i * 6 + 3] = i * 4 + 0;
		vbo_elements_data[i * 6 + 4] = i * 4 + 2;
		vbo_elements_data[i * 6 + 5] = i * 4 + 3;
	}
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(GLuint) * p.max * 6, vbo_elements_data, GL_STATIC_DRAW);
	delete[] vbo_elements_data;
}

void Renderer::setBlend(RendererBlend blend) {
	this->blend = blend;
}

void Renderer::setShader(shader_type *shader) {
	this->shader = shader;
}
void Renderer::setTexture(texture_type *tex) {
	this->tex = tex;
}

void Renderer::update(ParticlesData &p) {
	vertexes.clear();
	vec4* pos = p.getSlot4(POS);
	vec4* tex = p.getSlot4(TEXTURE);
	vec4* color = p.getSlot4(COLOR);
	for (uint32_t i = 0; i < p.count; i++) {
		vertexes.push_back({ {pos[i].x - pos[i].z, pos[i].y - pos[i].z, }, {tex[i].s, tex[i].t}, color[i] });
		vertexes.push_back({ {pos[i].x + pos[i].z, pos[i].y - pos[i].z, }, {tex[i].p, tex[i].t}, color[i] });
		vertexes.push_back({ {pos[i].x + pos[i].z, pos[i].y + pos[i].z, }, {tex[i].p, tex[i].q}, color[i] });
		vertexes.push_back({ {pos[i].x - pos[i].z, pos[i].y + pos[i].z, }, {tex[i].s, tex[i].q}, color[i] });
	}
}

//*
void Renderer::draw(ParticlesData &p, float x, float y) {
	mat4 model = mat4();
	model = glm::translate(model, glm::vec3(x, y, 0));
	mat4 mvp = View::getCurrent()->get() * model;

	switch (blend) {
		case RendererBlend::DefaultBlend: break;
		case RendererBlend::AdditiveBlend: glBlendFunc(GL_ONE, GL_ONE); break;
		case RendererBlend::MixedBlend: glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;
		case RendererBlend::ShinyBlend: glBlendFunc(GL_SRC_ALPHA,GL_ONE); break;
	}

	if (tex) {
		tglActiveTexture(GL_TEXTURE0);
		tglBindTexture(GL_TEXTURE_2D, tex->tex);
	}

	shader_type *shader = shader ? shader : (default_particlescompose_shader ? default_particlescompose_shader : default_shader);
	useShaderSimple(shader);

	glUniformMatrix4fv(shader->p_mvp, 1, GL_FALSE, glm::value_ptr(mvp));

	glBindBuffer(GL_ARRAY_BUFFER, vbos[1]);
	glBufferData(GL_ARRAY_BUFFER, sizeof(renderer_vertex) * vertexes.size(), NULL, GL_STREAM_DRAW);
	glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(renderer_vertex) * vertexes.size(), vertexes.data());

	glEnableVertexAttribArray(shader->vertex_attrib);
	glVertexAttribPointer(shader->vertex_attrib, 2, GL_FLOAT, GL_FALSE, sizeof(renderer_vertex), (void*)0);
	if (shader->texcoord_attrib != -1) {
		glEnableVertexAttribArray(shader->texcoord_attrib);
		glVertexAttribPointer(shader->texcoord_attrib, 2, GL_FLOAT, GL_FALSE, sizeof(renderer_vertex), (void*)offsetof(renderer_vertex, tex));
	}
	if (shader->color_attrib != -1) {
		glEnableVertexAttribArray(shader->color_attrib);
		glVertexAttribPointer(shader->color_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(renderer_vertex), (void*)offsetof(renderer_vertex, color));
	}

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbos[0]);

	glDrawElements(GL_TRIANGLES, p.count * 6, GL_UNSIGNED_INT, (void*)0);

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

	switch (blend) {
		case RendererBlend::DefaultBlend: break;
		default: glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA); break;
	}
}
//*/
/* Instancing version
void Renderer::draw(ParticlesData &p, float x, float y) {
	mat4 model = mat4();
	model = glm::translate(model, glm::vec3(x, y, 0));
	mat4 mvp = View::getCurrent()->get() * model;

	if (tex) {
		tglActiveTexture(GL_TEXTURE0);
		tglBindTexture(GL_TEXTURE_2D, tex->tex);
	}

	shader_type *shader = shader ? shader : default_particlescompose_shader;
	useShaderSimple(shader);

	glUniformMatrix4fv(shader->p_mvp, 1, GL_FALSE, glm::value_ptr(mvp));

	glBindBuffer(GL_ARRAY_BUFFER, vbo_shape);
	glEnableVertexAttribArray(shader->shape_vertex_attrib);
	glVertexAttribPointer(shader->shape_vertex_attrib, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 2, (void*)0);
	glVertexAttribDivisor(shader->shape_vertex_attrib, 0);
	
	glBindBuffer(GL_ARRAY_BUFFER, vbo_pos);
	glBufferData(GL_ARRAY_BUFFER, sizeof(vec4) * p.count, NULL, GL_STREAM_DRAW);
	glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vec4) * p.count, p.getSlot4(POS));
	glEnableVertexAttribArray(shader->vertex_attrib);
	glVertexAttribPointer(shader->vertex_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(vec4), (void*)0);
	glVertexAttribDivisor(shader->vertex_attrib, 1);

	glBindBuffer(GL_ARRAY_BUFFER, vbo_color);
	glBufferData(GL_ARRAY_BUFFER, sizeof(vec4) * p.count, NULL, GL_STREAM_DRAW);
	glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vec4) * p.count, p.getSlot4(COLOR));
	glEnableVertexAttribArray(shader->color_attrib);
	glVertexAttribPointer(shader->color_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(vec4), (void*)0);
	glVertexAttribDivisor(shader->color_attrib, 1);

	glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 4, p.count);
}
//*/
}
