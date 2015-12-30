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

#include "renderer-moderngl/Renderer.hpp"
extern "C" {
       #include <sys/time.h>
       #include <unistd.h>
}

/***************************************************************************
 ** Permanent VBO/DisplayList store
 ***************************************************************************/

static stack<DisplayList*> available_dls;
static DisplayList* current_used_dl = NULL;
static DORContainer* current_used_dl_container = NULL;

DisplayList* getDisplayList(DORContainer *container, GLuint tex, shader_type *shader) {
	if (available_dls.empty()) {
		available_dls.push(new DisplayList());
	}

	if (current_used_dl && current_used_dl->tex == tex && current_used_dl->shader == shader && current_used_dl_container == container) {
		// printf("Reussing current DL! %x with %d, %d, %x\n", current_used_dl, current_used_dl->vbo, current_used_dl->tex, current_used_dl->shader);
		// current_used_dl->used++;
		// container->addDisplayList(current_used_dl);
		return current_used_dl;
	}

	DisplayList *dl = available_dls.top();
	available_dls.pop();
	dl->tex = tex;
	dl->shader = shader;
	// printf("Getting DL! %x with %d, %d, %x\n", dl, dl->vbo, tex, shader);
	dl->used++;
	current_used_dl = dl;
	current_used_dl_container = container;
	container->addDisplayList(dl);
	return dl;
}
void releaseDisplayList(DisplayList *dl) {
	// printf("Releasing DL! %x with %d, %d, %x; used %d times\n", dl, dl->vbo, dl->tex, dl->shader, dl->used);
	dl->used--;
	if (dl->used <= 0) {
		// Clear will nto release the memory, just "forget" about the data
		// we keep the VBO allocated for later
		dl->list.clear();
		dl->tex = 0;
		dl->shader = NULL;

		available_dls.push(dl);
		if (current_used_dl == dl) {
			current_used_dl = NULL;
			current_used_dl_container = NULL;
		}
	}
}

DisplayList::DisplayList() {
	glGenBuffers(1, &vbo);
	// printf("Making new DL! %x with vbo %d\n", this, vbo);
}
// This really should never be actually used
DisplayList::~DisplayList() {
	// printf("Deleteing DL! %x with vbo %d\n", this, vbo);
	glDeleteBuffers(1, &vbo);
	vbo = 0;
}


DisplayObjectGL::DisplayObjectGL() {
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
}

RendererGL::RendererGL() : Renderer(), DORContainer() {
	glGenBuffers(1, &vbo_elements);
	state = new RendererState(screen->w, screen->h);
}
RendererGL::RendererGL(int w, int h) : Renderer(), DORContainer() {
	glGenBuffers(1, &vbo_elements);
	state = new RendererState(w, h);
}
RendererGL::~RendererGL() {
	glDeleteBuffers(1, &vbo_elements);
	delete state;
}

void DORVertexes::render(DORContainer *container, mat4 cur_model) {
	cur_model *= model;
	auto dl = getDisplayList(container, tex, shader);

	// Make sure we do not have to reallocate each step
	int nb = vertices.size();
	int startat = dl->list.size();
	dl->list.reserve(startat + nb);

	// Copy & apply the model matrix
	// DG: is it better to first copy it all and then alter it ? most likely not, change me
	dl->list.insert(std::end(dl->list), std::begin(this->vertices), std::end(this->vertices));
	vertex *dest = dl->list.data();
	for (int di = startat; di < startat + nb; di++) {
		dest[di].pos = cur_model * dest[di].pos;
	}

	resetChanged();
}

void DORText::render(DORContainer *container, mat4 cur_model) {
	cur_model *= model;
	auto dl = getDisplayList(container, tex, shader);

	// Make sure we do not have to reallocate each step
	int nb = vertices.size();
	int startat = dl->list.size();
	dl->list.reserve(startat + nb);

	// Copy & apply the model matrix
	// DG: is it better to first copy it all and then alter it ? most likely not, change me
	dl->list.insert(std::end(dl->list), std::begin(this->vertices), std::end(this->vertices));
	vertex *dest = dl->list.data();
	for (int di = startat; di < startat + nb; di++) {
		dest[di].pos = cur_model * dest[di].pos;
	}

	resetChanged();
}

void DORContainer::render(DORContainer *container, mat4 cur_model) {
	cur_model *= model;
	for (auto it = dos.begin() ; it != dos.end(); ++it) {
		DisplayObjectGL *i = dynamic_cast<DisplayObjectGL*>(*it);
		if (i) i->render(container, cur_model);
	}
	resetChanged();
}

void RendererGL::update() {
	// Release currently owned display lists
	for (auto dl = displays.begin() ; dl != displays.end(); ++dl) { releaseDisplayList(*dl); }
	displays.clear();

	// Build up the new display lists
	mat4 cur_model = mat4();
	for (auto it = dos.begin() ; it != dos.end(); ++it) {
		DisplayObjectGL *i = dynamic_cast<DisplayObjectGL*>(*it);
		if (i) i->render(this, cur_model);
	}

	// Notify we dont need to be rebuilt again unless more stuff changes
	resetChanged();

	// Upload each display list vertices data to the corresponding VBO on the GPU memory
	nb_quads = 0;
	for (auto dl = displays.begin() ; dl != displays.end(); ++dl) {
		if ((*dl)->list.size() > nb_quads) nb_quads = (*dl)->list.size();

		// printf("REBUILDING THE VBO %d...\n", (*dl)->vbo);
		glBindBuffer(GL_ARRAY_BUFFER, (*dl)->vbo);
		glBufferData(GL_ARRAY_BUFFER, sizeof(vertex) * (*dl)->list.size(), NULL, mode);
		glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vertex) * (*dl)->list.size(), (*dl)->list.data());
	}
	nb_quads /= 4;
	// printf("max quads %d / %d\n", nb_quads, displays.size());

	// Update the indices
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
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(GLuint) * vbo_elements_nb * 6, NULL, GL_STATIC_DRAW); // Static because this wont change often
		glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, 0, sizeof(GLuint) * vbo_elements_nb * 6, vbo_elements_data);
		printf("Upping vbo_elements to %d\n", nb_quads);
	}
}

void RendererGL::toScreen(float x, float y, float r, float g, float b, float a) {
	if (changed) update();

 	if (x || y) state->translate(x, y, 0);

	// Bind the indices
	// printf("=r= binding vbo_elements %d\n", vbo_elements);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_elements);

	// Draw all display lists
	printf("=r= drawing %d lists\n", displays.size());
	for (auto dl = displays.begin() ; dl != displays.end(); ++dl) {
		// Bind the vertices
		glBindBuffer(GL_ARRAY_BUFFER, (*dl)->vbo);
	 	tglBindTexture(GL_TEXTURE_2D, (*dl)->tex);
		// printf("=r= binding vbo %d\n", (*dl)->vbo);
		// printf("=r= binding tex %d\n", (*dl)->tex);

		shader_type *shader = (*dl)->shader;
		if (!shader) {
			useNoShader();
			if (!current_shader) return;
		} else {
			tglUseProgramObject(shader->shader);
			current_shader = default_shader;
		}

		shader = current_shader;
		if (shader->vertex_attrib == -1) return;
		// printf("=r= binding shader %d\n", current_shader->shader);

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
		glVertexAttribPointer(shader->vertex_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(vertex), (void*)0);
		if (shader->texcoord_attrib != -1) {
			glEnableVertexAttribArray(shader->texcoord_attrib);
			glVertexAttribPointer(shader->texcoord_attrib, 2, GL_FLOAT, GL_FALSE, sizeof(vertex), (void*)offsetof(vertex, tex));
		}
		if (shader->color_attrib != -1) {
			glEnableVertexAttribArray(shader->color_attrib);
			glVertexAttribPointer(shader->color_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(vertex), (void*)offsetof(vertex, color));
		}


		// printf("=r= drawing %d elements\n", (*dl)->list.size() / 4 * 6);
		glDrawElements(kind, (*dl)->list.size() / 4 * 6, GL_UNSIGNED_INT, (void*)0);
		// glDrawArrays(kind, 0, (*dl)->list.size());


		glDisableVertexAttribArray(shader->vertex_attrib);
		glDisableVertexAttribArray(shader->texcoord_attrib);
		glDisableVertexAttribArray(shader->color_attrib);
	}

	glBindBuffer(GL_ARRAY_BUFFER, 0);

	if (x || y) state->translate(-x, -y, 0);
}
