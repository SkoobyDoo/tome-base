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
#ifndef TEXTOBJECTS_H
#define TEXTOBJECTS_H

#include "renderer-moderngl/Renderer.hpp"
#include <string.h>
#include "font.hpp"

class DORText : public DORVertexes{
private:
	static shader_type *default_shader;

	DORContainer entities_container;

	int font_lua_ref = LUA_NOREF;
	font_type *font = NULL;
	bool centered = false;
	char *text;
	int line_max_width = 99999;
	int max_lines = 999999;
	bool no_linefeed = false;
	vector<vec2> positions;
	uint32_t last_glyph = 0;
	font_style default_style = FONT_STYLE_NORMAL;
	vec4 font_color;
	vec4 font_last_color;

	vec4 used_color, used_last_color;
	font_style used_font_style;

	float shadow_x = 0, shadow_y = 0;
	vec4 shadow_color;

	float outline = 0;
	vec4 outline_color;

	virtual void cloneInto(DisplayObject *into);
	ftgl::texture_glyph_t *getGlyph(uint32_t codepoint);

public:
	int nb_lines = 1;
	int w = 0;
	int h = 0;

	static void defaultShader(shader_type *s) { default_shader = s; };

	DORText();
	virtual ~DORText();
	DO_STANDARD_CLONE_METHOD(DORText);
	virtual const char* getKind() { return "DORText"; };
	
	void setFont(font_type *font, int lua_ref) {
		if (font_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, font_lua_ref);
		this->font = font;
		font_lua_ref = lua_ref;
	};

	void setNoLinefeed(bool no_linefeed) { this->no_linefeed = no_linefeed; parseText(); };
	void setMaxWidth(int width) { this->line_max_width = width; parseText(); };
	void setMaxLines(int max) { this->max_lines = max; parseText(); };
	void setTextStyle(font_style style) { default_style = style; };
	void setTextColor(float r, float g, float b, float a) { font_color.r = r; font_color.g = g; font_color.b = b; font_color.a = a; font_last_color.r = r; font_last_color.g = g; font_last_color.b = b; font_last_color.a = a; parseText(); };
	void setFrom(DORText *prev);

	vec2 getLetterPosition(int idx);

	void setText(const char *text, bool simple=false);
	void center();

	void setShadow(float offx, float offy, vec4 color) { shadow_x = offx; shadow_y = offy; shadow_color = color; };
	void setOutline(float o, vec4 color) { outline = o; outline_color = color; };

	virtual void clear();

	virtual void render(RendererGL *container, mat4& cur_model, vec4& color, bool cur_visible);
	// virtual void renderZ(RendererGL *container, mat4& cur_model, vec4& color, bool cur_visible);

private:
	void parseText();
	void parseTextSimple();
	int getTextChunkSize(const char *str, size_t len, font_style style);
	int addCharQuad(const char *str, size_t len, font_style style, int bx, int by, float r, float g, float b, float a);
};

#endif
