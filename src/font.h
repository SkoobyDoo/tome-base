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
#ifndef _LUAFONT_H_
#define _LUAFONT_H_

#include "display.h"
#include "tgl.h"

#define DEFAULT_ATLAS_W	512
#define DEFAULT_ATLAS_H	512
#define MAX_ATLAS_DATA	256*256

typedef enum {
	FONT_STYLE_NORMAL,
	FONT_STYLE_BOLD,
	FONT_STYLE_UNDERLINED,
	FONT_STYLE_MAX,
	FONT_STYLE_ITALIC,
} font_style;

typedef struct
{
	GLfloat tx1, tx2, ty1, ty2;
	int w, h;
} font_atlas_data_style;

typedef struct
{
	font_atlas_data_style data[FONT_STYLE_MAX];
} font_atlas_data;

typedef struct
{
	TTF_Font *font;
	
	GLuint atlas_tex;
	SDL_Surface *atlas;
	int atlas_w, atlas_h;
	int atlas_x, atlas_y;
	font_atlas_data *atlas_data;
	bool atlas_changed;
} lua_font;

extern int luaopen_font(lua_State *L);

#endif
