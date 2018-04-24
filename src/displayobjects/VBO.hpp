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
#ifndef VBO_HPP
#define VBO_HPP

extern "C" {
#include "tgl.h"
#include "useshader.h"
}

#include <vector>

#define GLM_FORCE_INLINE
#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"
#include "glm/ext.hpp"

using namespace glm;
using namespace std;

enum class VBOMode : GLenum { DYNAMIC = GL_DYNAMIC_DRAW, STREAM = GL_STREAM_DRAW, STATIC = GL_STATIC_DRAW };

typedef struct {
	vec4 pos;
	vec2 tex;
	vec4 color;
} vbo_vertex;

class VBO {
	VBOMode mode = VBOMode::STATIC;

	vec4 color = {1, 1, 1, 1};

	GLuint vbo = 0, vbo_elements = 0;
	vector<GLuint> textures;
	shader_type *shader = NULL;

	vector<vbo_vertex> vertices;
	vector<GLuint> elements;

	bool changed = true;

	void update();

public:
	VBO();
	VBO(VBOMode mode);
	virtual ~VBO();

	void clear();

	void resetTexture();
	void setTexture(GLuint tex);
	void setTexture(GLuint tex, int pos);
	void setShader(shader_type *shader);
	void setColor(float r, float g, float b, float a);

	int addQuad(
		float x1, float y1, float u1, float v1, 
		float x2, float y2, float u2, float v2, 
		float x3, float y3, float u3, float v3, 
		float x4, float y4, float u4, float v4, 
		float r, float g, float b, float a
	);
	int addQuad(
		float x1, float y1, float z1, float u1, float v1, 
		float x2, float y2, float z2, float u2, float v2, 
		float x3, float y3, float z3, float u3, float v3, 
		float x4, float y4, float z4, float u4, float v4, 
		float r, float g, float b, float a
	);

	void toScreen(mat4 model);
	void toScreen(float x, float y, float rot, float scalex, float scaley);
};

#endif
