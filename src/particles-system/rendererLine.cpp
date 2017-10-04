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

void RendererLine::setup(ParticlesData &p) {
	vertexes.reserve(4 * p.max * 3);

	glGenBuffers(2, vbos);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbos[0]);
	GLuint *vbo_elements_data = new GLuint[p.max * 6 * 3];
	for (uint32_t i = 0; i < p.max; i++) {
		vbo_elements_data[i * 6 + 0] = i * 4 + 0;
		vbo_elements_data[i * 6 + 1] = i * 4 + 1;
		vbo_elements_data[i * 6 + 2] = i * 4 + 2;

		vbo_elements_data[i * 6 + 3] = i * 4 + 0;
		vbo_elements_data[i * 6 + 4] = i * 4 + 2;
		vbo_elements_data[i * 6 + 5] = i * 4 + 3;
	}
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(GLuint) * p.max * 6 * 3, vbo_elements_data, GL_STATIC_DRAW);
	delete[] vbo_elements_data;
}

RendererLine::~RendererLine() {
	glDeleteBuffers(2, vbos);
}

void RendererLine::update(ParticlesData &p) {
	lock_guard<mutex> guard(p.mux);

	vertexes.clear();
	vec4* pos = p.getSlot4(POS);
	vec2* links = p.getSlot2(LINKS);
	vec4* tex = p.getSlot4(TEXTURE);
	vec4* color = p.getSlot4(COLOR);
	if (!pos || !tex || !color || !links || !p.count) return;
	for (int32_t i = 0; i < p.count - 1; i++) {
		if (links[i].x >= 0) continue; // This is not the start of a line

		int32_t curid = i;
		int32_t nextid = (int32_t)links[i].y;
		// printf("__ starting chain at %d => %d\n", curid, nextid);
		if (links[nextid].y == curid) { printf("Loop detected %d <=> %d, breaking\n", curid, nextid); continue; }
		while (nextid >= 0 && nextid != curid) {
			vec4 p1 = pos[curid];
			vec4 p2 = pos[nextid];
			vec4 color1 = color[curid];
			vec4 color2 = color[nextid];

			float angle = atan2(p2.y - p1.y, p2.x - p1.x) + M_PI_2;
			float cangle = cos(angle);
			float sangle = sin(angle);

			mat2 rot(cangle, -sangle, sangle, cangle);

			vec2 bp1(p1.x, p1.y);
			vec2 ip1 = bp1 + vec2(-p1.z, 0) * rot;
			vec2 ip2 = bp1 + vec2( p1.z, 0) * rot;
			vec2 ip3 = bp1 + vec2( p1.z, p1.z) * rot;
			vec2 ip4 = bp1 + vec2(-p1.z, p1.z) * rot;
			vertexes.push_back({ ip1, {tex[curid].s, tex[curid].t+(tex[curid].q-tex[curid].t)*0.25}, color1 });
			vertexes.push_back({ ip2, {tex[curid].p, tex[curid].t+(tex[curid].q-tex[curid].t)*0.25}, color1 });
			vertexes.push_back({ ip3, {tex[curid].p, tex[curid].t}, color1 });
			vertexes.push_back({ ip4, {tex[curid].s, tex[curid].t}, color1 });

			vec2 bp2(p2.x, p2.y);
			vec2 ip5 = bp2 + vec2(-p2.z, -p2.z) * rot;
			vec2 ip6 = bp2 + vec2( p2.z, -p2.z) * rot;
			vec2 ip7 = bp2 + vec2( p2.z, 0) * rot;
			vec2 ip8 = bp2 + vec2(-p2.z, 0) * rot;
			vertexes.push_back({ ip5, {tex[curid].s, tex[curid].q}, color2 });
			vertexes.push_back({ ip6, {tex[curid].p, tex[curid].q}, color2 });
			vertexes.push_back({ ip7, {tex[curid].p, tex[curid].t+(tex[curid].q-tex[curid].t)*0.75}, color2 });
			vertexes.push_back({ ip8, {tex[curid].s, tex[curid].t+(tex[curid].q-tex[curid].t)*0.75}, color2 });

			vertexes.push_back({ ip1, {tex[curid].s, tex[curid].t+(tex[curid].q-tex[curid].t)*0.25}, color1 });
			vertexes.push_back({ ip2, {tex[curid].p, tex[curid].t+(tex[curid].q-tex[curid].t)*0.25}, color1 });
			vertexes.push_back({ ip7, {tex[curid].p, tex[curid].t+(tex[curid].q-tex[curid].t)*0.75}, color2 });
			vertexes.push_back({ ip8, {tex[curid].s, tex[curid].t+(tex[curid].q-tex[curid].t)*0.75}, color2 });

			curid = nextid;	
			nextid = (uint32_t)links[nextid].y;
			// printf(" - contiuing chain at %d => %d\n", curid, nextid);
		}
	}
}

void RendererLine::draw(ParticlesData &p, mat4 &model) {
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
