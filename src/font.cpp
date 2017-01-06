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
#include <map>

using namespace ftgl;
using namespace std;

static int nb_fonts = 0;

static bool default_atlas_chars_bold = FALSE;
static char *default_atlas_chars;

struct AtlasManager {
	char *data;
	size_t data_len;
	texture_atlas_t *atlas;
	texture_font_t *font;
	int used;
};

static map<string, AtlasManager> atlases;

static int set_default_atlas_chars(lua_State *L) {
	const char *n = luaL_checkstring(L, 1);	
	default_atlas_chars_bold = lua_toboolean(L, 2);

	free(default_atlas_chars);
	default_atlas_chars = strdup(n);
	return 0;
}

static int sdl_free_font(lua_State *L)
{
	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
	auto am = atlases.find(*f->fontname);
	if (am != atlases.end()) {
		am->second.used--;
		// printf("[FONT] delete use %s => %d\n", am->first.c_str(), am->second.used);
		if (am->second.used <= 0) {
			printf("[FONT] deleting font %s => %d\n", am->first.c_str(), am->second.used);
			glDeleteTextures(1, &am->second.atlas->id);
			texture_font_delete(am->second.font);
			texture_atlas_delete(am->second.atlas);
			free(am->second.data);
			nb_fonts--;
			atlases.erase(am);
		}
	}
	delete f->fontname;
	lua_pushnumber(L, 1);
	return 1;
}

static int sdl_new_font(lua_State *L)
{
	const char *name = luaL_checkstring(L, 1);
	float size = luaL_checknumber(L, 2);

	PHYSFS_file *fff = PHYSFS_openRead(name);
	if (!fff) {
		return luaL_error(L, "could not load font: %s (%d); file not found", name, (int)size);
		return 0;
	}

	font_type *f = (font_type*)lua_newuserdata(L, sizeof(font_type));
	auxiliar_setclass(L, "sdl{font}", -1);

	f->fontname = new string(name);

	auto am = atlases.find(*f->fontname);
	if (am != atlases.end()) { // Found, use it
		f->atlas = am->second.atlas;
		f->font = am->second.font;
		f->font_mem = am->second.data;
		f->font_mem_size = am->second.data_len;
		am->second.used++;
		printf("[FONT] add use %s => %d\n", am->first.c_str(), am->second.used);
	} else { // Not found, create it
		size_t len = PHYSFS_fileLength(fff);
		char *data = (char*)malloc(len * sizeof(char));
		size_t read = 0;
		while (read < len) {
			size_t rl = PHYSFS_read(fff, data + read, sizeof(char), len - read);
			if (rl <= 0) break;
			read += rl;
		}
		PHYSFS_close(fff);

		f->font_mem = data;
		f->font_mem_size = len;

		f->atlas = texture_atlas_new(DEFAULT_ATLAS_W, DEFAULT_ATLAS_H, 1);
		f->font = texture_font_new_from_memory(f->atlas, 32, data, len);
		f->font->rendermode = RENDER_SIGNED_DISTANCE_FIELD;
		texture_font_load_glyphs(f->font, default_atlas_chars);

		glGenTextures(1, &f->atlas->id);
		glBindTexture(GL_TEXTURE_2D, f->atlas->id );
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );

		font_update_atlas(f);
		atlases[*f->fontname] = (AtlasManager){ data, len, f->atlas, f->font, 1 };
		printf("[FONT] new use %s => %d\n", name, 1);
		nb_fonts++;
	}


	f->scale = size / 32.0;
	// f->lineskip = (f->font->ascender - f->font->descender + f->font->linegap) * f->scale;
	// f->lineskip = (f->font->ascender - f->font->descender + f->font->linegap);
	f->lineskip = f->font->height;

	return 1;
}

#define FONT_PADDING 2
bool font_add_atlas(font_type *f, int32_t c, font_style style) {
}

void font_update_atlas(font_type *f) {
	if (f->atlas->changed) {
		glBindTexture(GL_TEXTURE_2D, f->atlas->id);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_ALPHA, f->atlas->width, f->atlas->height, 0, GL_ALPHA, GL_UNSIGNED_BYTE, f->atlas->data);
	}
}

static int sdl_font_get_atlas_size(lua_State *L)
{
	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
	lua_pushnumber(L, f->atlas->width);
	lua_pushnumber(L, f->atlas->height);
	return 2;
}

static int sdl_font_size(lua_State *L)
{
	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
	size_t len;
	const char *str = luaL_checklstring(L, 2, &len);

	int x = 0;
	ssize_t off = 1;
	int32_t c, oldc = 0;
	while (off > 0) {
		off = utf8proc_iterate((const uint8_t*)str, len, &c);
		str += off;
		len -= off;

		texture_glyph_t *d = ftgl::texture_font_get_glyph(f->font, c);
		if (d) {
			if (oldc) {
				x += texture_glyph_get_kerning(d, oldc) * f->scale;
			}
			x += d->advance_x * f->scale;
		}
		oldc = c;
	}

	lua_pushnumber(L, x);
	lua_pushnumber(L, f->lineskip * f->scale);
	return 2;
}

static int sdl_font_height(lua_State *L)
{
	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
	lua_pushnumber(L, f->lineskip * f->scale);
	return 1;
}

static int sdl_font_lineskip(lua_State *L)
{
	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
	lua_pushnumber(L, f->lineskip * f->scale);
	return 1;
}

static int sdl_font_style_get(lua_State *L)
{
	// font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
	// int style = TTF_GetFontStyle(f->font);

	// if (style & TTF_STYLE_BOLD) lua_pushliteral(L, "bold");
	// else if (style & TTF_STYLE_ITALIC) lua_pushliteral(L, "italic");
	// else if (style & TTF_STYLE_UNDERLINE) lua_pushliteral(L, "underline");
	// else lua_pushliteral(L, "normal");
	lua_pushliteral(L, "normal");
	return 1;
}

static int sdl_font_style(lua_State *L)
{
	// font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
	// const char *style = luaL_checkstring(L, 2);

	// if (!strcmp(style, "normal")) TTF_SetFontStyle(f->font, 0);
	// else if (!strcmp(style, "bold")) TTF_SetFontStyle(f->font, TTF_STYLE_BOLD);
	// else if (!strcmp(style, "italic")) TTF_SetFontStyle(f->font, TTF_STYLE_ITALIC);
	// else if (!strcmp(style, "underline")) TTF_SetFontStyle(f->font, TTF_STYLE_UNDERLINE);
	return 0;
}

static int sdl_new_tile(lua_State *L)
{
	int w = luaL_checknumber(L, 1);
	int h = luaL_checknumber(L, 2);
	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 3);
	size_t lenstr;
	const char *str = luaL_checklstring(L, 4, &lenstr);
	int x = luaL_checknumber(L, 5);
	int y = luaL_checknumber(L, 6);
	int r = luaL_checknumber(L, 7);
	int g = luaL_checknumber(L, 8);
	int b = luaL_checknumber(L, 9);
	int br = luaL_checknumber(L, 10);
	int bg = luaL_checknumber(L, 11);
	int bb = luaL_checknumber(L, 12);
	int alpha = luaL_checknumber(L, 13);

	SDL_Color color = {r,g,b};
	// SDL_Surface *txt = TTF_RenderUTF8_Blended(f->font, str, color);
	int32_t c;
	utf8proc_iterate((const uint8_t*)str, lenstr, &c);
	texture_glyph_t *d = ftgl::texture_font_get_glyph(f->font, c);

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

static int sdl_font_total(lua_State *L)
{
	lua_pushnumber(L, nb_fonts);
	return 1;
}


static const struct luaL_Reg sdl_font_reg[] =
{
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
	{"fontDefaultAtlasChars", set_default_atlas_chars},
	{"newFont", sdl_new_font},
	{"newTile", sdl_new_tile},
	{"totalOpenFonts", sdl_font_total},
	{NULL, NULL}
};

int luaopen_font(lua_State *L)
{
	default_atlas_chars = strdup("abcdefghijklmopqrstuvwxyzABCDEFGHIJKLMOPQRSTUVWXYZ0123456789.-/*&~\"'\\{}()[]|^%%*$! =+,€");
	default_atlas_chars_bold = FALSE;

	auxiliar_newclass(L, "sdl{font}", sdl_font_reg);
	lua_getglobal(L, "core");
	lua_getfield(L, -1, "display");
	luaL_register(L, NULL, fontlib);
	lua_pop(L, 2);

	if (!default_atlas_chars) utf8proc_iterate(NULL, 0, NULL); // DGDGDGDG: WTF ??? Without it the lib is not compiled in ? -- This codeis never even executed
	return 1;
}
