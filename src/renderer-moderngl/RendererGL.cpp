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

#include "renderer-moderngl/Renderer.hpp"
#include <algorithm>

extern "C" {
       #include <sys/time.h>
       // #include <unistd.h>
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
	return getDisplayList(container, {0,0,0}, NULL, VERTEX_BASE, RenderKind::QUADS);
}
DisplayList* getDisplayList(RendererGL *container, array<GLuint, DO_MAX_TEX> tex, shader_type *shader, uint8_t data_kind, RenderKind render_kind) {
	if (available_dls.empty()) {
		available_dls.push(new DisplayList());
	}

	// printf("test::: %d ?? %d ::: %lx ?? %lx\n", current_used_dl ? current_used_dl->tex : 0 ,tex, current_used_dl ? current_used_dl->shader : 0 ,shader);
	if (current_used_dl && current_used_dl->tex == tex && current_used_dl->shader == shader && current_used_dl_container == container && current_used_dl->data_kind == data_kind && current_used_dl->render_kind == render_kind) {
		// printf("Reussing current DL! %x with %d, %d, %x\n", current_used_dl, current_used_dl->vbo, current_used_dl->tex[0], current_used_dl->shader);
		// current_used_dl->used++;
		// container->addDisplayList(current_used_dl);
		return current_used_dl;
	}

	DisplayList *dl = available_dls.top();
	available_dls.pop();
	dl->tex = tex;
	dl->shader = shader;
	dl->data_kind = data_kind;
	dl->render_kind = render_kind;
	// printf("Getting DL! %x with %d, %d, %x\n", dl, dl->vbo, tex, shader);
	dl->used++;
	current_used_dl = dl;
	current_used_dl_container = container;
	container->addDisplayList(dl);
	return dl;
}
void releaseDisplayList(DisplayList *dl) {
	dl->used--;
	// printf("Releasing DL! %x with %d, %d, %x; used %d times\n", dl, dl->vbo[0], dl->tex, dl->shader, dl->used);
	if (dl->used <= 0) {
		// Clear will nto release the memory, just "forget" about the data
		// we keep the VBO allocated for later
		dl->list.clear();
		dl->list_kind_info.clear();
		dl->list_map_info.clear();
		dl->list_model_info.clear();
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
	glGenBuffers(4, vbo);
	list.reserve(4096);
	// printf("Making new DL! %x with vbo %d\n", this, vbo);
}
// This really should never be actually used
DisplayList::~DisplayList() {
	// printf("Deleteing DL! %x with vbo %d\n", this, vbo);
	glDeleteBuffers(4, vbo);
}

/***************************************************************************
 ** RendererGL class
 ***************************************************************************/

RendererGL::RendererGL(VBOMode mode) {
	this->mode = mode;
	glGenBuffers(1, &vbo_elements);
}
RendererGL::~RendererGL() {
	glDeleteBuffers(1, &vbo_elements);
	refcleaner(&my_default_shader_lua_ref);
}

DisplayObject* RendererGL::clone() {
	RendererGL *into = new RendererGL(mode);
	this->cloneInto(into);
	return into;
}
void RendererGL::cloneInto(DisplayObject* _into) {
	SubRenderer::cloneInto(_into);
	RendererGL *into = dynamic_cast<RendererGL*>(_into);

	into->mode = mode;

	into->zsort = zsort;
	into->cutting = cutting;
	into->cutpos1 = cutpos1;
	into->cutpos2 = cutpos2;
}

void RendererGL::setShader(shader_type *s, int lua_ref) {
	refcleaner(&my_default_shader_lua_ref);
	my_default_shader = s;
	my_default_shader_lua_ref = lua_ref;
}

// bool sortable_vertex::operator<(const sortable_vertex &i) const {
// 	if (v.pos.z == i.v.pos.z) {
// 		if (shader == i.shader) return tex < i.tex;
// 		else return shader < i.shader;
// 	} else {
// 		return v.pos.z < i.v.pos.z;
// 	}
// }

static bool sort_dos(DORFlatSortable *i, DORFlatSortable *j) {
	if (i->sort_z == j->sort_z) {
		if (i->sort_shader == j->sort_shader) return i->sort_tex < j->sort_tex;
		else return i->sort_shader < j->sort_shader;
	} else {
		return i->sort_z < j->sort_z;
	}
}

void RendererGL::sortedToDL() {
	// array<GLuint, DO_MAX_TEX> tex {{0,0,0}};
	// shader_type *shader = NULL;
	// DisplayList *dl = NULL;

	// // Make sure we do not have to reallocate each step
	// int nb = zvertices.size();
	// int startat = -1;

	// for (auto v = zvertices.begin(); v != zvertices.end(); v++) {
	// 	if (v->sub) {
	// 		stopDisplayList(); // Needed to make sure we break texture chaining
	// 		dl = getDisplayList(this);
	// 		stopDisplayList(); // Needed to make sure we break texture chaining
	// 		dl->sub = v->sub;
	// 		dl = NULL;
	// 	} else if (v->tick) {
	// 		stopDisplayList(); // Needed to make sure we break texture chaining
	// 		dl = getDisplayList(this);
	// 		stopDisplayList(); // Needed to make sure we break texture chaining
	// 		dl->tick = v->tick;
	// 		dl = NULL;
	// 	} else {
	// 		if (!dl || (tex != v->tex) || (shader != v->shader)) {
	// 			tex = v->tex; shader = v->shader;
	// 			dl = getDisplayList(this, tex, shader);
	// 			startat = dl->list.size();
	// 			dl->list.reserve(startat + nb); // Meh; will probably reserve way too much. but meh
	// 		}
	// 		dl->list.push_back(v->v);
	// 	}
	// }
}

void RendererGL::resetDisplayLists() {
	// Release currently owned display lists
	for (auto dl = displays.begin() ; dl != displays.end(); ++dl) { releaseDisplayList(*dl); }
	displays.clear();
}

// DGDGDGDG: make that (optionally?) process in a second thread; making it nearly costless
void RendererGL::update() {
	// printf("Renderer %s needs updating\n", getRendererName());

	if (!manual_dl_management) {
		resetDisplayLists();

		// Build up the new display lists
		mat4 cur_model = mat4();
		if (zsort == SortMode::NO_SORT || zsort == SortMode::GL) {
			for (auto it = dos.begin() ; it != dos.end(); ++it) {
				DisplayObject *i = dynamic_cast<DisplayObject*>(*it);
				if (i) i->render(this, cur_model, color, true);
			}
		} else if (zsort == SortMode::FAST) {
			// If nothing that can alter sort order changed, we can just quickly recompute the DisplayLists just like in the no sort method
			if (recompute_fast_sort) {
				recompute_fast_sort = false;
				// printf("FST SORT\n");
				sorted_dos.clear();

				// First we iterate over the DOs tree to "flatten" in
				for (auto it = dos.begin() ; it != dos.end(); ++it) {
					DisplayObject *i = dynamic_cast<DisplayObject*>(*it);
					if (i) i->sortZ(this, cur_model);
				}

				// Now we sort the flattened tree. This is awy faster than the full sort mode because here we sort DOs instead of vertices
				// Also since we are not sorting vertices we likely dont need to use a stable sort -- DGDGDGDG: don't we ?
				sort(sorted_dos.begin(), sorted_dos.end(), sort_dos);
			}

			// And now we can iterate the sorted flattened tree and render as a normal no sort render
			// printf("FST redraw\n");
			for (auto it = sorted_dos.begin() ; it != sorted_dos.end(); ++it) {
				DORFlatSortable *i = dynamic_cast<DORFlatSortable*>(*it);
				if (i && i->parent) {
					recomputematrix cur = i->parent->computeParentCompositeMatrix(this, {cur_model, color, true});
					i->render(this, cur.model, cur.color, cur.visible);
				}
			}
		} else if (zsort == SortMode::FULL) {
			printf("[RendererGL] ERROR! SortMode::FULL CURRENTLY UNSUPPORTED\n");
			// zvertices.clear();
			// for (auto it = dos.begin() ; it != dos.end(); ++it) {
			// 	DisplayObject *i = dynamic_cast<DisplayObject*>(*it);
			// 	if (i) i->renderZ(this, cur_model, color, true);
			// }
			// stable_sort(zvertices.begin(), zvertices.end());

			// sortedToDL();
		}

		// Notify we dont need to be rebuilt again unless more stuff changes
	}
	resetChanged();
	changed_children = false;

	// Upload each display list vertices data to the corresponding VBO on the GPU memory
	int nb_quads = 0;
	bool uses_elements_vbo = false;
	for (auto dl = displays.begin() ; dl != displays.end(); ++dl) {
		if (!(*dl)->sub && !(*dl)->tick) {
			if ((*dl)->list.size() > nb_quads) nb_quads = (*dl)->list.size();

			if ((*dl)->render_kind == RenderKind::QUADS) uses_elements_vbo = true;

			// printf("REBUILDING THE VBO %d with %d elements of size %dko...\n", (*dl)->vbo, (*dl)->list.size(), sizeof(vertex) * (*dl)->list.size() / 1024);
			glBindBuffer(GL_ARRAY_BUFFER, (*dl)->vbo[0]);
			glBufferData(GL_ARRAY_BUFFER, sizeof(vertex) * (*dl)->list.size(), NULL, (GLuint)mode);
			glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vertex) * (*dl)->list.size(), (*dl)->list.data());

			if ((*dl)->data_kind & VERTEX_KIND_INFO) {
				glBindBuffer(GL_ARRAY_BUFFER, (*dl)->vbo[1]);
				glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_kind_info) * (*dl)->list_kind_info.size(), NULL, (GLuint)mode);
				glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vertex_kind_info) * (*dl)->list_kind_info.size(), (*dl)->list_kind_info.data());				
			}
			if ((*dl)->data_kind & VERTEX_MAP_INFO) {
				glBindBuffer(GL_ARRAY_BUFFER, (*dl)->vbo[2]);
				glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_map_info) * (*dl)->list_map_info.size(), NULL, (GLuint)mode);
				glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vertex_map_info) * (*dl)->list_map_info.size(), (*dl)->list_map_info.data());				
			}
			if ((*dl)->data_kind & VERTEX_MODEL_INFO) {
				glBindBuffer(GL_ARRAY_BUFFER, (*dl)->vbo[3]);
				glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_model_info) * (*dl)->list_model_info.size(), NULL, (GLuint)mode);
				glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vertex_model_info) * (*dl)->list_model_info.size(), (*dl)->list_model_info.data());				
			}
		}
	}

	// Update the indices
	if (uses_elements_vbo) {
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

bool ok =true;
void RendererGL::toScreen(mat4 cur_model, vec4 cur_color) {
	if (!visible) return;
	if (changed_children) update();
	if (displays.empty()) return;
	// printf("Displaying renderer %s with %d\n", getRendererName(), displays.size());

	long int start_time;
	int nb_draws_start;
	if (count_time) start_time = SDL_GetTicks();
	if (count_draws) {
		nb_draws_start = nb_draws;
	}

	cur_model = cur_model * model; // This is .. undeeded ..??
	mat4 mvp = (view ? view->get() : View::getCurrent()->get()) * cur_model;
	cur_color = cur_color * color;

	if (cutting) activateCutting(cur_model, true);
	// else glDisable(GL_SCISSOR_TEST);

	if (zsort == SortMode::GL) glEnable(GL_DEPTH_TEST);
	if (!allow_blending) glDisable(GL_BLEND);
	if (premultiplied_alpha) glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

	// Draw all display lists
	int nb_vert = 0;
	for (auto dl = displays.begin() ; dl != displays.end(); ++dl) {
		if ((*dl)->sub) {
			(*dl)->sub->toScreen(cur_model * (*dl)->sub->use_model, cur_color * (*dl)->sub->use_color);
			if (cutting) activateCutting(cur_model, true);
		} else if ((*dl)->tick) {
			(*dl)->tick->tick();
			if (cutting) activateCutting(cur_model, true);
		} else {
			// Bind the indices
			if ((*dl)->render_kind == RenderKind::QUADS) glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_elements);

			// Bind the vertices
			glBindBuffer(GL_ARRAY_BUFFER, (*dl)->vbo[0]);
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

			if ((*dl)->data_kind & VERTEX_KIND_INFO) {
				glBindBuffer(GL_ARRAY_BUFFER, (*dl)->vbo[1]);
				if (shader->kind_attrib != -1) {
					glEnableVertexAttribArray(shader->kind_attrib);
					glVertexAttribPointer(shader->kind_attrib, 1, GL_FLOAT, GL_FALSE, sizeof(vertex_kind_info), (void*)offsetof(vertex_kind_info, kind));
				}
			}

			if ((*dl)->data_kind & VERTEX_MAP_INFO) {
				glBindBuffer(GL_ARRAY_BUFFER, (*dl)->vbo[2]);
				if (shader->texcoorddata_attrib != -1) {
					glEnableVertexAttribArray(shader->texcoorddata_attrib);
					glVertexAttribPointer(shader->texcoorddata_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(vertex_map_info), (void*)offsetof(vertex_map_info, texcoords));
				}
				if (shader->mapcoord_attrib != -1) {
					glEnableVertexAttribArray(shader->mapcoord_attrib);
					glVertexAttribPointer(shader->mapcoord_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(vertex_map_info), (void*)offsetof(vertex_map_info, mapcoords));
				}
			}

			if ((*dl)->data_kind & VERTEX_MODEL_INFO) {
				glBindBuffer(GL_ARRAY_BUFFER, (*dl)->vbo[3]);
				if (shader->model_attrib != -1) {
					glEnableVertexAttribArray(shader->model_attrib+0);
					glVertexAttribPointer(shader->model_attrib+0, 4, GL_FLOAT, GL_FALSE, sizeof(vertex_model_info), (void*)(offsetof(vertex_model_info, model)));
					glEnableVertexAttribArray(shader->model_attrib+1);
					glVertexAttribPointer(shader->model_attrib+1, 4, GL_FLOAT, GL_FALSE, sizeof(vertex_model_info), (void*)(offsetof(vertex_model_info, model) + sizeof(float) * 4));
					glEnableVertexAttribArray(shader->model_attrib+2);
					glVertexAttribPointer(shader->model_attrib+2, 4, GL_FLOAT, GL_FALSE, sizeof(vertex_model_info), (void*)(offsetof(vertex_model_info, model) + sizeof(float) * 8));
					glEnableVertexAttribArray(shader->model_attrib+3);
					glVertexAttribPointer(shader->model_attrib+3, 4, GL_FLOAT, GL_FALSE, sizeof(vertex_model_info), (void*)(offsetof(vertex_model_info, model) + sizeof(float) * 12));
				}
			}

			if ((*dl)->render_kind == RenderKind::QUADS) {
				glDrawElements(GL_TRIANGLES, (*dl)->list.size() / 4 * 6, GL_UNSIGNED_INT, (void*)0);
			} else if ((*dl)->render_kind == RenderKind::TRIANGLES) {
				glDrawArrays(GL_TRIANGLES, 0, (*dl)->list.size());
			} else if ((*dl)->render_kind == RenderKind::POINTS) {
				glDrawArrays(GL_POINTS, 0, (*dl)->list.size());
			} else if ((*dl)->render_kind == RenderKind::LINES) {
				glLineWidth(line_width);
				if (line_smooth) glEnable(GL_LINE_SMOOTH);
				glDrawArrays(GL_LINES, 0, (*dl)->list.size());
				if (line_smooth) glDisable(GL_LINE_SMOOTH);
			}
			nb_vert += (*dl)->list.size();
		}
	}

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);

	if (zsort == SortMode::GL) glDisable(GL_DEPTH_TEST);
	if (!allow_blending) glEnable(GL_BLEND);
	if (premultiplied_alpha) glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);

	if (cutting) {
		glDisable(GL_SCISSOR_TEST);
	}

	if (count_vertexes) {
		printf("RendererGL<%s> drew %d vertexes in %ld calls\n", renderer_name, nb_vert, displays.size());
	}
	if (count_draws) {
		printf("RendererGL<%s> drew in %d calls\n", renderer_name, nb_draws - nb_draws_start);
	}
	if (count_time) {
		printf("RendererGL<%s> drew in %ld ms\n", renderer_name, SDL_GetTicks() - start_time);
	}
}
