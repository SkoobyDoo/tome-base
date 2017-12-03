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

extern "C" {
#include "lua.h"
#include "types.h"
#include "display.h"
#include "fov/fov.h"
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "script.h"
#include "display.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "main.h"
#include "utf8proc/utf8proc.h"
}
#include "font.hpp"

using namespace ftgl;
using namespace std;

static int nb_fonts = 0;


/************************************************************
 ** FontKind
 ************************************************************/

unordered_map<string, FontKind*> FontKind::all_fonts;
void FontKind::used(bool v) {
	nb_use += v ? 1 : -1;
}

FontKind* FontKind::getFont(string &name) {
	auto am = all_fonts.find(name);
	if (am != all_fonts.end()) { // Found, use it
		FontKind *fk = am->second;
		fk->used(true);
		printf("[FONT] add use %s => %d\n", fk->fontname.c_str(), fk->nb_use);
		return fk;
	} else { // Not found, create it, we assume the file exists, check is before
		FontKind *fk = new FontKind(name);
		fk->used(true);
		all_fonts.emplace(name, fk);
		printf("[FONT] create %s\n", fk->fontname.c_str());
		return fk;
	}
}

FontKind::FontKind(string &name) : fontname(name) {
	PHYSFS_file *fff = PHYSFS_openRead(name.c_str());
	font_mem_size = PHYSFS_fileLength(fff);
	font_mem = new char[font_mem_size];
	size_t read = 0;
	while (read < font_mem_size) {
		size_t rl = PHYSFS_read(fff, font_mem + read, sizeof(char), font_mem_size - read);
		if (rl <= 0) break;
		read += rl;
	}
	PHYSFS_close(fff);

	atlas = texture_atlas_new(DEFAULT_ATLAS_W, DEFAULT_ATLAS_H, 1);
	font = texture_font_new_from_memory(atlas, 32, font_mem, font_mem_size);
	font->rendermode = RENDER_SIGNED_DISTANCE_FIELD;
	texture_font_load_glyphs(font, default_atlas_chars.c_str());
	lineskip = font->height;

	glGenTextures(1, &atlas->id);
	glBindTexture(GL_TEXTURE_2D, atlas->id );
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );

	updateAtlas();
}

FontKind::~FontKind() {
	glyph_map_normal.clear();
	glyph_map_outline.clear();
	glDeleteTextures(1, &atlas->id);
	texture_font_delete(font);
	texture_atlas_delete(atlas);
	delete[] font_mem;
}

void FontKind::updateAtlas() {
	if (!atlas->changed) return;
	glBindTexture(GL_TEXTURE_2D, atlas->id);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_ALPHA, atlas->width, atlas->height, 0, GL_ALPHA, GL_UNSIGNED_BYTE, atlas->data);
	atlas->changed = false;
}


/************************************************************
 ** Lua Stuff
 ************************************************************/

extern "C" void font_cleanup() {
}

static int sdl_free_font(lua_State *L) {
	FontInstance *f = *(FontInstance**)auxiliar_checkclass(L, "sdl{font}", 1);
	delete f;
	lua_pushnumber(L, 1);
	return 1;
}

static int sdl_new_font(lua_State *L) {
	const char *name = luaL_checkstring(L, 1);
	float size = luaL_checknumber(L, 2);
	if (!PHYSFS_exists(name)) {
		return luaL_error(L, "could not load font: %s (%f); file not found", name, size);
		return 0;
	}

	FontInstance **fp = (FontInstance**)lua_newuserdata(L, sizeof(FontInstance*));
	auxiliar_setclass(L, "sdl{font}", -1);

	string fname(name);
	*fp = new FontInstance(FontKind::getFont(fname), size);
	return 1;
}
 
static int sdl_font_get_atlas_size(lua_State *L) {
	FontInstance *f = *(FontInstance**)auxiliar_checkclass(L, "sdl{font}", 1);
	auto s = f->kind->getAtlasSize();
	lua_pushnumber(L, s.x);
	lua_pushnumber(L, s.y);
	return 2;
}

glm::vec2 FontInstance::textSize(const char *str, size_t len, font_style style) {
	int x = 0;
	ssize_t off = 1;
	int32_t c, oldc = 0;
	while (off > 0) {
		off = utf8proc_iterate((const uint8_t*)str, len, &c);
		str += off;
		len -= off;

		texture_glyph_t *d = kind->getGlyph(c);
		if (d) {
			if (oldc) {
				x += texture_glyph_get_kerning(d, oldc) * scale;
			}
			x += d->advance_x * scale;
		}
		oldc = c;
	}
	return {x, kind->lineSkip() * scale};
}

static int sdl_font_size(lua_State *L) {
	FontInstance *f = *(FontInstance**)auxiliar_checkclass(L, "sdl{font}", 1);
	size_t len;
	const char *str = luaL_checklstring(L, 2, &len);

	auto s = f->textSize(str, len);
	lua_pushnumber(L, s.x);
	lua_pushnumber(L, s.y);
	return 2;
}

static int sdl_font_height(lua_State *L) {
	FontInstance *f = *(FontInstance**)auxiliar_checkclass(L, "sdl{font}", 1);
	lua_pushnumber(L, f->kind->lineSkip() * f->scale);
	return 1;
}

static int sdl_font_lineskip(lua_State *L) {
	FontInstance *f = *(FontInstance**)auxiliar_checkclass(L, "sdl{font}", 1);
	lua_pushnumber(L, f->kind->lineSkip() * f->scale);
	return 1;
}

static int sdl_font_style_get(lua_State *L) {
	// font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
	// int style = TTF_GetFontStyle(f->font);

	// if (style & TTF_STYLE_BOLD) lua_pushliteral(L, "bold");
	// else if (style & TTF_STYLE_ITALIC) lua_pushliteral(L, "italic");
	// else if (style & TTF_STYLE_UNDERLINE) lua_pushliteral(L, "underline");
	// else lua_pushliteral(L, "normal");
	lua_pushliteral(L, "normal");
	return 1;
}

static int sdl_font_style(lua_State *L) {
	// font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
	// const char *style = luaL_checkstring(L, 2);

	// if (!strcmp(style, "normal")) TTF_SetFontStyle(f->font, 0);
	// else if (!strcmp(style, "bold")) TTF_SetFontStyle(f->font, TTF_STYLE_BOLD);
	// else if (!strcmp(style, "italic")) TTF_SetFontStyle(f->font, TTF_STYLE_ITALIC);
	// else if (!strcmp(style, "underline")) TTF_SetFontStyle(f->font, TTF_STYLE_UNDERLINE);
	return 0;
}

static int sdl_new_tile(lua_State *L) {
	int w = luaL_checknumber(L, 1);
	int h = luaL_checknumber(L, 2);
	FontInstance *f = *(FontInstance**)auxiliar_checkclass(L, "sdl{font}", 3);
	size_t lenstr;
	const char *str = luaL_checklstring(L, 4, &lenstr);
	int x = luaL_checknumber(L, 5);
	int y = luaL_checknumber(L, 6);
	Uint8 r = luaL_checknumber(L, 7);
	Uint8 g = luaL_checknumber(L, 8);
	Uint8 b = luaL_checknumber(L, 9);
	Uint8 br = luaL_checknumber(L, 10);
	Uint8 bg = luaL_checknumber(L, 11);
	Uint8 bb = luaL_checknumber(L, 12);
	Uint8 alpha = luaL_checknumber(L, 13);

	SDL_Color color = {r,g,b};
	// SDL_Surface *txt = TTF_RenderUTF8_Blended(f->font, str, color);
	int32_t c;
	utf8proc_iterate((const uint8_t*)str, lenstr, &c);
	// texture_glyph_t *d = ftgl::texture_font_get_glyph(f->font, c);

	SDL_Surface **s = (SDL_Surface**)lua_newuserdata(L, sizeof(SDL_Surface*));
	auxiliar_setclass(L, "sdl{surface}", -1);

	Uint32 rmask, gmask, bmask, amask;
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
	rmask = 0xff000000;
	gmask = 0x00ff0000;
	bmask = 0x0000ff00;
	amask = 0x000000ff;
#else
	rmask = 0x000000ff;
	gmask = 0x0000ff00;
	bmask = 0x00ff0000;
	amask = 0xff000000;
#endif

	*s = SDL_CreateRGBSurface(
		SDL_SWSURFACE,
		w,
		h,
		32,
		rmask, gmask, bmask, amask
		);

	SDL_FillRect(*s, NULL, SDL_MapRGBA((*s)->format, br, bg, bb, alpha));

	// DGDGDGDG -- make newTile work again
	// if (txt)
	// {
		// if (!alpha) SDL_SetAlpha(txt, 0, 0);
		// sdlDrawImage(*s, txt, x, y);

		// SDL_Rect r;
		// r.w=image->w;
		// r.h=image->h;
		// r.x=x;
		// r.y=y;
		// int errcode = SDL_BlitSurface(image, NULL, *s, &r);

		// SDL_FreeSurface(txt);
	// }

	return 1;
}

static int sdl_font_total(lua_State *L) {
	lua_pushnumber(L, nb_fonts);
	return 1;
}

static const struct luaL_Reg sdl_font_reg[] = {
	{"__gc", sdl_free_font},
	{"close", sdl_free_font},
	{"size", sdl_font_size},
	{"height", sdl_font_height},
	{"lineSkip", sdl_font_lineskip},
	{"setStyle", sdl_font_style},
	{"getStyle", sdl_font_style_get},
	{NULL, NULL},
};

const luaL_Reg fontlib[] = {
	{"newFont", sdl_new_font},
	{"newTile", sdl_new_tile},
	{"totalOpenFonts", sdl_font_total},
	{NULL, NULL}
};

int luaopen_font(lua_State *L) {
	auxiliar_newclass(L, "sdl{font}", sdl_font_reg);
	lua_getglobal(L, "core");
	lua_getfield(L, -1, "display");
	luaL_register(L, NULL, fontlib);
	lua_pop(L, 2);
	return 1;
}
