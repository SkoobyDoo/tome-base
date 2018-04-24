/*
    TE4 - T-Engine 4
    Copyright (C) 2009 - 2018 Nicolas Casalini

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

spShaderHolder default_particlescompose_shader;

void Renderer::setBlend(RendererBlend blend) {
	this->blend = blend;
}

void Renderer::setShader(spShaderHolder &shader) {
	this->shader = shader;
}
void Renderer::setTexture(spTextureHolder &tex) {
	this->tex = tex;
}

void RendererGL2::setup(ParticlesData &p) {
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

RendererGL2::~RendererGL2() {
	glDeleteBuffers(2, vbos);
}

void RendererGL2::update(ParticlesData &p) {
	lock_guard<mutex> guard(p.mux);

	vertexes.clear();
	vec4* pos = p.getSlot4(POS);
	vec4* tex = p.getSlot4(TEXTURE);
	vec4* color = p.getSlot4(COLOR);
	if (!pos || !tex || !color) return;
	for (uint32_t i = 0; i < p.count; i++) {
		vec4 p = pos[i];
		if (!p.w) { // Not rotated, easy case
			vertexes.push_back({ {p.x - p.z, p.y - p.z, }, {tex[i].s, tex[i].t}, color[i] });
			vertexes.push_back({ {p.x + p.z, p.y - p.z, }, {tex[i].p, tex[i].t}, color[i] });
			vertexes.push_back({ {p.x + p.z, p.y + p.z, }, {tex[i].p, tex[i].q}, color[i] });
			vertexes.push_back({ {p.x - p.z, p.y + p.z, }, {tex[i].s, tex[i].q}, color[i] });
		} else {
			float s = sin(p.w);
			float c = cos(p.w);
			mat2 rot(c, -s, s, c);

			vec2 p1(-p.z, -p.z);
			vec2 p2( p.z, -p.z);
			vec2 p3( p.z,  p.z);
			vec2 p4(-p.z,  p.z);
			vec2 bp(p.x, p.y);
			vertexes.push_back({ bp + p1 * rot, {tex[i].s, tex[i].t}, color[i] });
			vertexes.push_back({ bp + p2 * rot, {tex[i].p, tex[i].t}, color[i] });
			vertexes.push_back({ bp + p3 * rot, {tex[i].p, tex[i].q}, color[i] });
			vertexes.push_back({ bp + p4 * rot, {tex[i].s, tex[i].q}, color[i] });
		}
	}
}

void RendererGL2::draw(ParticlesData &p, mat4 &model) {
	mat4 mvp = View::getCurrent()->get() * model;
	vec4 color(1, 1, 1, 1);

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

	glUniformMatrix4fv(shader->p_mvp, 1, GL_FALSE, glm::value_ptr(mvp));
	if (shader->p_color != -1) { glUniform4fv(shader->p_color, 1, glm::value_ptr(color)); }

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

	glDrawElements(GL_TRIANGLES, vertexes.size() * 6 / 4, GL_UNSIGNED_INT, (void*)0);

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

	switch (blend) {
		case RendererBlend::DefaultBlend: break;
		default: glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA); break;
	}
}

}
