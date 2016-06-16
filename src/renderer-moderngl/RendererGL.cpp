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

void stopDisplayList() {
	current_used_dl = NULL;
}

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

/***************************************************************************
 ** SubRenderer
 ***************************************************************************/

void SubRenderer::cloneInto(DisplayObject* _into) {
	DORContainer::cloneInto(_into);
	SubRenderer *into = dynamic_cast<SubRenderer*>(_into);
	into->use_model = use_model;
	into->use_color = use_color;
}

void SubRenderer::render(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	if (!visible) return;
	this->use_model = cur_model * model;
	this->use_color = cur_color * color;
	stopDisplayList(); // Needed to make sure we break texture chaining
	auto dl = getDisplayList(container, 0, NULL);
	stopDisplayList(); // Needed to make sure we break texture chaining
	dl->sub = this;
	// resetChanged();
}

void SubRenderer::renderZ(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	if (!visible) return;
	this->use_model = cur_model * model;
	this->use_color = cur_color * color;
	int startat = container->zvertices.size();
	container->zvertices.resize(startat + 1);
	sortable_vertex *dest = container->zvertices.data();
	dest[startat].sub = this;
	// resetChanged();
}

void SubRenderer::toScreenSimple() {
	vec4 color = {1.0, 1.0, 1.0, 1.0};
	toScreen(mat4(), color);
}

/***************************************************************************
 ** DORCallback class
 ***************************************************************************/
void DORCallback::cloneInto(DisplayObject* _into) {
	SubRenderer::cloneInto(_into);
	DORCallback *into = dynamic_cast<DORCallback*>(_into);
	if (L && cb_ref) {
		lua_rawgeti(L, LUA_REGISTRYINDEX, cb_ref);
		into->cb_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	}
}

void DORCallback::toScreen(mat4 cur_model, vec4 color) {
}

/***************************************************************************
 ** RendererGL class
 ***************************************************************************/

RendererGL::RendererGL() : RendererGL(screen->w / screen_zoom, screen->h / screen_zoom) {}
RendererGL::RendererGL(int w, int h) {
	glGenBuffers(1, &vbo_elements);
	this->w = w;
	this->h = h;
	view = glm::ortho(0.f, (float)w, (float)h, 0.f, -1001.f, 1001.f);
}
RendererGL::~RendererGL() {
	enablePostProcessing(false);
	glDeleteBuffers(1, &vbo_elements);
}

DisplayObject* RendererGL::clone() {
	RendererGL *into = new RendererGL(w, h);
	this->cloneInto(into);
	return into;
}
void RendererGL::cloneInto(DisplayObject* _into) {
	SubRenderer::cloneInto(_into);
	RendererGL *into = dynamic_cast<RendererGL*>(_into);

	into->mode = mode;
	into->kind = kind;

	into->view = view;

	into->zsort = zsort;
	into->cutting = cutting;
	into->cutpos1 = cutpos1;
	into->cutpos2 = cutpos2;

	if (post_processing) {
		into->enablePostProcessing(true);
		for (auto it = post_process_shaders.begin(); it != post_process_shaders.end(); it++) {
			into->addPostProcessShader(*it);
		}
	}
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
			stopDisplayList(); // Needed to make sure we break texture chaining
			dl = getDisplayList(this, 0, NULL);
			stopDisplayList(); // Needed to make sure we break texture chaining
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

void RendererGL::enablePostProcessing(bool v) {
	post_processing = v;
	if (v) {
		glGenFramebuffers(2, post_process_fbos);
		glGenTextures(2, post_process_textures);
		for (int i = 0; i < 2; i++) {
			tglBindFramebuffer(GL_FRAMEBUFFER, post_process_fbos[i]);
			tfglBindTexture(GL_TEXTURE_2D, post_process_textures[i]);
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8,  w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, post_process_textures[i], 0);
		}
		tglBindFramebuffer(GL_FRAMEBUFFER, 0);
	} else {
		for (int i = 0; i < 2; i++) {
			tglBindFramebuffer(GL_FRAMEBUFFER, post_process_fbos[i]);
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, 0, 0);
		}
		tglBindFramebuffer(GL_FRAMEBUFFER, 0);

		glDeleteTextures(2, post_process_textures);
		glDeleteFramebuffers(2, post_process_fbos);
	}
}

void RendererGL::clearPostProcessShaders() {
	post_process_shaders.clear();
}

// DGDGDGDG: test & finish post processing
void RendererGL::addPostProcessShader(shader_type *s) {
	post_process_shaders.push_back(s);
}

void RendererGL::activateCutting(mat4 cur_model, bool v) {
	if (v) {
		glEnable(GL_SCISSOR_TEST);
		vec4 cut1 = cur_model * cutpos1;
		vec4 cut2 = cur_model * cutpos2;
		cut2 -= cut1;
		glScissor(cut1.x, screen->h / screen_zoom - cut1.y - cut2.y, cut2.x, cut2.y);
	} else {
		glDisable(GL_SCISSOR_TEST);
	}
}

void RendererGL::toScreen(mat4 cur_model, vec4 cur_color) {
	if (!visible) return;

	if (changed) update();

	cur_model = cur_model * model;
	mat4 mvp = view * cur_model;
	cur_color = cur_color * color;

	if (cutting) activateCutting(cur_model, true);
	else glDisable(GL_SCISSOR_TEST);

	// Bind the indices
	// printf("=r= binding vbo_elements %d\n", vbo_elements);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_elements);

	// Draw all display lists
	// printf("=r= drawing %d lists\n", displays.size());
	for (auto dl = displays.begin() ; dl != displays.end(); ++dl) {
		if ((*dl)->sub) {
			(*dl)->sub->toScreen(cur_model * (*dl)->sub->use_model, cur_color * (*dl)->sub->use_color);
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_elements);
			if (cutting) activateCutting(cur_model, true);
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