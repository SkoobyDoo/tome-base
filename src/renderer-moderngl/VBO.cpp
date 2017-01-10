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

extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "display.h"
#include "types.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "main.h"
}
#include "renderer-moderngl/VBO.hpp"
#include "renderer-moderngl/View.hpp"

VBO::VBO(VBOMode mode) : VBO() {
	this->mode = mode;
}

VBO::VBO() {
	glGenBuffers(1, &vbo);
}

VBO::~VBO() {
	glDeleteBuffers(1, &vbo);
}

void VBO::clear() {
	vertices.clear();
	textures.clear();
	shader = NULL;
	changed = true;
}

void VBO::setTexture(GLuint tex) {
	setTexture(tex, 0);
}

void VBO::setTexture(GLuint tex, int pos) {
	textures.resize(pos + 1, 0);
	textures[pos] = tex;
}

void VBO::setShader(shader_type *shader) {
	this->shader = shader;
}

void VBO::setColor(float r, float g, float b, float a) {
	color = {r, g, b, a};
}

int VBO::addQuad(
		float x1, float y1, float u1, float v1, 
		float x2, float y2, float u2, float v2, 
		float x3, float y3, float u3, float v3, 
		float x4, float y4, float u4, float v4, 
		float r, float g, float b, float a
	) {
	return addQuad(
		x1, y1, 0, u1, v1,
		x2, y2, 0, u2, v2,
		x3, y3, 0, u3, v3,
		x4, y4, 0, u4, v4,
		r, g, b, a
	);
}

int VBO::addQuad(
		float x1, float y1, float z1, float u1, float v1, 
		float x2, float y2, float z2, float u2, float v2, 
		float x3, float y3, float z3, float u3, float v3, 
		float x4, float y4, float z4, float u4, float v4, 
		float r, float g, float b, float a
	) {
	if (vertices.size() + 4 < vertices.capacity()) vertices.reserve(vertices.size() * 2);

	vertices.push_back({{x1, y1, z1, 1}, {u1, v1}, {r, g, b, a}});
	vertices.push_back({{x2, y2, z2, 1}, {u2, v2}, {r, g, b, a}});
	vertices.push_back({{x3, y3, z3, 1}, {u3, v3}, {r, g, b, a}});
	vertices.push_back({{x1, y1, z1, 1}, {u1, v1}, {r, g, b, a}});
	vertices.push_back({{x3, y3, z3, 1}, {u3, v3}, {r, g, b, a}});
	vertices.push_back({{x4, y4, z4, 1}, {u4, v4}, {r, g, b, a}});

	changed = true;
	return 0;
}

void VBO::update() {
	// glBindBuffer(GL_ARRAY_BUFFER, vbo); // dont do it here, we did it before being called in toScreen
	glBufferData(GL_ARRAY_BUFFER, sizeof(vbo_vertex) * vertices.size(), NULL, (GLenum)mode);
	glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vbo_vertex) * vertices.size(), vertices.data());
	changed = false;
}

void VBO::toScreen(mat4 model) {
	glBindBuffer(GL_ARRAY_BUFFER, vbo);
	if (changed) update();

	int tex_unit = 0;
	for (auto tex : textures) {
		tglActiveTexture(GL_TEXTURE0 + tex_unit);
		tglBindTexture(GL_TEXTURE_2D, tex);
		tex_unit++;
	}
	tglActiveTexture(GL_TEXTURE0);

	mat4 mvp = View::getCurrent()->get() * model;

	shader_type *shader = this->shader;
	if (!shader) { useNoShader(); if (!current_shader) return; }
	else { useShaderSimple(shader); current_shader = shader; }
	shader = current_shader;

	if (shader->p_tick != -1) { GLfloat t = cur_frame_tick; glUniform1fv(shader->p_tick, 1, &t); }
	if (shader->p_color != -1) { glUniform4fv(shader->p_color, 1, glm::value_ptr(color)); }
	glUniformMatrix4fv(shader->p_mvp, 1, GL_FALSE, glm::value_ptr(mvp));
	glEnableVertexAttribArray(shader->vertex_attrib);
	glVertexAttribPointer(shader->vertex_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(vbo_vertex), (void*)0);
	glEnableVertexAttribArray(shader->texcoord_attrib);
	glVertexAttribPointer(shader->texcoord_attrib, 2, GL_FLOAT, GL_FALSE, sizeof(vbo_vertex), (void*)offsetof(vbo_vertex, tex));
	glEnableVertexAttribArray(shader->color_attrib);
	glVertexAttribPointer(shader->color_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(vbo_vertex), (void*)offsetof(vbo_vertex, color));

	glDrawArrays(GL_TRIANGLES, 0, vertices.size());
}

void VBO::toScreen(float x, float y, float rot, float scalex, float scaley) {
	mat4 model = mat4();
	model = glm::translate(model, glm::vec3(x, y, 0));
	model = glm::rotate(model, rot, glm::vec3(0, 0, 1));
	model = glm::scale(model, glm::vec3(scalex, scaley, 1));
	toScreen(model);
}
