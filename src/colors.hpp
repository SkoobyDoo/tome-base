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
#ifndef _LUACOLORS_H_
#define _LUACOLORS_H_

extern "C" {
#include "display.h"
#include "tgl.h"
}
#include <string>
#include <unordered_map>
#include "glm/glm.hpp"

using namespace std;
using namespace glm;

class Color {
protected:
	static unordered_map<string, Color> all_colors;
	vec4 rgba;
public:
	Color(float r, float g, float b, float a);
	vec4 get1();
	vec4 get256();

	static void resetAll();
	static void define256(const char *name, int r, int g, int b, int a = 255);
	static Color *find(string &name);
};

#endif
