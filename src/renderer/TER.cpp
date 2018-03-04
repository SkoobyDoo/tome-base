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

sTER_Texture TER_Texture::build(TER_TextureType type, uint16_t w, uint16_t h, bool powerof2, bool clamp, bool pixelize) {
	#ifdef TER_USE_GL21
		return make_shared<TER_GL21_Texture>(type, w, h, powerof2, clamp, pixelize);
	#else
		#error Need to compile with one renderer backend
	#endif
}

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
