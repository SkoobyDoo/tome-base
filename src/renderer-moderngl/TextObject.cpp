/*
	TE4 - T-Engine 4
	Copyright (C) 2009 - 2018 Nicolas Casalini

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
#include "colors.hpp"

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

void DORText::setFrom(DORText *prev) {
	font_color = prev->used_color;
	font_last_color = prev->used_last_color;
	default_style = prev->used_font_style;
}

void DORText::setTextStyle(font_style style) {
	default_style = style;
	used_font_style = style;
}
void DORText::setTextColor(float r, float g, float b, float a) {
	font_color.r = r; font_color.g = g; font_color.b = b; font_color.a = a;
	font_last_color.r = r; font_last_color.g = g; font_last_color.b = b; font_last_color.a = a;
	used_color = font_color;
	used_last_color = font_last_color;
	parseText();
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

		font->kind->font->outline_thickness = 0;
		font->kind->font->rendermode = ftgl::RENDER_SIGNED_DISTANCE_FIELD;
		ftgl::texture_glyph_t *d = font->kind->getGlyph(c);
		if (d) {
			float kerning = 0;
			if (last_glyph) {
				kerning = texture_glyph_get_kerning(d, last_glyph) * scale;
			}
			x += texture_glyph_get_kerning(d, last_glyph) * scale;
			last_glyph = c;

		        // printf("Glyph: %c : %f + %f : %d : %d\n", c, kerning, d->advance_x, d->offset_x, d->width);
			
			float x0  = bx + x + d->offset_x * scale;
			float x1  = x0 + d->width * scale;
			float italicx = - d->offset_x * scale * italic;
			float y0 = by + (font->kind->font->ascender - d->offset_y) * scale;
			float y1 = y0 + (d->height) * scale;
			positions.push_back({x0, y});

			if (shadow_x || shadow_y) {
				vertices.push_back({{shadow_x+x0+italicx, shadow_y+y0, -1, 1},	{d->s0, d->t0}, shadow_color});
				vertices.push_back({{shadow_x+x1+italicx, shadow_y+y0, -1, 1},	{d->s1, d->t0}, shadow_color});
				vertices.push_back({{shadow_x+x1, shadow_y+y1, -1, 1},	{d->s1, d->t1}, shadow_color});
				vertices.push_back({{shadow_x+x0, shadow_y+y1, -1, 1},	{d->s0, d->t1}, shadow_color});
				vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 1.0f : 0.0f)});
				vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 1.0f : 0.0f)});
				vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 1.0f : 0.0f)});
				vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 1.0f : 0.0f)});
			}

			if (outline) {
				font->kind->font->outline_thickness = 2;
				font->kind->font->rendermode = ftgl::RENDER_OUTLINE_POSITIVE;
				ftgl::texture_glyph_t *doutline = font->kind->getGlyph(c);
				if (doutline) {
					float x0  = bx + x + doutline->offset_x * scale;
					float x1  = x0 + doutline->width * scale;
					float italicx = - doutline->offset_x * scale * italic;
					float y0 = by + (font->kind->font->ascender - doutline->offset_y) * scale;
					float y1 = y0 + (doutline->height) * scale;

					vertices.push_back({{1+x0+italicx, 1+y0, 0, 1},	{doutline->s0, doutline->t0}, outline_color});
					vertices.push_back({{1+x1+italicx, 1+y0, 0, 1},	{doutline->s1, doutline->t0}, outline_color});
					vertices.push_back({{1+x1, 1+y1, 0, 1},	{doutline->s1, doutline->t1}, outline_color});
					vertices.push_back({{1+x0, 1+y1, 0, 1},	{doutline->s0, doutline->t1}, outline_color});
					vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 3.0f : 2.0f)});
					vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 3.0f : 2.0f)});
					vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 3.0f : 2.0f)});
					vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 3.0f : 2.0f)});				}
			}

			vertices.push_back({{x0+italicx, y0, 0, 1},	{d->s0, d->t0}, {r, g, b, a}});
			vertices.push_back({{x1+italicx, y0, 0, 1},	{d->s1, d->t0}, {r, g, b, a}});
			vertices.push_back({{x1, y1, 0, 1},	{d->s1, d->t1}, {r, g, b, a}});
			vertices.push_back({{x0, y1, 0, 1},	{d->s0, d->t1}, {r, g, b, a}});
			vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 1.0f : 0.0f)});
			vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 1.0f : 0.0f)});
			vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 1.0f : 0.0f)});
			vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 1.0f : 0.0f)});

			// Much trickery, such dev
			if (style == FONT_STYLE_UNDERLINED) {
				ftgl::texture_glyph_t *ul = font->kind->getGlyph('_');
				if (ul) {
					float x0  = bx + x;
					float x1  = x0 + d->advance_x * scale;
					float y0 = by + (font->kind->font->ascender * 1.05 - ul->offset_y) * scale;
					float y1 = y0 + (ul->height) * scale;
					float s2 = (ul->s1 - ul->s0) / 1.5;

					vertices.push_back({{x0, y0, 0, 1},	{ul->s0 + s2, ul->t0}, {r, g, b, a}});
					vertices.push_back({{x1, y0, 0, 1},	{ul->s1 - s2, ul->t0}, {r, g, b, a}});
					vertices.push_back({{x1, y1, 0, 1},	{ul->s1 - s2, ul->t1}, {r, g, b, a}});
					vertices.push_back({{x0, y1, 0, 1},	{ul->s0 + s2, ul->t1}, {r, g, b, a}});
					vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 1.0f : 0.0f)});
					vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 1.0f : 0.0f)});
					vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 1.0f : 0.0f)});
					vertices_kind_info.push_back({(style == FONT_STYLE_BOLD ? 1.0f : 0.0f)});				}
			}			

			x += d->advance_x * scale * (style == FONT_STYLE_BOLD ? 1.1 : 1);
		}
	}
	return x;
}

void DORText::parseText() {
	clear();
	entities_container.clear();
	positions.clear();
	centered = false;
	setChanged(true);

	// printf("-- '%s'\n", text);
	// printf("==CUREC  %fx%fx%fx%f\n", font_color.r, font_color.g, font_color.b, font_color.a);
	// printf("==USEDC  %fx%fx%fx%f\n", used_color.r, used_color.g, used_color.b, used_color.a);

	if (!font) return;
	size_t len = strlen(text);
	if (!len) {
		used_color = font_color;
		used_last_color = font_last_color;
		used_font_style = default_style;
		return;
	}
	const char *str = text;
	float r = font_color.r, g = font_color.g, b = font_color.b, a = font_color.a;
	float lr = font_last_color.r, lg = font_last_color.g, lb = font_last_color.b, la = font_last_color.a;
	int max_width = line_max_width;
	int bx = 0, by = 0;

	setTexture(font->kind->getAtlasTexture(), LUA_NOREF);

	// Update VO size once, we are allocating a few more than neede in case of utf8 or control sequences, but we dont care
	vertices.reserve(len * 4);
	vertices_kind_info.reserve(len * 4);

	int font_h = font->getHeight();
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
	font_style style = default_style;

	last_glyph = 0;

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
			int future_size = (font->textSize(start, len, style)).x;

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
						lua_pushliteral(L, "getEntityDisplayObject");
						lua_gettable(L, -2);
						// Add parameters
						lua_pushvalue(L, -2);
						lua_pushnil(L);
						lua_pushnumber(L, font_h);
						lua_pushnumber(L, font_h);
						lua_pushboolean(L, false);
						lua_pushboolean(L, false);
						// Call method to get the DO
						lua_call(L, 6, 1);

						DisplayObject *c = userdata_to_DO(L, -1);
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
						goto endcolor;
					}

					string cname(next+1, (size_t)(codestop - (next+1)));
					Color *color = Color::find(cname);
					if (color) {
						vec4 rgba = color->get1();
						lr = r; lg = g; lb = b; la = a;
						r = rgba.r; g = rgba.g; b = rgba.b; a = rgba.a;
					// Hexacolor
					} else if (codestop - (next+1) == 6) {
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
				}
endcolor:

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

	used_font_style = style;
	used_color = vec4(r, g, b, a);
	used_last_color = vec4(lr, lg, lb, la);

	this->nb_lines = nb_lines;
	this->w = max_size;
	this->h = nb_lines * font_h;

	font->kind->updateAtlas(); // Make sure any texture changes are upload to the GPU
}

void DORText::parseTextSimple() {
	clear();
	entities_container.clear();
	positions.clear();
	centered = false;
	setChanged(true);

	if (!font) return;
	size_t len = strlen(text);
	if (!len) return;
	const char *str = text;
	float r = font_color.r, g = font_color.g, b = font_color.b, a = font_color.a;

	setTexture(font->kind->getAtlasTexture(), LUA_NOREF);

	// Update VO size once, we are allocating a few more than neede in case of utf8 or control sequences, but we dont care
	vertices.reserve(len * 4);

	int font_h = font->getHeight();
	this->w = addCharQuad(str, len, default_style, 0, 0, r, g, b, a);
	this->nb_lines = 1;
	this->h = font_h;

	font->kind->updateAtlas(); // Make sure any texture changes are upload to the GPU
}

void DORText::setText(const char *text, bool simple) {
	// text = "je suis un lon#BLUE#text loli\n loz #{italic}#AHAH plop je suis un lon#BLUE#text loli\n loz #{italic}#AHAH plop je suis un lon#BLUE#text loli\n loz #{italic}#AHAH plop je suis un lon#BLUE#text loli\n loz #{italic}#AHAH plop je suis un lon#BLUE#text loli\n loz #{italic}#AHAH plop je suis un lon#BLUE#text loli\n loz #{italic}#AHAH plop ";
	// ProfilerStart("nameOfProfile.log");
	// for (int i = 0; i < 10000; i++) {

	free((void*)this->text);
	size_t len = strlen(text);
	this->text = (char*)malloc(len + 1);
	strcpy(this->text, text);
	if (simple) parseTextSimple();
	else parseText();
	
	// }
	// ProfilerStop();
	// exit(0);
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

void DORText::render(RendererGL *container, mat4& cur_model, vec4& cur_color, bool cur_visible) {
	if (!visible || !cur_visible) return;
	DORVertexes::render(container, cur_model, cur_color, true);
	mat4 emodel = cur_model * model;
	vec4 ecolor = cur_color * color;
	entities_container.render(container, emodel, ecolor, true);
}

// void DORText::renderZ(RendererGL *container, mat4& cur_model, vec4& cur_color, bool cur_visible) {
// 	if (!visible || !cur_visible) return;
// 	DORVertexes::renderZ(container, cur_model, cur_color, true);
// 	mat4 emodel = cur_model * model;
// 	vec4 ecolor = cur_color * color;
// 	entities_container.renderZ(container, emodel, ecolor, true);
// }

DORText::DORText() {
	text = (char*)malloc(1);
	text[0] = '\0';
	font_color = {1, 1, 1, 1};
	entities_container.setParent(this);
	if (default_shader) setShader(default_shader);
	setDataKinds(VERTEX_BASE + VERTEX_KIND_INFO);
};

DORText::~DORText() {
	free((void*)text);
	refcleaner(&font_lua_ref);
};
