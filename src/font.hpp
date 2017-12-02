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
#include <unordered_map>

#define GLM_FORCE_INLINE
#include "glm/glm.hpp"

using namespace std;

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

using CodepointGlyphMap = unordered_map<uint32_t, ftgl::texture_glyph_t*>;

class FontInstance;
class DORText;

class FontKind {
	friend FontInstance;
	friend DORText;
protected:
	static unordered_map<string, FontKind*> all_fonts;
	const string default_atlas_chars = "abcdefghijklmopqrstuvwxyzABCDEFGHIJKLMOPQRSTUVWXYZ0123456789.-_/*&~\"'\\{}()[]|^%%*$! =+,€";

	string fontname;
	char *font_mem;
	int32_t font_mem_size;
	float lineskip;
	ftgl::texture_atlas_t *atlas;
	ftgl::texture_font_t *font;

	CodepointGlyphMap glyph_map_normal;
	CodepointGlyphMap glyph_map_outline;

	int32_t nb_use = 0;
public:
	static FontKind* getFont(string &name);

	FontKind(string &name);
	~FontKind();

	void used(bool v);
	void updateAtlas();
	inline glm::vec2 getAtlasSize() { return {atlas->width, atlas->height}; }
	inline float lineSkip() { return lineskip; }
	inline GLuint getAtlasTexture() { return atlas->id; }

	inline ftgl::texture_glyph_t* getGlyph(uint32_t codepoint) {
		CodepointGlyphMap *glyph_map = &glyph_map_normal;
		if (font->rendermode == ftgl::RENDER_OUTLINE_POSITIVE) glyph_map = &glyph_map_outline;

		auto it = glyph_map->find(codepoint);
		if (it != glyph_map->end()) return it->second;

		ftgl::texture_glyph_t *g = ftgl::texture_font_get_glyph(font, codepoint);
		if (g) {
			std::pair<uint32_t, ftgl::texture_glyph_t*> p(codepoint, g);
			glyph_map->insert(p);
		}
		return g;
	}
};

class FontInstance {
public:
	FontKind *kind;
	float size;
	float scale;

	FontInstance(FontKind *fk, float size) : kind(fk), scale(size / 32.0), size(size) {};

	glm::vec2 textSize(const char *str, size_t len, font_style style=FONT_STYLE_NORMAL);
	inline glm::vec2 textSize(string &text, font_style style=FONT_STYLE_NORMAL) { return textSize(text.c_str(), text.size(), style); }
	inline float getHeight() { return kind->lineSkip() * scale; }
};

#endif
