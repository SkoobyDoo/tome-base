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

#include "renderer/TER.hpp"
#include "renderer/gl2.1/TER_GL21.hpp"

/*****************************************************************
 ** Texture
 *****************************************************************/
sTER_Texture TER_Texture::build(TER_TextureType type, uint16_t w, uint16_t h, bool powerof2, bool clamp, bool pixelize) {
	#ifdef TER_USE_GL21
		return make_shared<TER_GL21_Texture>(type, w, h, powerof2, clamp, pixelize);
	#else
		#error Need to compile with one renderer backend
	#endif
}

TER_TextureFormat TER_Texture::getSurfaceFormat(SDL_Surface *s) {
	int nOfColors = s->format->BytesPerPixel;
	TER_TextureFormat texture_format;
	if (nOfColors == 4)	 // contains an alpha channel
	{
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
		if (s->format->Rmask == 0xff000000)
#else
		if (s->format->Rmask == 0x000000ff)
#endif
			texture_format = TER_TextureFormat::RGBA;
		else
			texture_format = TER_TextureFormat::BGRA;
	} else if (nOfColors == 3)	 // no alpha channel
	{
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
		if (s->format->Rmask == 0x00ff0000)
#else
		if (s->format->Rmask == 0x000000ff)
#endif
			texture_format = TER_TextureFormat::RGB;
		else
			texture_format = TER_TextureFormat::BGR;
	} else {
		printf("warning: the image is not truecolor..  this will probably break %d\n", nOfColors);
	}
	return texture_format;
}

sTER_Texture TER_Texture::build(SDL_Surface *s, bool powerof2, bool clamp, bool pixelize) {
	TER_TextureFormat format = getSurfaceFormat(s);
	sTER_Texture tex = build(TER_TextureType::T2D, s->w, s->h, powerof2, clamp, pixelize);
	tex->load(format, s->w, s->h, s->pixels);
	return tex;
}

/*****************************************************************
 ** Shaders
 *****************************************************************/
unordered_map<string, TER_ShaderAttribute> TER_shader_attribute_names_to_ids({
	{"te4_position", TER_ShaderAttribute::POS},
	{"te4_color", TER_ShaderAttribute::COLOR},
	{"te4_texcoord", TER_ShaderAttribute::TEXCOORD},
	{"te4_shape_vertex", TER_ShaderAttribute::TEXCOORD},
	{"te4_texinfo", TER_ShaderAttribute::TEXINFO},
	{"te4_mapcoord", TER_ShaderAttribute::MAPCOORD},
	{"te4_kind", TER_ShaderAttribute::KIND},
	{"te4_model", TER_ShaderAttribute::MODEL},
});
unordered_map<string, TER_ShaderUniform> TER_shader_uniform_names_to_ids({
	{"mvp", TER_ShaderUniform::MVP},
	{"tick", TER_ShaderUniform::TICK},
	{"displayColor", TER_ShaderUniform::COLOR},
});
array<uint8_t, (uint8_t)TER_BinderType::END> TER_binder_types_sizes = {
	0, // ERROR,
	1, // FLOAT,
	2, // VEC2,
	3, // VEC3,
	4, // VEC4,
	16, // MAT4,
	1, // TEXTURE2D,
};

sTER_Shader TER_Shader::build(TER_ShaderType type, const char *code) {
	#ifdef TER_USE_GL21
		return make_shared<TER_GL21_Shader>(type, code);
	#else
		#error Need to compile with one renderer backend
	#endif
}

sTER_Program TER_Program::build(sTER_Shader vertex, sTER_Shader fragment) {
	#ifdef TER_USE_GL21
		return make_shared<TER_GL21_Program>(vertex, fragment);
	#else
		#error Need to compile with one renderer backend
	#endif
}

/*****************************************************************
 ** Buffers
 *****************************************************************/
array<uint8_t, (uint8_t)TER_BufferFormat::END> TER_buffer_format_sizes = {
	sizeof(float), // FLOAT
	sizeof(uint32_t), // UINT32
};

TER_AttributesDecl* TER_AttributesDecl::add(TER_ShaderAttribute attr, TER_BinderType type) {
	printf("TER_AttributesDecl:add: %d, %d, %d, %d\n", (uint32_t)attr, (uint32_t)type, total_size, TER_binder_types_sizes[(uint8_t)type]);
	list.emplace_back(attr, type, total_size, TER_binder_types_sizes[(uint8_t)type]);
	total_size += TER_binder_types_sizes[(uint8_t)type];
	return this;
}

sTER_AttributesDecl TER_AttributesDecl::build() {
	return make_shared<TER_AttributesDecl>();
}

sTER_VertexBuffer TER_VertexBuffer::build(TER_BufferFormat format, TER_BufferMode mode, sTER_AttributesDecl data_format, void *data, uint32_t data_nb) {
	#ifdef TER_USE_GL21
		return make_shared<TER_GL21_VertexBuffer>(format, mode, data_format, data, data_nb);
	#else
		#error Need to compile with one renderer backend
	#endif
}
sTER_IndexBuffer TER_IndexBuffer::build(TER_BufferFormat format, TER_BufferMode mode, void *data, uint32_t data_nb) {
	#ifdef TER_USE_GL21
		return make_shared<TER_GL21_IndexBuffer>(format, mode, data, data_nb);
	#else
		#error Need to compile with one renderer backend
	#endif
}

/*****************************************************************
 ** Frame Buffers
 *****************************************************************/
sTER_FrameBuffer TER_FrameBuffer::build(uint16_t w, uint16_t h, uint16_t nbt, bool hdr, bool depth) {
	#ifdef TER_USE_GL21
		return make_shared<TER_GL21_FrameBuffer>(w, h, nbt, hdr, depth);
	#else
		#error Need to compile with one renderer backend
	#endif
}

/*****************************************************************
 ** Rendering Context
 *****************************************************************/
TER_Context* TER_Context::build() {
	#ifdef TER_USE_GL21
		return new TER_GL21_Context();
	#else
		#error Need to compile with one renderer backend
	#endif
}
