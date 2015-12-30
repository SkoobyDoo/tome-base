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
#ifndef TEXTOBJECTS_H
#define TEXTOBJECTS_H

#include "displayobjects/DisplayObject.hpp"
extern "C" {
#include "font.h"
#include "utf8proc/utf8proc.h"
}

class DOText : public DOVertexes{
private:
	int font_lua_ref = LUA_NOREF;
	font_type *font = NULL;

	char *text;
	int line_max_width = 99999;
	bool no_linefeed = false;
	int nb_lines = 1;
	int w = 0;
	int h = 0;

public:

	DOText() {
		text = strdup("");
	};
	virtual ~DOText() {
		free((void*)text);
		if (font_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, font_lua_ref);
	};
	
	void setFont(font_type *font, int lua_ref) {
		if (font_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, font_lua_ref);
		this->font = font;
		font_lua_ref = lua_ref;
	};

	void setNoLinefeed(bool no_linefeed) { this->no_linefeed = no_linefeed; parseText(); };
	void setMaxWidth(int width) { this->line_max_width = width; parseText(); };

	void setText(const char *text);

private:
	void parseText();
	int getTextChunkSize(const char *str, size_t len, font_style style);
	int addCharQuad(const char *str, size_t len, font_style style, int bx, int by, float r, float g, float b, float a);
};

#endif
