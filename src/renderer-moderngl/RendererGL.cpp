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
#include <algorithm>

extern "C" {
       #include <sys/time.h>
       #include <unistd.h>
}

/**********************************
 ** Permanent VBO/DisplayList store
 ***************************************************************************/

static stack<DisplayList*> available_dls;
static DisplayList* current_used_dl = NULL;
static DORContainer* current_used_dl_container = NULL;

void stopDisplayList() {
	current_used_dl = NULL;
}

DisplayList* getDisplayList(RendererGL *container) {
	return getDisplayList(container, {0,0,0}, NULL);
}
DisplayList* getDisplayList(RendererGL *container, array<GLuint, DO_MAX_TEX> tex, shader_type *shader) {
	if (available_dls.empty()) {
		available_dls.push(new DisplayList());
	}

	// printf("test::: %d ?? %d ::: %lx ?? %lx\n", current_used_dl ? current_used_dl->tex : 0 ,tex, current_used_dl ? current_used_dl->shader : 0 ,shader);
	if (current_used_dl && current_used_dl->tex == tex && current_used_dl->shader == shader && current_used_dl_container == container) {
		// printf("Reussing current DL! %x with %d, %d, %x\n", current_used_dl, current_used_dl->vbo, current_used_dl->tex[0], current_used_dl->shader);
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
	dl->mode = container->mode;
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
		dl->tex = {0,0,0};
		dl->shader = NULL;
		dl->sub = NULL;
		dl->tick = NULL;

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

void DisplayList::update() {
	if (!changed) return;
	// Upload display list vertices data to the corresponding VBO on the GPU memory
	if (!sub && !tick) {
		// printf("REBUILDING THE VBO %d...\n", vbo);
		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glBufferData(GL_ARRAY_BUFFER, sizeof(vertex) * list.size(), NULL, (GLuint)mode);
		glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vertex) * list.size(), list.data());
	}
	changed = false;
}

/***************************************************************************
 ** RendererGL class
 ***************************************************************************/

RendererGL::RendererGL(VBOMode mode) {
	setChanged(ChangedSet::REBUILD);
	setChanged(ChangedSet::RESORT);
	this->mode = mode;
	renderer = this;
	glGenBuffers(1, &vbo_elements);
}
RendererGL::~RendererGL() {
	glDeleteBuffers(1, &vbo_elements);
	if (my_default_shader_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, my_default_shader_lua_ref);
}

DisplayObject* RendererGL::clone() {
	RendererGL *into = new RendererGL(mode);
	this->cloneInto(into);
	return into;
}
void RendererGL::cloneInto(DisplayObject* _into) {
	ISubRenderer::cloneInto(_into);
	RendererGL *into = dynamic_cast<RendererGL*>(_into);

	into->mode = mode;
	into->kind = kind;

	into->zsort = zsort;
	into->cutting = cutting;
	into->cutpos1 = cutpos1;
	into->cutpos2 = cutpos2;
}

void RendererGL::setShader(shader_type *s, int lua_ref) {
	if (my_default_shader_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, my_default_shader_lua_ref);
	my_default_shader = s;
	my_default_shader_lua_ref = lua_ref;
}

bool sortable_vertex::operator<(const sortable_vertex &i) const {
	if (v.pos.z == i.v.pos.z) {
		if (shader == i.shader) return tex < i.tex;
		else return shader < i.shader;
	} else {
		return v.pos.z < i.v.pos.z;
	}
}

static bool sort_dos(DORFlatSortable *i, DORFlatSortable *j) {
	if (i->sort_z == j->sort_z) {
		if (i->sort_shader == j->sort_shader) return i->sort_tex < j->sort_tex;
		else return i->sort_shader < j->sort_shader;
	} else {
		return i->sort_z < j->sort_z;
	}
}

bool RendererGL::usesElementsVBO() {
	return kind == RenderKind::QUADS;
}

void RendererGL::sortedToDL() {
	array<GLuint, DO_MAX_TEX> tex {{0,0,0}};
	shader_type *shader = NULL;
	DisplayList *dl = NULL;

	// Make sure we do not have to reallocate each step
	int nb = zvertices.size();
	int startat = -1;

	for (auto v = zvertices.begin(); v != zvertices.end(); v++) {
		if (v->sub) {
			stopDisplayList(); // Needed to make sure we break texture chaining
			dl = getDisplayList(this);
			stopDisplayList(); // Needed to make sure we break texture chaining
			dl->sub = v->sub;
			dl = NULL;
		} else if (v->tick) {
			stopDisplayList(); // Needed to make sure we break texture chaining
			dl = getDisplayList(this);
			stopDisplayList(); // Needed to make sure we break texture chaining
			dl->tick = v->tick;
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

void RendererGL::resetDisplayLists() {
	// Release currently owned display lists
	for (auto dl = displays.begin() ; dl != displays.end(); ++dl) { releaseDisplayList(*dl); }
	displays.clear();
}
#include <map>
// DGDGDGDG: make that (optionally?) process in a second thread; making it nearly costless
void RendererGL::update() {
	// printf("Renderer %s needs updating: %d %d %d\n", getRendererName(), update_dos.size(), changed[ChangedSet::REBUILD] ? 1 : 0, changed[ChangedSet::RESORT] ? 1 : 0);

	if (!manual_dl_management && changed[ChangedSet::REBUILD]) {
		resetDisplayLists();

		function<void(DisplayObject*)> fct = [this](DisplayObject *o) { o->renderer = this; };
		for (auto &it : dos) { it->traverse(fct); }

		// Build up the new display lists
		mat4 cur_model = mat4();
		if (zsort == SortMode::NO_SORT || zsort == SortMode::GL) {
			for (auto &it : dos) {
				it->updateFull(cur_model, color, true, true);
				it->render(this, cur_model, color, true);
			}
		} else if (zsort == SortMode::FAST) {
			for (auto &it : dos) it->updateFull(cur_model, color, true, true);

			// If nothing that can alter sort order changed, we can just quickly recompute the DisplayLists just like in the no sort method
			if (changed[ChangedSet::RESORT]) {
				// printf("FST SORT\n");
				sorted_dos.clear();

				// First we iterate over the DOs tree to "flatten" in
				for (auto &it : dos) {
					it->sortZ(this, cur_model);
				}

				// Now we sort the flattened tree. This is awy faster than the full sort mode because here we sort DOs instead of vertices
				// Also since we are not sorting vertices we likely dont need to use a stable sort -- DGDGDGDG: don't we ?
				stable_sort(sorted_dos.begin(), sorted_dos.end(), sort_dos);
			}

		long int start_time = SDL_GetTicks();
		printf("===REBUILD== %s\n", getRendererName());
			// And now we can iterate the sorted flattened tree and render as a normal no sort render
			// printf("FST redraw\n");
			for (auto &it : sorted_dos) {
				it->render(this, cur_model, color, true);
			}
		printf("===REBUILD-DONE== %s : %ld\n", getRendererName(), SDL_GetTicks() - start_time);
		} else if (zsort == SortMode::FULL) {
			printf("BOOH NOT DONE\n"); exit(1); // DGDGDGDG
			updateFull(cur_model, color, true, true);
			zvertices.clear();
			for (auto it = dos.begin() ; it != dos.end(); ++it) {
				DisplayObject *i = dynamic_cast<DisplayObject*>(*it);
				if (i) i->renderZ(this, cur_model, color, true);
			}
			stable_sort(zvertices.begin(), zvertices.end());

			sortedToDL();
		}

		update_dos.clear(); // No need to redo them
	}
	resetChanged();

	if (update_dos.size()) {
		// extern int nbcompute;
		// extern std::map<DisplayObject*, int> computemap;
		// long int start_time = SDL_GetTicks();
		// nbcompute = 0;
		// printf("===UPDATE== %s : %d\n", getRendererName(), update_dos.size());
		update_dos_done.clear();
		for (auto &d : update_dos) {
			// printf("__update__: %lx : %s\n", d, d->getKind());
			if (d->parent) d->updateFull(d->parent->computed_model, d->parent->computed_color, d->parent->computed_visible, false);
		}
		update_dos.clear();
		// for (auto &it : computemap) {
			// printf("   -- %lx : %d\n", it.first, it.second);
		// }
		// printf("===UPDATE-DONE== %s : %ld --- %d\n", getRendererName(), SDL_GetTicks() - start_time, nbcompute);
	}

	// Update the indices
	if (usesElementsVBO()) {
		int nb_quads = 0;
		for (auto dl = displays.begin() ; dl != displays.end(); ++dl) {
			if (!(*dl)->sub && !(*dl)->tick) {
				if ((*dl)->list.size() > nb_quads) nb_quads = (*dl)->list.size();
			}
		}

		nb_quads /= 4;
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
			printf("Upping vbo_elements to %d in renderer %s\n", nb_quads, getRendererName());
		}
	}
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

void RendererGL::setChanged(ChangedSet what) {
	switch (what) {
		case ChangedSet::PARENTS:
			break;
		case ChangedSet::CHILDS:
			break;
		case ChangedSet::RESORT:
			changed.set(ChangedSet::RESORT);
		case ChangedSet::REBUILD:
			changed.set(ChangedSet::REBUILD);
			break;
	}
}

void RendererGL::toScreen(mat4 cur_model, vec4 cur_color) {
	if (!visible) return;
	if (changed[ChangedSet::REBUILD] || changed[ChangedSet::RESORT] || update_dos.size()) update();
	if (displays.empty()) return;
	// printf("Displaying renderer %s\n", getRendererName());

	long int start_time;
	if (count_time) start_time = SDL_GetTicks();
	if (count_draws) {
		nb_draws = 0;
	}

	cur_model = cur_model * model; // This is .. undeeded ..??
	mat4 mvp = View::getCurrent()->get() * cur_model;
	cur_color = cur_color * color;

	if (cutting) activateCutting(cur_model, true);
	// else glDisable(GL_SCISSOR_TEST);

	if (zsort == SortMode::GL) glEnable(GL_DEPTH_TEST);
	if (!allow_blending) glDisable(GL_BLEND);
	if (premultiplied_alpha) glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

	// Bind the indices
	if (usesElementsVBO()) glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_elements);

	// Draw all display lists
	int nb_vert = 0;
	for (auto dl = displays.begin() ; dl != displays.end(); ++dl) {
		if ((*dl)->sub) {
			(*dl)->sub->toScreen(cur_model * (*dl)->sub->use_model, cur_color * (*dl)->sub->use_color);
			if (usesElementsVBO()) glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_elements);
			if (cutting) activateCutting(cur_model, true);
		} else if ((*dl)->tick) {
			(*dl)->tick->tick();
			if (usesElementsVBO()) glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_elements);
			if (cutting) activateCutting(cur_model, true);
		} else {
			(*dl)->update();

			// Bind the vertices
			glBindBuffer(GL_ARRAY_BUFFER, (*dl)->vbo);
	 		tglActiveTexture(GL_TEXTURE0);
		 	tglBindTexture(GL_TEXTURE_2D, (*dl)->tex[0]);
		 	for (int i = 1; i < DO_MAX_TEX; i++) { if ((*dl)->tex[i]) {
		 		tglActiveTexture(GL_TEXTURE0 + i);
		 		tglBindTexture(GL_TEXTURE_2D, (*dl)->tex[i]);
		 	} }
			// printf("=r= binding vbo %d\n", (*dl)->vbo);
			// printf("=r= binding tex %d\n", (*dl)->tex);

			shader_type *shader = (*dl)->shader;
			if (!shader) shader = my_default_shader;
			if (!shader) {
				useNoShader();
				if (!current_shader) return;
			} else {
				useShaderSimple(shader);
				current_shader = shader;
			}

			shader = current_shader;
			if (shader->vertex_attrib == -1) return;
			// printf("=r= binding shader %s in renderer %s : %lx (default %lx)\n", shader->name, getRendererName(), shader, default_shader);

			if (shader->p_tick != -1) {
				GLfloat t = cur_frame_tick;
				glUniform1fv(shader->p_tick, 1, &t);
			}

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
			if (shader->texcoorddata_attrib != -1) {
				glEnableVertexAttribArray(shader->texcoorddata_attrib);
				glVertexAttribPointer(shader->texcoorddata_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(vertex), (void*)offsetof(vertex, texcoords));
			}
			if (shader->mapcoord_attrib != -1) {
				glEnableVertexAttribArray(shader->mapcoord_attrib);
				glVertexAttribPointer(shader->mapcoord_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(vertex), (void*)offsetof(vertex, mapcoords));
			}
			if (shader->kind_attrib != -1) {
				glEnableVertexAttribArray(shader->kind_attrib);
				glVertexAttribPointer(shader->kind_attrib, 1, GL_FLOAT, GL_FALSE, sizeof(vertex), (void*)offsetof(vertex, kind));
			}

			if (kind == RenderKind::QUADS) {
				glDrawElements(GL_TRIANGLES, (*dl)->list.size() / 4 * 6, GL_UNSIGNED_INT, (void*)0);
			} else if (kind == RenderKind::TRIANGLES) {
				glDrawArrays(GL_TRIANGLES, 0, (*dl)->list.size());
			}
			nb_vert += (*dl)->list.size();
		}
	}

	if (usesElementsVBO()) glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);

	if (zsort == SortMode::GL) glDisable(GL_DEPTH_TEST);
	if (!allow_blending) glEnable(GL_BLEND);
	if (premultiplied_alpha) glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);

	if (cutting) {
		glDisable(GL_SCISSOR_TEST);
	}

	if (count_vertexes) {
		printf("RendererGL<%s> drew %d vertexes in %d calls\n", renderer_name, nb_vert, displays.size());
	}
	if (count_draws) {
		printf("RendererGL<%s> drew in %d calls\n", renderer_name, nb_draws);
	}
	if (count_time) {
		printf("RendererGL<%s> drew in %d ms\n", renderer_name, SDL_GetTicks() - start_time);
	}
}
