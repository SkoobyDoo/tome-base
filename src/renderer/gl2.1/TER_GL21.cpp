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
}

TER_GL21_Texture::~TER_GL21_Texture() {
	glDeleteTextures(1, &tex);
}

void TER_GL21_Texture::load(TER_TextureFormat format, const void *data) {
	switch (format) {
		case TER_TextureFormat::RGBA: gl_format = GL_RGBA; break;
		case TER_TextureFormat::RGB:  gl_format = GL_RGB; break;
		case TER_TextureFormat::BGRA: gl_format = GL_BGRA; break;
		case TER_TextureFormat::BGR:  gl_format = GL_BGR; break;
	}
	glTexImage2D(gl_type, 0, gl_format, w, h, 0, gl_format, GL_UNSIGNED_BYTE, data);
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

	program = glCreateProgram();
	glAttachShader(program, vertex->shader);
	glAttachShader(program, fragment->shader);
	glLinkProgram(program);
	CHECKGLSLLINK(program);
	CHECKGLSLVALID(program);

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
		attributes.emplace_back(loc, name, type);
		printf("[GL21] Program Attribute #%d Type: %u Name: %s Location %d\n", i, type, name, loc);
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
	}	
}

TER_GL21_Program::~TER_GL21_Program() {
	if (program != 0) glDeleteProgram(program);
}
