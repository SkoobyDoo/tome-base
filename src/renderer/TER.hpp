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
#ifndef _RENDERER_ABSTRACT_H_
#define _RENDERER_ABSTRACT_H_

#include <memory>
using namespace std;

enum class TER_RendererBackend { GL21 };

/*****************************************************************
 ** Texture
 *****************************************************************/
enum class TER_TextureType { T2D };
enum class TER_TextureFormat { RGBA, RGB, BGR, BGRA };

class TER_Texture; using sTER_Texture = shared_ptr<TER_Texture>;
class TER_Texture {
public:
	TER_TextureType type;
	uint16_t w, h;
	uint16_t rw, rh;

	virtual ~TER_Texture() {}
	virtual void load(TER_TextureFormat format, const void *data) = 0;

	sTER_Texture build(TER_TextureType type, uint16_t w, uint16_t h, bool powerof2=false, bool clamp=false, bool pixelize=false);
};

/*****************************************************************
 ** Shaders
 *****************************************************************/
enum class TER_ShaderType { VERTEX, FRAGMENT };
enum class TER_BinderType { ERROR, FLOAT, VEC2, VEC3, VEC4, MAT4, TEXTURE2D };

class TER_Shader; using sTER_Shader = shared_ptr<TER_Shader>;
class TER_Shader {
public:
	TER_ShaderType type;

	virtual ~TER_Shader() {}
	static sTER_Shader build(TER_ShaderType type, const char *code);
};

class TER_Program; using sTER_Program = shared_ptr<TER_Program>;
class TER_Program {
public:
	virtual ~TER_Program() {}
	static sTER_Program build(sTER_Shader vertex, sTER_Shader fragment);
};

/*****************************************************************
 ** Buffers
 *****************************************************************/
class TER_VertexBuffer {
public:
};

class TER_IndexBuffer {
public:
};

/*****************************************************************
 ** Rendering Context
 *****************************************************************/
class TER_Context {
public:
};

#endif
