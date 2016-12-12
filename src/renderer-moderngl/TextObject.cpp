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

extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "display.h"
#include "types.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "main.h"
#include "utf8proc/utf8proc.h"
}

#include "renderer-moderngl/Renderer.hpp"
#include "renderer-moderngl/TextObject.hpp"

shader_type *DORText::default_shader = NULL;

void DORText::cloneInto(DisplayObject* _into) {
	DORVertexes::cloneInto(_into);
	DORText *into = dynamic_cast<DORText*>(_into);

	// Clone reference
	if (L && font_lua_ref) {
		lua_rawgeti(L, LUA_REGISTRYINDEX, font_lua_ref);
		into->font_lua_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	}

	into->font = font;
	into->font_color = font_color;
	into->line_max_width = line_max_width;
	into->max_lines = max_lines;
	into->no_linefeed = no_linefeed;
	into->setText(text);
}

int DORText::addCharQuad(const char *str, size_t len, font_style style, int bx, int by, float r, float g, float b, float a) {
	int x = 0, y = by;
	ssize_t off = 1;
	int32_t c;
	float scale = font->scale;
	float italic = 0;
	if (style == FONT_STYLE_ITALIC) { style = FONT_STYLE_NORMAL; italic = 0.3; }
	while (off > 0) {
		off = utf8proc_iterate((const uint8_t*)str, len, &c);
		str += off;
		len -= off;

		font->font->outline_thickness = 0;
		font->font->rendermode = ftgl::RENDER_SIGNED_DISTANCE_FIELD;
		ftgl::texture_glyph_t *d = ftgl::texture_font_get_glyph(font->font, c);
		if (d) {
			float kerning = 0;
			if (last_glyph) {
				kerning = texture_glyph_get_kerning(d, last_glyph) * scale;
			}
			x += texture_glyph_get_kerning(d, last_glyph) * scale;
			positions.push_back({x, y});
			last_glyph = c;

		        // printf("Glyph: %c : %f + %f : %d : %d\n", c, kerning, d->advance_x, d->offset_x, d->width);
			
			float x0  = bx + x + d->offset_x * scale;
			float x1  = x0 + d->width * scale;
			float italicx = - d->offset_x * scale * italic;
			float y0 = by + (font->font->ascender - d->offset_y) * scale;
			float y1 = y0 + (d->height) * scale;

			if (shadow_x || shadow_y) {
				vertices.push_back({{shadow_x+x0+italicx, shadow_y+y0, -1, 1},	{d->s0, d->t0}, shadow_color, {style == FONT_STYLE_BOLD, 0, 0, 0}});
				vertices.push_back({{shadow_x+x1+italicx, shadow_y+y0, -1, 1},	{d->s1, d->t0}, shadow_color, {style == FONT_STYLE_BOLD, 0, 0, 0}});
				vertices.push_back({{shadow_x+x1, shadow_y+y1, -1, 1},	{d->s1, d->t1}, shadow_color, {style == FONT_STYLE_BOLD, 0, 0, 0}});
				vertices.push_back({{shadow_x+x0, shadow_y+y1, -1, 1},	{d->s0, d->t1}, shadow_color, {style == FONT_STYLE_BOLD, 0, 0, 0}});
			}

			if (outline) {
				font->font->outline_thickness = 2;
				font->font->rendermode = ftgl::RENDER_OUTLINE_POSITIVE;
				ftgl::texture_glyph_t *doutline = ftgl::texture_font_get_glyph(font->font, c);
				if (doutline) {
					float x0  = bx + x + doutline->offset_x * scale;
					float x1  = x0 + doutline->width * scale;
					float italicx = - doutline->offset_x * scale * italic;
					float y0 = by + (font->font->ascender - doutline->offset_y) * scale;
					float y1 = y0 + (doutline->height) * scale;

					vertices.push_back({{x0+italicx, y0, 0, 1},	{doutline->s0, doutline->t0}, outline_color, {style == FONT_STYLE_BOLD, 1, 0, 0}});
					vertices.push_back({{x1+italicx, y0, 0, 1},	{doutline->s1, doutline->t0}, outline_color, {style == FONT_STYLE_BOLD, 1, 0, 0}});
					vertices.push_back({{x1, y1, 0, 1},	{doutline->s1, doutline->t1}, outline_color, {style == FONT_STYLE_BOLD, 1, 0, 0}});
					vertices.push_back({{x0, y1, 0, 1},	{doutline->s0, doutline->t1}, outline_color, {style == FONT_STYLE_BOLD, 1, 0, 0}});
				}
			}

			vertices.push_back({{x0+italicx, y0, 0, 1},	{d->s0, d->t0}, {r, g, b, a}, {style == FONT_STYLE_BOLD, 0, 0, 0}});
			vertices.push_back({{x1+italicx, y0, 0, 1},	{d->s1, d->t0}, {r, g, b, a}, {style == FONT_STYLE_BOLD, 0, 0, 0}});
			vertices.push_back({{x1, y1, 0, 1},	{d->s1, d->t1}, {r, g, b, a}, {style == FONT_STYLE_BOLD, 0, 0, 0}});
			vertices.push_back({{x0, y1, 0, 1},	{d->s0, d->t1}, {r, g, b, a}, {style == FONT_STYLE_BOLD, 0, 0, 0}});

			x += d->advance_x * scale; // WTF without a 110% factor letters always look too close .. uh
		}
	}
	return x;
}

int DORText::getTextChunkSize(const char *str, size_t len, font_style style) {
	int x = 0, y = 0;
	ssize_t off = 1;
	int32_t c, oldc = 0;
	float scale = font->scale;
	while (off > 0) {
		off = utf8proc_iterate((const uint8_t*)str, len, &c);
		str += off;
		len -= off;

		ftgl::texture_glyph_t *d = ftgl::texture_font_get_glyph(font->font, c);
		if (d) {
			if (oldc) {
				x += texture_glyph_get_kerning(d, oldc) * scale;
			}
			x += d->advance_x * scale;
		}
		oldc = c;
	}
	return x;
}

void DORText::parseText() {
	clear();
	entities_container.clear();
	positions.clear();
	centered = false;

	font_type *f = font;
	if (!f) return;
	size_t len = strlen(text);
	if (!len) return;
	const char *str = text;
	float r = font_color.r, g = font_color.g, b = font_color.b, a = font_color.a;
	float lr = r, lg = g, lb = b, la = a;
	int max_width = line_max_width;
	int bx = 0, by = 0;

	setTexture(f->atlas->id, LUA_NOREF);

	// Update VO size once, we are allocating a few more than neede in case of utf8 or control sequences, but we dont care
	vertices.reserve(len * 4);

	int font_h = f->lineskip * f->scale;
	int nb_lines = 1;
	int id_real_line = 1;
	char *line_data = NULL;
	int line_data_size = 0;
	char *start = (char*)str, *stop = (char*)str, *next = (char*)str;
	int max_size = 0;
	int size = 0;
	bool is_separator = false;
	int i;
	bool force_nl = false;
	font_style style = FONT_STYLE_NORMAL;

	last_glyph = 0;

	// int fstyle = TTF_GetFontStyle(f->font);
	// if (fstyle & TTF_STYLE_BOLD) style = FONT_STYLE_BOLD;
	// else if (fstyle & TTF_STYLE_ITALIC) style = FONT_STYLE_ITALIC;
	// else if (fstyle & TTF_STYLE_UNDERLINE) style = FONT_STYLE_UNDERLINED;

	while (true)
	{
		if ((*next == '\n') || (*next == ' ') || (*next == '\0') || (*next == '#'))
		{
			bool inced = false;
			if (*next == ' ' && *(next+1))
			{
				inced = true;
				stop = next;
				next++;
			}
			else stop = next - 1;

			// Make a surface for the word
			int len = next - start;
			int future_size = getTextChunkSize(start, len, style);

			// If we must do a newline, flush the previous word and the start the new line
			if (!no_linefeed && (force_nl || (future_size && max_width && (size + future_size > max_width))))
			{
				if (size > max_size) max_size = size;
				size = 0;
				last_glyph = 0;

				// Stop?
				if (nb_lines >= max_lines) break;

				// Push it & reset the surface
				is_separator = false;
//				printf("Ending previous line at size %d\n", size);
				nb_lines++;
				if (force_nl)
				{
					id_real_line++;
					if (line_data) { line_data = NULL; }
				}
				force_nl = false;
			}

			if (len)
			{
				// Detect separators
				if ((*start == '-') && (*(start+1) == '-') && (*(start+2) == '-') && !(*(start+3))) is_separator = true;

//				printf("Drawing word '%s'\n", start);
				size += addCharQuad(start, len, style, bx + size, by + (nb_lines-1) * font_h, r, g, b, a);
			}
			if (inced) next--;
			start = next + 1;

			// Force a linefeed
			if (*next == '\n') force_nl = true;

			// Handle special codes
			else if (*next == '#')
			{
				char *codestop = next + 1;
				while (*codestop && *codestop != '#') codestop++;
				// Font style
				if (*(next+1) == '{') {
					if (*(next+2) == 'n') style = FONT_STYLE_NORMAL;
					else if (*(next+2) == 'b') style = FONT_STYLE_BOLD;
					else if (*(next+2) == 'i') style = FONT_STYLE_ITALIC;
					else if (*(next+2) == 'u') style = FONT_STYLE_UNDERLINED;
				}
				// Entity UID
				else if ((codestop - (next+1) > 4) && (*(next+1) == 'U') && (*(next+2) == 'I') && (*(next+3) == 'D') && (*(next+4) == ':')) {
					// Grab the entity
					lua_getglobal(L, "__get_uid_entity");
					char *colon = next + 5;
					while (*colon && *colon != ':') colon++;
					lua_pushlstring(L, next+5, colon - (next+5));
					lua_call(L, 1, 1);
					if (lua_istable(L, -1))
					{
						// Grab the method
						lua_pushstring(L, "getEntityDisplayObject");
						lua_gettable(L, -2);
						// Add parameters
						lua_pushvalue(L, -2);
						lua_pushnil(L);
						lua_pushnumber(L, font_h);
						lua_pushnumber(L, font_h);
						lua_pushnumber(L, 1);
						lua_pushnil(L);
						lua_pushnil(L);
						lua_pushboolean(L, true);
						// Call method to get the DO
						lua_call(L, 8, 1);

						DisplayObject *c = userdata_to_DO(__FUNCTION__, L, -1);
						if (c) {
							c->setLuaRef(luaL_ref(L, LUA_REGISTRYINDEX));
							c->translate(bx + size, by + (nb_lines-1) * font_h, -1, false);
							entities_container.add(c);
						}
						lua_pop(L, 1);
						size += font_h;
					}
					lua_pop(L, 1);
				}
				// Extra data
				else if (*(next+1) == '&') {
					line_data = next + 2;
					line_data_size = codestop - (next+2);
				}
				// Color
				else {
					if ((codestop - (next+1) == 4) && (*(next+1) == 'L') && (*(next+2) == 'A') && (*(next+3) == 'S') && (*(next+4) == 'T'))
					{
						r = lr;
						g = lg;
						b = lb;
						a = la;
					}

					lua_getglobal(L, "colors");
					lua_pushlstring(L, next+1, codestop - (next+1));
					lua_rawget(L, -2);
					if (lua_istable(L, -1)) {
						lr = r;
						lg = g;
						lb = b;
						la = a;

						lua_pushliteral(L, "r");
						lua_rawget(L, -2);
						r = lua_tonumber(L, -1) / 255;
						lua_pushliteral(L, "g");
						lua_rawget(L, -3);
						g = lua_tonumber(L, -1) / 255;
						lua_pushliteral(L, "b");
						lua_rawget(L, -4);
						b = lua_tonumber(L, -1) / 255;
						lua_pop(L, 3);
						a = 1;
					}
					// Hexacolor
					else if (codestop - (next+1) == 6)
					{
						lr = r;
						lg = g;
						lb = b;
						la = a;

						int rh = 0, gh = 0, bh = 0;

						if ((*(next+1) >= '0') && (*(next+1) <= '9')) rh += 16 * (*(next+1) - '0');
						else if ((*(next+1) >= 'a') && (*(next+1) <= 'f')) rh += 16 * (10 + *(next+1) - 'a');
						else if ((*(next+1) >= 'A') && (*(next+1) <= 'F')) rh += 16 * (10 + *(next+1) - 'A');
						if ((*(next+2) >= '0') && (*(next+2) <= '9')) rh += (*(next+2) - '0');
						else if ((*(next+2) >= 'a') && (*(next+2) <= 'f')) rh += (10 + *(next+2) - 'a');
						else if ((*(next+2) >= 'A') && (*(next+2) <= 'F')) rh += (10 + *(next+2) - 'A');

						if ((*(next+3) >= '0') && (*(next+3) <= '9')) gh += 16 * (*(next+3) - '0');
						else if ((*(next+3) >= 'a') && (*(next+3) <= 'f')) gh += 16 * (10 + *(next+3) - 'a');
						else if ((*(next+3) >= 'A') && (*(next+3) <= 'F')) gh += 16 * (10 + *(next+3) - 'A');
						if ((*(next+4) >= '0') && (*(next+4) <= '9')) gh += (*(next+4) - '0');
						else if ((*(next+4) >= 'a') && (*(next+4) <= 'f')) gh += (10 + *(next+4) - 'a');
						else if ((*(next+4) >= 'A') && (*(next+4) <= 'F')) gh += (10 + *(next+4) - 'A');

						if ((*(next+5) >= '0') && (*(next+5) <= '9')) bh += 16 * (*(next+5) - '0');
						else if ((*(next+5) >= 'a') && (*(next+5) <= 'f')) bh += 16 * (10 + *(next+5) - 'a');
						else if ((*(next+5) >= 'A') && (*(next+5) <= 'F')) bh += 16 * (10 + *(next+5) - 'A');
						if ((*(next+6) >= '0') && (*(next+6) <= '9')) bh += (*(next+6) - '0');
						else if ((*(next+6) >= 'a') && (*(next+6) <= 'f')) bh += (10 + *(next+6) - 'a');
						else if ((*(next+6) >= 'A') && (*(next+6) <= 'F')) bh += (10 + *(next+6) - 'A');

						r = (float)rh / 255;
						g = (float)gh / 255;
						b = (float)bh / 255;
						a = 1;
					}
					lua_pop(L, 2);
				}

				char old = *codestop;
				*codestop = '\0';
//				printf("Found code: %s\n", next+1);
				*codestop = old;

				start = codestop + 1;
				next = codestop; // The while will increment it, so we dont so it here
			}
		}
		if (*next == '\0') break;
		next++;
	}

	if (size > max_size) max_size = size;

	this->nb_lines = nb_lines;
	this->w = max_size;
	this->h = nb_lines * font_h;

	font_update_atlas(f); // Make sure any texture changes are upload to the GPU
}

void DORText::setText(const char *text) {
	free((void*)this->text);
	size_t len = strlen(text);
	this->text = (char*)malloc(len + 1);
	strcpy(this->text, text);
	parseText();
}

void DORText::center() {
	if (!w || !h) return;
	if (centered) return;
	centered = true;
	
	// We dont use translate() to now make other translate fail, we move the actual center
	float hw = w / 2, hh = h / 2;
	for (auto it = vertices.begin() ; it != vertices.end(); ++it) {
		it->pos.x -= hw;
		it->pos.y -= hh;
	}
	setChanged();
}

vec2 DORText::getLetterPosition(int idx) {
	idx = idx - 1;
	if (positions.empty()) return {0, 0};
	if (idx > positions.size()) idx = positions.size();
	return positions[idx];
}

void DORText::clear() {
	DORVertexes::clear();
	entities_container.clear();
}

void DORText::render(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	if (!visible) return;
	DORVertexes::render(container, cur_model, cur_color);
	entities_container.render(container, cur_model, cur_color);
}

void DORText::renderZ(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	if (!visible) return;
	DORVertexes::renderZ(container, cur_model, cur_color);
	entities_container.renderZ(container, cur_model, cur_color);
}

DORText::~DORText() {
	free((void*)text);
	if (font_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, font_lua_ref);
};
