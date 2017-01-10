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
#ifndef _LUAFONT_H_
#define _LUAFONT_H_

extern "C" {
#include "display.h"
#include "tgl.h"
#include "freetype-gl/texture-atlas.h"
#include "freetype-gl/texture-font.h"
}
#include <string>

#define DEFAULT_ATLAS_W	1024
#define DEFAULT_ATLAS_H	1024
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
	std::string *fontname;
	void *font_mem;
	int font_mem_size;
	float scale;
	float lineskip;
	ftgl::texture_atlas_t *atlas;
	ftgl::texture_font_t *font;
} font_type;

// extern bool font_add_atlas(font_type *f, int32_t c, font_style style);
extern void font_update_atlas(font_type *f);
// extern void font_make_atlas(font_type *f, int w, int h);


#endif
