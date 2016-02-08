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

class SubRenderer;
class RendererGL;

typedef struct {
	vertex v;
	GLuint tex;
	shader_type *shader;
	SubRenderer *sub;
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
	SubRenderer *sub = NULL;

	DisplayList();
	~DisplayList();
};

/****************************************************************************
 ** Interface to make a DisplayObject be a sub-renderer: breaking chaining
 ** and using it's own render method
 ****************************************************************************/
class SubRenderer : public DORContainer {
	friend class RendererGL;
private:
	vec4 use_color;
	mat4 use_model;

public:
	virtual void render(RendererGL *container, mat4 cur_model, vec4 color);
	virtual void renderZ(RendererGL *container, mat4 cur_model, vec4 color);

	virtual void toScreenSimple();
	virtual void toScreen(mat4 cur_model, vec4 color) = 0;
};

/****************************************************************************
 ** Handling actual rendering to the screen & such
 ****************************************************************************/
class RendererGL : public SubRenderer {
	friend class DORVertexes;
protected:
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
	vec4 cutpos1;
	vec4 cutpos2;

public:
	vector<sortable_vertex> zvertices;

public:
	RendererGL();
	RendererGL(int w, int h);
	virtual ~RendererGL();
	virtual const char* getKind() { return "RendererGL"; };

	virtual void addDisplayList(DisplayList* dl) {
		displays.push_back(dl);
	}

	void cutoff(float x, float y, float w, float h) { cutting = true; cutpos1 = vec4(x, y, 0, 1); cutpos2 = vec4(x + w, y + h, 0, 1); };
	void zSorting(bool sort) { zsort = sort; };
	void sortedToDL();
	void update();
	virtual void toScreen(mat4 cur_model, vec4 color);

	void activateCutting(mat4 cur_model, bool v);
};

#endif
