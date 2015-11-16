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

#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"
#include "glm/ext.hpp"

using namespace glm;

#include "RendererState.hpp"
#include "RendererGL.hpp"
#include "displayobjects/Renderer.hpp"

class RendererGL : public Renderer {
private:
	RendererState state;
	GLuint *vbo_elements_data = NULL;
	GLuint vbo_elements = 0;
	int vbo_elements_nb = 0;

	GLuint vbo;
	GLuint mode;
	GLenum kind;

public:
	RendererGL();
	~RendererGL();

	RendererGL::update();
	virtual void render(DisplayObject *dob);

};

#endif
