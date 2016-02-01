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
#include <algorithm>

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

DisplayList* getDisplayList(RendererGL *container, GLuint tex, shader_type *shader) {
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
		dl->sub = NULL;

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

RendererGL::RendererGL() : RendererGL(screen->w / screen_zoom, screen->h / screen_zoom) {}
RendererGL::RendererGL(int w, int h) : DORContainer() {
	glGenBuffers(1, &vbo_elements);
	view = glm::ortho(0.f, (float)w, (float)h, 0.f, -1001.f, 1001.f);
}
RendererGL::~RendererGL() {
	glDeleteBuffers(1, &vbo_elements);
}

void DORVertexes::render(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	cur_model *= model;
	cur_color *= color;
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
		dest[di].color = cur_color * dest[di].color;
	}

	resetChanged();
}

void DORVertexes::renderZ(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	cur_model *= model;
	cur_color *= color;

	// Make sure we do not have to reallocate each step
	int nb = vertices.size();
	int startat = container->zvertices.size();
	container->zvertices.resize(startat + nb);

	// Copy & apply the model matrix
	vertex *src = vertices.data();
	sortable_vertex *dest = container->zvertices.data();
	for (int di = startat, si = 0; di < startat + nb; di++, si++) {
		dest[di].sub = NULL;
		dest[di].tex = tex;
		dest[di].shader = shader;
		dest[di].v.tex = src[si].tex;
		dest[di].v.color = cur_color * src[si].color;
		dest[di].v.pos = cur_model * src[si].pos;
	}

	resetChanged();
}

void DORContainer::render(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	cur_model *= model;
	cur_color *= color;
	for (auto it = dos.begin() ; it != dos.end(); ++it) {
		DisplayObject *i = dynamic_cast<DisplayObject*>(*it);
		if (i) i->render(container, cur_model, cur_color);
	}
	resetChanged();
}

void DORContainer::renderZ(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	cur_model *= model;
	cur_color *= color;
	for (auto it = dos.begin() ; it != dos.end(); ++it) {
		DisplayObject *i = dynamic_cast<DisplayObject*>(*it);
		if (i) i->renderZ(container, cur_model, cur_color);
	}
	resetChanged();
}

void RendererGL::render(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	this->use_model = cur_model * model;
	this->use_color = cur_color * color;
	current_used_dl = NULL; // Needed to make sure we break texture chaining
	auto dl = getDisplayList(container, 0, NULL);
	current_used_dl = NULL; // Needed to make sure we break texture chaining
	dl->sub = this;
	// resetChanged();
}

void RendererGL::renderZ(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	this->use_model = cur_model * model;
	this->use_color = cur_color * color;
	int startat = container->zvertices.size();
	container->zvertices.resize(startat + 1);
	sortable_vertex *dest = container->zvertices.data();
	dest[startat].sub = this;
	// resetChanged();
}

static bool zSorter(const sortable_vertex &i, const sortable_vertex &j) {
	if (i.v.pos.z == j.v.pos.z) {
		if (i.shader == j.shader) return i.tex < j.tex;
		else return i.shader < j.shader;
	} else {
		return i.v.pos.z < j.v.pos.z;
	}
}

void RendererGL::sortedToDL() {
	GLuint tex = 0;
	shader_type *shader = NULL;
	DisplayList *dl = NULL;

	// Make sure we do not have to reallocate each step
	int nb = zvertices.size();
	int startat = -1;

	for (auto v = zvertices.begin(); v != zvertices.end(); v++) {
		if (v->sub) {
			current_used_dl = NULL; // Needed to make sure we break texture chaining
			dl = getDisplayList(this, 0, NULL);
			current_used_dl = NULL; // Needed to make sure we break texture chaining
			dl->sub = v->sub;
			dl = NULL;
		} else {
			if (!dl || (tex != v->tex) || (shader != v->shader)) {
				tex = v->tex; shader = v->shader;
				dl = getDisplayList(this, tex, shader);
				startat = dl->list.size();
				dl->list.reserve(startat + nb); // Meh; will probably reserve way too much. but meh
			}
			dl->list.push_back(v->v);
		}
	}
}

void RendererGL::update() {
	// Release currently owned display lists
	for (auto dl = displays.begin() ; dl != displays.end(); ++dl) { releaseDisplayList(*dl); }
	displays.clear();

	// Build up the new display lists
	mat4 cur_model = mat4();
	if (zsort) {
		zvertices.clear();
		for (auto it = dos.begin() ; it != dos.end(); ++it) {
			DisplayObject *i = dynamic_cast<DisplayObject*>(*it);
			if (i) i->renderZ(this, cur_model, color);
		}
		stable_sort(zvertices.begin(), zvertices.end(), zSorter);

		sortedToDL();
	} else {
		for (auto it = dos.begin() ; it != dos.end(); ++it) {
			DisplayObject *i = dynamic_cast<DisplayObject*>(*it);
			if (i) i->render(this, cur_model, color);
		}
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

void RendererGL::toScreen() {
	vec4 color = {1.0, 1.0, 1.0, 1.0};
	toScreen(mat4(), color);
}

void RendererGL::toScreen(mat4 cur_model, vec4 cur_color) {
	if (changed) update();

	cur_model = cur_model * model;
	mat4 mvp = view * cur_model;
	cur_color = cur_color * color;

	if (cutting) {
		glEnable(GL_SCISSOR_TEST);
		glScissor(cutsize.x, cutsize.y, cutsize.z, cutsize.w);
	} else {
		glDisable(GL_SCISSOR_TEST);
	}

	// Bind the indices
	// printf("=r= binding vbo_elements %d\n", vbo_elements);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_elements);

	// Draw all display lists
	// printf("=r= drawing %d lists\n", displays.size());
	for (auto dl = displays.begin() ; dl != displays.end(); ++dl) {
		if ((*dl)->sub) {
			(*dl)->sub->toScreen(cur_model * (*dl)->sub->use_model, cur_color * (*dl)->sub->use_color);
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_elements);
			if (cutting) {
				glEnable(GL_SCISSOR_TEST);
				glScissor(cutsize.x, cutsize.y, cutsize.z, cutsize.w);
			}
		} else {
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
				glUniform4fv(shader->p_color, 1, glm::value_ptr(cur_color));
			}

			if (shader->p_mvp != -1) {
				glUniformMatrix4fv(shader->p_mvp, 1, GL_FALSE, glm::value_ptr(mvp));
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
	}

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);

	if (cutting) {
		glDisable(GL_SCISSOR_TEST);
	}
}
