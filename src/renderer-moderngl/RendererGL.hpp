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

#ifndef RENDERER_GL_H
#define RENDERER_GL_H

#include "renderer-moderngl/Renderer.hpp"

class RendererGL;

typedef struct {
	vertex v;
	GLuint tex;
	shader_type *shader;
	RendererGL *sub;
} sortable_vertex;

/****************************************************************************
 ** Display lists contain a VBO, texture, ... and a list of vertices to be
 ** drawn; those dont change and dont get recomputed until needed
 ****************************************************************************/
class DisplayList {
public:
	int used = 0;
	GLuint vbo = 0;
	GLuint tex = 0;
	shader_type *shader = NULL;
	vector<vertex> list;
	RendererGL *sub = NULL;

	DisplayList();
	~DisplayList();
};

/****************************************************************************
 ** Handling actual rendering to the screen & such
 ****************************************************************************/
class RendererGL : public DORContainer {
	friend class DORVertexes;
private:
	GLuint mode = GL_DYNAMIC_DRAW;
	GLenum kind = GL_TRIANGLES;

	mat4 view;

	GLuint *vbo_elements_data = NULL;
	GLuint vbo_elements = 0;
	int vbo_elements_nb = 0;
	bool zsort = false;
	vector<DisplayList*> displays;
	int nb_quads = 0;

	bool cutting = false;
	vec4 cutsize;

	vector<sortable_vertex> zvertices;

public:
	RendererGL();
	RendererGL(int w, int h);
	virtual ~RendererGL();

	virtual void addDisplayList(DisplayList* dl) {
		displays.push_back(dl);
	}

	void cutoff(float x, float y, float w, float h) { cutting = true; y = screen->h / screen_zoom - y - h; cutsize = vec4(x, y, w, h); };
	void zSorting(bool sort) { zsort = sort; };
	void sortedToDL();
	void update();
	void toScreen(mat4 cur_model, vec4 color);
	void toScreen();

	virtual void render(RendererGL *container, mat4 cur_model, vec4 color);
	virtual void renderZ(RendererGL *container, mat4 cur_model, vec4 color);
};

#endif
