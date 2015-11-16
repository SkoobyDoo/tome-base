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
void setuptestgl();
void displaytestgl();
}

#include "renderer-moderngl/RendererGL.hpp"

DisplayObjectGL::DisplayObjectGL() {
	glGenBuffers(1, &vbo);
	mode = GL_DYNAMIC_DRAW;
	kind = GL_TRIANGLES;
	// if (mode == VERTEX_STATIC) mode = GL_STATIC_DRAW;
	// if (mode == VERTEX_DYNAMIC) mode = GL_DYNAMIC_DRAW;
	// if (mode == VERTEX_STREAM) mode = GL_STREAM_DRAW;
	// if (kind == VO_POINTS) kind = GL_POINTS;
	// if (kind == VO_QUADS) kind = GL_TRIANGLES;
	// if (kind == VO_TRIANGLE_FAN) kind = GL_TRIANGLE_FAN;
}

DisplayObjectGL::~DisplayObjectGL() {
	glDeleteBuffers(1, &vbo);
}

RendererGL::RendererGL() : Renderer(), DORContainer() {
	glGenBuffers(1, &vbo_elements);
	state = new RendererState(screen->w, screen->h);
}
RendererGL::~RendererGL() {
	glDeleteBuffers(1, &vbo_elements);
	delete state;
}

void DORVertexes::render(RendererGL *renderer) {
	DisplayList &dl = renderer->getDisplayList(tex, shader);
	dl.list.insert(std::end(dl.list), std::begin(this->vertices), std::end(this->vertices));
	resetChanged();
}

void DORContainer::render(RendererGL *renderer) {
	for (vector<DisplayObject*>::iterator it = dos.begin() ; it != dos.end(); ++it) {
		DisplayObjectGL *i = dynamic_cast<DisplayObjectGL*>(*it);
		if (i) i->render(renderer);
	}
	resetChanged();
}

void RendererGL::render() {
	displays.clear();
	DORContainer::render(this);
	resetChanged();
}

void RendererGL::update() {
	// Update the vertices
	render();

	// Update the indices
	// if (vx->kind == VO_QUADS)
	{
		int nb_quads = 0;
		for (auto it = displays.begin() ; it != displays.end(); ++it) {
			if (it->list.size() > nb_quads) nb_quads = it->list.size();
		}
		nb_quads /= 4;
		printf("max quads %d\n", nb_quads);

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
		}

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_elements);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(GLuint) * vbo_elements_nb * 6, NULL, GL_DYNAMIC_DRAW);
		glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, 0, sizeof(GLuint) * vbo_elements_nb * 6, vbo_elements_data);
	}
}

DisplayList& RendererGL::getDisplayList() {
	if (!displays.size()) displays.push_back(DisplayList());
	return displays[displays.size()-1];
}

DisplayList& RendererGL::getDisplayList(GLuint tex, shader_type *shader) {
	if (!displays.size()) {
		displays.push_back(DisplayList());
		DisplayList &dl = displays[displays.size()-1];
		dl.tex = tex;
		dl.shader = shader;
		printf("New DL for %d / %x\n", tex, shader);
	}
	DisplayList &dl = displays[displays.size()-1];

	if (dl.tex != tex || dl.shader != shader) {
		displays.push_back(DisplayList());
		DisplayList &ndl = displays[displays.size()-1];
		ndl.tex = tex;
		ndl.shader = shader;
		printf("New DL for %d / %x\n", tex, shader);
		return ndl;
	} else {
		return dl;
	}
}

void RendererGL::toScreen(float x, float y, float r, float g, float b, float a) {
	if (changed) update();

 	state->translate(x, y, 0);

	// Bind the indices
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_elements);

	// Draw all display lists
	for (auto dl = displays.begin() ; dl != displays.end(); ++dl) {
		// Bind the vertices
		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		printf("REBUILDING THE VBO EACH TIME, FIX ME! WE WANT ONE VBO PER DISPLAY LSIT BUT IN A SMART WAY ...\n");
		glBufferData(GL_ARRAY_BUFFER, sizeof(vertex) * dl->list.size(), NULL, mode);
		glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vertex) * dl->list.size(), dl->list.data());

	 	tglBindTexture(GL_TEXTURE_2D, dl->tex);

		shader_type *shader = dl->shader;
		if (!shader) {
			useNoShader();
			if (!current_shader) return;
		} else {
			tglUseProgramObject(shader->shader);
			current_shader = default_shader;
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
			state->updateMVP(true);
			glUniformMatrix4fv(shader->p_mvp, 1, GL_FALSE, glm::value_ptr(state->mvp));
		}

		glEnableVertexAttribArray(shader->vertex_attrib);
		glVertexAttribPointer(shader->vertex_attrib, 2, GL_FLOAT, GL_FALSE, sizeof(vertex), (void*)0);
		if (shader->texcoord_attrib != -1) {
			glEnableVertexAttribArray(shader->texcoord_attrib);
			glVertexAttribPointer(shader->texcoord_attrib, 2, GL_FLOAT, GL_FALSE, sizeof(vertex), (void*)offsetof(vertex, tex));
		}
		if (shader->color_attrib != -1) {
			glEnableVertexAttribArray(shader->color_attrib);
			glVertexAttribPointer(shader->color_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(vertex), (void*)offsetof(vertex, color));
		}

		glDrawElements(kind, dl->list.size() / 4 * 6, GL_UNSIGNED_INT, (void*)0);

		glDisableVertexAttribArray(shader->vertex_attrib);
		glDisableVertexAttribArray(shader->texcoord_attrib);
		glDisableVertexAttribArray(shader->color_attrib);
	}

	glBindBuffer(GL_ARRAY_BUFFER, 0);

	state->translate(-x, -y, 0);
}

static RendererGL *r;
void setuptestgl() {
	DORVertexes *v1 = new DORVertexes();
	v1->setTexture(1);
	v1->addQuad(
		100, 100, 0, 0,
		200, 100, 0, 1,
		200, 200, 1, 0,
		100, 200, 1, 1,
		1, 1, 1, 1
	);

	DORVertexes *v2 = new DORVertexes();
	v2->setTexture(2);
	v2->addQuad(
		200, 100, 0, 0,
		300, 100, 0, 1,
		300, 200, 1, 0,
		200, 200, 1, 1,
		1, 1, 1, 1
	);

	DORVertexes *v3 = new DORVertexes();
	v3->setTexture(2);
	v3->addQuad(
		300, 100, 0, 0,
		400, 100, 0, 1,
		400, 200, 1, 0,
		300, 200, 1, 1,
		1, 1, 1, 1
	);

	r = new RendererGL();
	r->add(v1);
	r->add(v2);
	r->add(v3);
}
void displaytestgl() {
	r->toScreen(0, 0, 1, 1, 1, 1);
}