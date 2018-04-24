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

extern "C" {
#include "tSDL.h"
}
extern SDL_Window *window;

#include "renderer/gl2.1/TER_GL21.hpp"
#include "renderer/gl2.1/checker.hpp"

/*****************************************************************
 ** Texture
 *****************************************************************/
TER_GL21_Texture::TER_GL21_Texture(TER_TextureType type, uint16_t w, uint16_t h, bool powerof2, bool clamp, bool pixelize) {
	this->type = type;
	switch (type) {
		case TER_TextureType::T2D: gl_type = GL_TEXTURE_2D; break;
	}

	if (powerof2) {
		rw = rh = 1;
		while (rw < w) rw *= 2;
		while (rh < h) rh *= 2;
		this->w = w;
		this->h = h;
	} else {
		this->w = rw = w;
		this->h = rh = h;
	}

	glGenTextures(1, &tex);
	glBindTexture(gl_type, tex);
	glTexParameteri(gl_type, GL_TEXTURE_WRAP_S, clamp ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(gl_type, GL_TEXTURE_WRAP_T, clamp ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(gl_type, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	if (pixelize) glTexParameteri(gl_type, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	// Init with null data
	format = TER_TextureFormat::RGBA;
	gl_format = GL_RGBA;
	glTexImage2D(gl_type, 0, gl_format, w, h, 0, gl_format, GL_UNSIGNED_BYTE, NULL);
}

TER_GL21_Texture::~TER_GL21_Texture() {
	glDeleteTextures(1, &tex);
}

void TER_GL21_Texture::load(TER_TextureFormat format, uint16_t uw, uint16_t uh, const void *data) {
	switch (format) {
		case TER_TextureFormat::RGBA: gl_format = GL_RGBA; break;
		case TER_TextureFormat::RGB:  gl_format = GL_RGB; break;
		case TER_TextureFormat::BGRA: gl_format = GL_BGRA; break;
		case TER_TextureFormat::BGR:  gl_format = GL_BGR; break;
	}
	this->format = format;
	glTexImage2D(gl_type, 0, gl_format, uw, uh, 0, gl_format, GL_UNSIGNED_BYTE, data);
	printf("[GL21] load texture with size %dx%d in texture of internal size %dx%d / %dx%d\n", uw, uh, w, h, rw, rh);
}

void TER_GL21_Texture::subload(TER_TextureFormat format, uint16_t x, uint16_t y, uint16_t uw, uint16_t uh, const void *data) {
	if (format != this->format) {
		printf("[GL21] subload with different format, forcing load\n");
		load(format, uw, uh, data);
		return;
	}
	glTexSubImage2D(gl_type, 0, x, y, uw, uh, gl_format, GL_UNSIGNED_BYTE, data);
	printf("[GL21] subload texture with size %dx%d at %dx%d in texture of internal size %dx%d / %dx%d\n", uw, uh, x, y, w, h, rw, rh);
}

/*****************************************************************
 ** Shaders
 *****************************************************************/
TER_GL21_Shader::TER_GL21_Shader(TER_ShaderType type, const char *code) : type(type) {
	GLuint kind;
	if (type == TER_ShaderType::FRAGMENT) kind = GL_FRAGMENT_SHADER;
	else if (type == TER_ShaderType::VERTEX) kind = GL_VERTEX_SHADER;

	shader = glCreateShader(kind);
	glShaderSource(shader, 1, &code, 0);
	glCompileShader(shader);
	CHECKGLSLCOMPILE(shader, "inline");
}

TER_GL21_Shader::~TER_GL21_Shader() {
	if (shader != 0) glDeleteShader(shader);
}

TER_GL21_Program::TER_GL21_Program(sTER_Shader _vertex, sTER_Shader _fragment) :
	vertex(static_pointer_cast<TER_GL21_Shader>(_vertex)), fragment(static_pointer_cast<TER_GL21_Shader>(_fragment))
{
	GLint count;

	for (auto &it : attributes) it.loc = -1;
	for (auto &it : frame_uniforms) it.loc = -1;

	program = glCreateProgram();
	glAttachShader(program, vertex->shader);
	glAttachShader(program, fragment->shader);
	glLinkProgram(program);
	CHECKGLSLLINK(program);
	CHECKGLSLVALID(program);
	glUseProgram(program);

	/** List all attributes **/
	glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES, &count);
	printf("[GL21] Program Active Attributes: %d\n", count);
	for (GLint i = 0; i < count; i++) {
		GLint size; // size of the variable
		GLenum type; // type of the variable (float, vec3 or mat4, etc)
		const GLsizei bufSize = 256; // maximum name length
		GLchar name[bufSize]; // variable name in GLSL
		GLsizei length; // name length

		glGetActiveAttrib(program, (GLuint)i, bufSize, &length, &size, &type, name);
		GLint loc = glGetAttribLocation(program, name);

		auto it = TER_shader_attribute_names_to_ids.find(name);
		if (it != TER_shader_attribute_names_to_ids.end()) {
			attributes[(uint16_t)it->second] = {loc, name, type};
			printf("[GL21] Program Attribute #%d Type: %u Name: %s Location: %d AttributeID %d\n", i, type, name, loc, (uint16_t)it->second);
		}
	}	

	/** List all uniforms **/
	glGetProgramiv(program, GL_ACTIVE_UNIFORMS, &count);
	printf("[GL21] Program Active Uniforms: %d\n", count);
	for (GLint i = 0; i < count; i++) {
		GLint size; // size of the variable
		GLenum type; // type of the variable (float, vec3 or mat4, etc)
		const GLsizei bufSize = 256; // maximum name length
		GLchar name[bufSize]; // variable name in GLSL
		GLsizei length; // name length

		glGetActiveUniform(program, (GLuint)i, bufSize, &length, &size, &type, name);
		GLint loc = glGetUniformLocation(program, name);
		uniforms.emplace_back(loc, name, type);
		printf("[GL21] Program Uniform #%d Type: %u Name: %s Location %d\n", i, type, name, loc);

		auto it = TER_shader_uniform_names_to_ids.find(name);
		if (it != TER_shader_uniform_names_to_ids.end()) {
			frame_uniforms[(uint16_t)it->second] = {loc, name, type};
			printf("[GL21] Program Uniform is also a frame uniform of id %d\n", (uint16_t)it->second);
		}
	}	
}

TER_GL21_Program::~TER_GL21_Program() {
	if (program != 0) glDeleteProgram(program);
}

bool TER_GL21_Program::setUniform(string name, float v) {
	glUseProgram(program);
	GLint loc = glGetUniformLocation(program, name.c_str());
	if (loc == -1) return false;
	glUniform1fv(loc, 1, &v);
	return true;
}

bool TER_GL21_Program::setUniform(string name, glm::vec2 v) {
	glUseProgram(program);
	GLint loc = glGetUniformLocation(program, name.c_str());
	if (loc == -1) return false;
	glUniform2fv(loc, 1, glm::value_ptr(v));
	return true;
}

bool TER_GL21_Program::setUniform(string name, glm::vec3 v) {
	glUseProgram(program);
	GLint loc = glGetUniformLocation(program, name.c_str());
	if (loc == -1) return false;
	glUniform3fv(loc, 1, glm::value_ptr(v));
	return true;
}

bool TER_GL21_Program::setUniform(string name, glm::vec4 v) {
	glUseProgram(program);
	GLint loc = glGetUniformLocation(program, name.c_str());
	if (loc == -1) return false;
	glUniform4fv(loc, 1, glm::value_ptr(v));
	return true;
}

bool TER_GL21_Program::setUniform(string name, glm::mat4 v) {
	glUseProgram(program);
	GLint loc = glGetUniformLocation(program, name.c_str());
	if (loc == -1) return false;
	glUniformMatrix4fv(loc, 1, GL_FALSE, glm::value_ptr(v));
	return true;
}

/*****************************************************************
 ** Buffers
 *****************************************************************/
TER_GL21_VertexBuffer::TER_GL21_VertexBuffer(TER_BufferFormat format, TER_BufferMode mode, sTER_AttributesDecl data_format, void *data, uint32_t data_nb) {
	this->data_format = data_format;
	this->data_nb = data_nb;
	base_data_size = TER_buffer_format_sizes[(uint8_t)format];
	switch (mode) {
		case TER_BufferMode::STATIC: gl_mode = GL_STATIC_DRAW; break;
		case TER_BufferMode::DYNAMIC: gl_mode = GL_DYNAMIC_DRAW; break;
		case TER_BufferMode::STREAM: gl_mode = GL_STREAM_DRAW; break;
	}
	switch (format) {
		case TER_BufferFormat::FLOAT: gl_type = GL_FLOAT; break;
		case TER_BufferFormat::UINT32: gl_type = GL_UNSIGNED_INT; break;
	}

	glGenBuffers(1, &buff);
	glBindBuffer(GL_ARRAY_BUFFER, buff);
	glBufferData(GL_ARRAY_BUFFER, base_data_size * data_nb, data, gl_mode);
}

TER_GL21_VertexBuffer::~TER_GL21_VertexBuffer() {
	glDeleteBuffers(1, &buff);
}

TER_GL21_IndexBuffer::TER_GL21_IndexBuffer(TER_BufferFormat format, TER_BufferMode mode, void *data, uint32_t data_nb) {
	this->data_nb = data_nb;
	base_data_size = TER_buffer_format_sizes[(uint8_t)format];
	switch (mode) {
		case TER_BufferMode::STATIC: gl_mode = GL_STATIC_DRAW; break;
		case TER_BufferMode::DYNAMIC: gl_mode = GL_DYNAMIC_DRAW; break;
		case TER_BufferMode::STREAM: gl_mode = GL_STREAM_DRAW; break;
	}
	switch (format) {
		case TER_BufferFormat::FLOAT: printf("[GL21] ERROR: TER_GL21_IndexBuffer only supports TER_BufferFormat::UINT32\n"); break;
		case TER_BufferFormat::UINT32: gl_type = GL_UNSIGNED_INT; break;
	}

	glGenBuffers(1, &buff);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, buff);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, base_data_size * data_nb, data, gl_mode);
}

TER_GL21_IndexBuffer::~TER_GL21_IndexBuffer() {
	glDeleteBuffers(1, &buff);
}

/*****************************************************************
 ** Frame Buffers
 *****************************************************************/
TER_GL21_FrameBuffer::TER_GL21_FrameBuffer(uint16_t w, uint16_t h, uint16_t nbt, bool hdr, bool depth) {
	// DGDGDGDG hdr is ignored for now
	this->w = w;
	this->h = h;
	this->nbt = nbt;
	glGenFramebuffers(1, &fbo);
	glBindFramebuffer(GL_FRAMEBUFFER, fbo);

	if (depth) {
		glGenTextures(1, &depthbuffer);
		glBindTexture(GL_TEXTURE_2D, depthbuffer);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT, w, h, 0, GL_DEPTH_COMPONENT, GL_FLOAT, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, depthbuffer, 0);
	} else {
		depthbuffer = 0;
	}

	// Now setup a texture to render to
	textures.reserve(nbt);
	for (uint16_t i = 0; i < nbt; i++) {
		textures.emplace_back(new TER_GL21_Texture(TER_TextureType::T2D, w, h, false, false, false));

		TER_GL21_Texture *tex = static_cast<TER_GL21_Texture*>(textures[i].get());
		glBindTexture(GL_TEXTURE_2D, tex->tex);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + i, GL_TEXTURE_2D, tex->tex, 0);
		buffers.emplace_back(GL_COLOR_ATTACHMENT0 + i);
	}

	tglBindFramebuffer(GL_FRAMEBUFFER, 0);
}

TER_GL21_FrameBuffer::~TER_GL21_FrameBuffer() {
	glBindFramebuffer(GL_FRAMEBUFFER, fbo);
	if (depthbuffer) {
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, 0, 0);
		glDeleteTextures(1, &depthbuffer);
	}
	textures.clear();
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
	glDeleteFramebuffers(1, &fbo);
}

void TER_GL21_FrameBuffer::use(bool state) {
	if (state) {
		tglBindFramebuffer(GL_FRAMEBUFFER, fbo);
		glDrawBuffers(buffers.size(), buffers.data());
		tglClearColor(clear_color.r, clear_color.g, clear_color.b, clear_color.a);
		if (depthbuffer) glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		else glClear(GL_COLOR_BUFFER_BIT);
	} else {
		glBindFramebuffer(GL_FRAMEBUFFER, 0);		
	}
}

/*****************************************************************
 ** Rendering Context
 *****************************************************************/
TER_GL21_Context::TER_GL21_Context() {
	// Defautl blend mode
	glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
}

TER_GL21_Context::~TER_GL21_Context() {
}

void TER_GL21_Context::submit(sTER_Program _program) {
	TER_GL21_Program *program = static_cast<TER_GL21_Program*>(_program.get());
	TER_GL21_VertexBuffer *vert_buf = static_cast<TER_GL21_VertexBuffer*>(cur_vertexbuffer.get());
	TER_GL21_IndexBuffer *idx_buf = static_cast<TER_GL21_IndexBuffer*>(cur_indexbuffer.get());

	// Close last framebuffer if we dont use it anymore
	if (cur_framebuffer != last_framebuffer && last_framebuffer) last_framebuffer->use(false);

	if (blendmode != last_blendmode) {
		switch (blendmode) {
			case TER_BlendMode::DEFAULT: glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA); break;
			case TER_BlendMode::ADDITIVE: glBlendFunc(GL_ONE, GL_ONE); break;
			case TER_BlendMode::MIXED: glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;
			case TER_BlendMode::SHINY: glBlendFunc(GL_SRC_ALPHA,GL_ONE); break;
		}
	}

	if (cur_framebuffer) cur_framebuffer->use(true);

	// Setup shader program
	if (_program != last_program) glUseProgram(program->program);

	// Bind textures
	for (uint8_t i = 0; i < 3 && !holds_alternative<bool>(cur_textures[i]); i++) {
		if (holds_alternative<sTER_Texture>(cur_textures[i])) {
			TER_GL21_Texture *t = static_cast<TER_GL21_Texture*>(get<sTER_Texture>(cur_textures[i]).get());
			glActiveTexture(GL_TEXTURE0 + i);
			glBindTexture(t->gl_type, t->tex);
		} else if (holds_alternative<sTER_FrameBuffer>(cur_textures[i])) {
			TER_GL21_FrameBuffer *f = static_cast<TER_GL21_FrameBuffer*>(get<sTER_FrameBuffer>(cur_textures[i]).get());
			glActiveTexture(GL_TEXTURE0 + i);
			TER_GL21_Texture *t = static_cast<TER_GL21_Texture*>(f->textures[0].get());
			glBindTexture(GL_TEXTURE_2D, t->tex);
		}
	}

	// Setup changing uniforms
	if (program->frame_uniforms[(uint8_t)TER_ShaderUniform::MVP].loc != -1) {
		glm::mat4 mvp = view_m * model_m;
		glUniformMatrix4fv(program->frame_uniforms[(uint8_t)TER_ShaderUniform::MVP].loc, 1, GL_FALSE, glm::value_ptr(mvp));
	}

	// Bind attributes
	if (cur_vertexbuffer != last_vertexbuffer) {
		glBindBuffer(GL_ARRAY_BUFFER, vert_buf->buff);
		for (auto &attr : vert_buf->data_format->list) {
			auto &program_attr = program->attributes[(uint8_t)get<0>(attr)];
			if (program_attr.loc != -1) {
				glEnableVertexAttribArray(program_attr.loc);

				uint64_t offset = get<2>(attr) * vert_buf->base_data_size;
				glVertexAttribPointer(program_attr.loc, get<3>(attr), vert_buf->gl_type, GL_FALSE, vert_buf->data_format->total_size * vert_buf->base_data_size, (void*)offset);
			}
		}
	}

	// Bind elements buffer
	if (cur_indexbuffer != last_indexbuffer) {
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, idx_buf->buff);
	}

	// By the power of the Mighty OpenGL, let there be draws!
	glDrawElements(GL_TRIANGLES, idx_buf->data_nb, GL_UNSIGNED_INT, (void*)0);

	// Remember stuff that should only change rarely
	last_indexbuffer = cur_indexbuffer;
	last_vertexbuffer = cur_vertexbuffer;
	last_framebuffer = cur_framebuffer;
	last_program = _program;
	last_blendmode = blendmode;

	// Clean up state for next submit
	cur_textures[0] = cur_textures[1] = cur_textures[2] = false;
	cur_vertexbuffer = nullptr;
	cur_indexbuffer = nullptr;
	cur_framebuffer = nullptr;
	// We do not cur_framebuffer->use(false) becasue this will be done by the next call
}

void TER_GL21_Context::frame() {
	SDL_GL_SwapWindow(window);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}
