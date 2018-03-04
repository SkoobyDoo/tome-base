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
#ifndef _RENDERER_TER_GL21_H_
#define _RENDERER_TER_GL21_H_

extern "C" {
#include "glew.h"
#include "tgl.h"
}

#include <string>
#include <vector>
#include "renderer/TER.hpp"

using namespace std;

/*****************************************************************
 ** Texture
 *****************************************************************/
class TER_GL21_Texture; using sTER_GL21_Texture = shared_ptr<TER_GL21_Texture>;
class TER_GL21_Texture : public TER_Texture {
public:
	GLuint tex = 0;
	GLenum gl_type = 0, gl_format = 0;

	TER_GL21_Texture(TER_TextureType type, uint16_t w, uint16_t h, bool powerof2=false, bool clamp=false, bool pixelize=false);
	virtual ~TER_GL21_Texture();
	virtual void load(TER_TextureFormat format, const void *data);
};

/*****************************************************************
 ** Shaders
 *****************************************************************/
class TER_GL21_Shader; using sTER_GL21_Shader = shared_ptr<TER_GL21_Shader>;
class TER_GL21_Shader : public TER_Shader {
public:
	GLuint shader = 0;
	TER_ShaderType type;

	TER_GL21_Shader(TER_ShaderType type, const char *code);
	virtual ~TER_GL21_Shader();
};

struct TER_GL21_Program_Binder {
	GLint loc;
	string name;
	TER_BinderType type;

	TER_GL21_Program_Binder(GLint loc, const char *name, GLenum gtype) : loc(loc), name(name) {
		switch (gtype) {
			case GL_FLOAT: type = TER_BinderType::FLOAT; break;
			case GL_FLOAT_VEC2: type = TER_BinderType::VEC2; break;
			case GL_FLOAT_VEC3: type = TER_BinderType::VEC3; break;
			case GL_FLOAT_VEC4: type = TER_BinderType::VEC4; break;
			case GL_SAMPLER_2D: type = TER_BinderType::TEXTURE2D; break;
			default: type = TER_BinderType::ERROR; break;
		}
	}
};

class TER_GL21_Program; using sTER_GL21_Program = shared_ptr<TER_GL21_Program>;
class TER_GL21_Program : public TER_Program {
protected:
	sTER_GL21_Shader vertex;
	sTER_GL21_Shader fragment;
public:
	GLuint program = 0;
	vector<TER_GL21_Program_Binder> attributes;
	vector<TER_GL21_Program_Binder> uniforms;

	TER_GL21_Program(sTER_Shader vertex, sTER_Shader fragment);
	virtual ~TER_GL21_Program();
};

/*****************************************************************
 ** Buffers
 *****************************************************************/
class TER_GL21_VertexBuffer : public TER_VertexBuffer {
public:
};

class TER_GL21_IndexBuffer : public TER_IndexBuffer {
public:
};

/*****************************************************************
 ** Rendering Context
 *****************************************************************/
class TER_GL21_Context : public TER_Context {
public:
};

#endif
