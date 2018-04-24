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

extern "C" {
#include "tSDL.h"
}

#define GLM_FORCE_INLINE
#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"
#include "glm/ext.hpp"

#include <memory>
#include <unordered_map>
#include <vector>
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
	TER_TextureFormat format;
	TER_TextureType type;
	uint16_t w, h;
	uint16_t rw, rh;

	virtual ~TER_Texture() {}
	virtual void load(TER_TextureFormat format, uint16_t uw, uint16_t uh, const void *data) = 0;
	virtual void subload(TER_TextureFormat format, uint16_t x, uint16_t y, uint16_t uw, uint16_t uh, const void *data) = 0;

	static TER_TextureFormat getSurfaceFormat(SDL_Surface *s);
	static sTER_Texture build(TER_TextureType type, uint16_t w, uint16_t h, bool powerof2=false, bool clamp=false, bool pixelize=false);
	static sTER_Texture build(SDL_Surface *s, bool powerof2=false, bool clamp=false, bool pixelize=false);
};

/*****************************************************************
 ** Shaders
 *****************************************************************/
enum class TER_ShaderType { VERTEX, FRAGMENT };
enum class TER_BinderType : uint8_t { ERROR, FLOAT, VEC2, VEC3, VEC4, MAT4, TEXTURE2D, END };
enum class TER_ShaderAttribute : uint8_t { POS, COLOR, TEXCOORD, TEXINFO, MAPCOORD, KIND, MODEL, END };
enum class TER_ShaderUniform : uint8_t { MVP, TICK, COLOR, END };

extern unordered_map<string, TER_ShaderAttribute> TER_shader_attribute_names_to_ids;
extern unordered_map<string, TER_ShaderUniform> TER_shader_uniform_names_to_ids;

extern array<uint8_t, (uint8_t)TER_BinderType::END> TER_binder_types_sizes;

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

	virtual bool setUniform(string name, float v) = 0;
	virtual bool setUniform(string name, glm::vec2 v) = 0;
	virtual bool setUniform(string name, glm::vec3 v) = 0;
	virtual bool setUniform(string name, glm::vec4 v) = 0;
	virtual bool setUniform(string name, glm::mat4 v) = 0;
};

/*****************************************************************
 ** Buffers
 *****************************************************************/
enum class TER_BufferMode { STATIC, DYNAMIC, STREAM };
enum class TER_BufferFormat : uint8_t { FLOAT, UINT32, END };
extern array<uint8_t, (uint8_t)TER_BufferFormat::END> TER_buffer_format_sizes;

class TER_AttributesDecl; using sTER_AttributesDecl = shared_ptr<TER_AttributesDecl>;
class TER_AttributesDecl {
public:
	// 0=AttributeID, 1=bind type(float, vec, ...), 2=offset, 3=size
	vector<tuple<TER_ShaderAttribute,TER_BinderType,uint16_t,uint16_t>> list;
	uint16_t total_size = 0;

	TER_AttributesDecl* add(TER_ShaderAttribute attr, TER_BinderType type);
	static sTER_AttributesDecl build();
};

class TER_VertexBuffer; using sTER_VertexBuffer = shared_ptr<TER_VertexBuffer>;
class TER_VertexBuffer {
public:
	TER_BufferMode mode;
	TER_BufferFormat format;
	sTER_AttributesDecl data_format;
	uint8_t data_element_size;
	void *data = nullptr;
	uint32_t data_nb = 0;

	virtual ~TER_VertexBuffer() {}
	static sTER_VertexBuffer build(TER_BufferFormat format, TER_BufferMode mode, sTER_AttributesDecl data_format, void *data, uint32_t data_nb);
};

class TER_IndexBuffer; using sTER_IndexBuffer = shared_ptr<TER_IndexBuffer>;
class TER_IndexBuffer {
public:
	TER_BufferMode mode;
	TER_BufferFormat format;
	uint8_t data_element_size;
	void *data = nullptr;
	uint32_t data_nb = 0;

	virtual ~TER_IndexBuffer() {}
	static sTER_IndexBuffer build(TER_BufferFormat format, TER_BufferMode mode, void *data, uint32_t data_nb);
};

/*****************************************************************
 ** Frame buffers
 *****************************************************************/
class TER_FrameBuffer; using sTER_FrameBuffer = shared_ptr<TER_FrameBuffer>;
class TER_FrameBuffer {
public:
	uint16_t w, h, nbt;
	glm::vec4 clear_color = {0, 0, 0, 1};
	vector<sTER_Texture> textures;

	virtual ~TER_FrameBuffer() {}
	static sTER_FrameBuffer build(uint16_t w, uint16_t h, uint16_t nbt=1, bool hdr=false, bool depth=false);

	inline bool isMRT() { return textures.size() > 1; }
	inline void setClearColor(glm::vec4 &c) { clear_color = c; }
	virtual void use(bool state) = 0;
};

/*****************************************************************
 ** Rendering Context
 *****************************************************************/
enum class TER_BlendMode { DEFAULT, ADDITIVE, MIXED, SHINY };

class TER_Context {
protected:
	// Persistent data between submits
	TER_BlendMode blendmode = TER_BlendMode::DEFAULT;
	glm::mat4 view_m;

	// Transient data, erased by submit
	glm::mat4 model_m;
	sTER_Texture cur_textures[3];
	sTER_VertexBuffer cur_vertexbuffer;
	sTER_IndexBuffer cur_indexbuffer;
	sTER_FrameBuffer cur_framebuffer;
public:
	virtual ~TER_Context() {}
	static TER_Context* build();

	inline void view(glm::mat4 v) { view_m = v; }
	inline void model(glm::mat4 m) { model_m = m; }
	inline void blend(TER_BlendMode b) { blendmode = b; }
	inline void texture(sTER_Texture t, uint8_t idx=0) { cur_textures[idx] = t; }
	inline void vertex(sTER_VertexBuffer v) { cur_vertexbuffer = v; }
	inline void index(sTER_IndexBuffer i) { cur_indexbuffer = i; }
	virtual void framebuffer(sTER_FrameBuffer f) { cur_framebuffer = f; }
	virtual void submit(sTER_Program p) = 0;
	virtual void frame() = 0;
};

#endif
