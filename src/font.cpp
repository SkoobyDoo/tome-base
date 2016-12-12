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
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, f->atlas->width, f->atlas->height, 0, GL_RED, GL_UNSIGNED_BYTE, f->atlas->data);
	}
}

static int sdl_font_get_atlas_size(lua_State *L)
{
	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
	lua_pushnumber(L, f->atlas->width);
	lua_pushnumber(L, f->atlas->height);
	return 2;
}

// static int sdl_font_atlas_debug(lua_State *L)
// {
// 	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
// 	if (!f->atlas) font_make_atlas(f, 0, 0);
// 	int x = luaL_checknumber(L, 2);
// 	int y = luaL_checknumber(L, 3);
// 	int w = luaL_checknumber(L, 4);
// 	int h = luaL_checknumber(L, 5);

// 	vertex_clear(generic_vx);
// 	vertex_add_quad(generic_vx,
// 		0, 0, 0, 0,
// 		0, h, 0, 1,
// 		w, h, 1, 1,
// 		w, 0, 1, 0,
// 		1, 1, 1, 1
// 	);
// 	vertex_toscreen(generic_vx, x, y, f->atlas_tex, 1, 1, 1, 1);

// 	return 0;
// }

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
			x += 1.05 * d->advance_x * f->scale; // WTF without a 110% factor letters always look too close .. uh
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

// int sdl_surface_drawstring(lua_State *L)
// {
// 	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
// 	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 2);
// 	const char *str = luaL_checkstring(L, 3);
// 	int x = luaL_checknumber(L, 4);
// 	int y = luaL_checknumber(L, 5);
// 	int r = luaL_checknumber(L, 6);
// 	int g = luaL_checknumber(L, 7);
// 	int b = luaL_checknumber(L, 8);
// 	bool alpha_from_texture = lua_toboolean(L, 9);

// 	SDL_Color color = {r,g,b};
// 	SDL_Surface *txt = TTF_RenderUTF8_Blended(f->font, str, color);
// 	if (txt)
// 	{
// 		if (alpha_from_texture) SDL_SetAlpha(txt, 0, 0);
// 		sdlDrawImage(*s, txt, x, y);
// 		SDL_FreeSurface(txt);
// 	}

// 	return 0;
// }

// int sdl_surface_drawstring_aa(lua_State *L)
// {
// 	if (no_text_aa) return sdl_surface_drawstring(L);
// 	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
// 	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 2);
// 	const char *str = luaL_checkstring(L, 3);
// 	int x = luaL_checknumber(L, 4);
// 	int y = luaL_checknumber(L, 5);
// 	int r = luaL_checknumber(L, 6);
// 	int g = luaL_checknumber(L, 7);
// 	int b = luaL_checknumber(L, 8);
// 	bool alpha_from_texture = lua_toboolean(L, 9);

// 	SDL_Color color = {r,g,b};
// 	SDL_Surface *txt = TTF_RenderUTF8_Blended(f->font, str, color);
// 	if (txt)
// 	{
// 		if (alpha_from_texture) SDL_SetAlpha(txt, 0, 0);
// 		sdlDrawImage(*s, txt, x, y);
// 		SDL_FreeSurface(txt);
// 	}

// 	return 0;
// }

// static int sdl_surface_drawstring_newsurface(lua_State *L)
// {
// 	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
// 	const char *str = luaL_checkstring(L, 2);
// 	int r = luaL_checknumber(L, 3);
// 	int g = luaL_checknumber(L, 4);
// 	int b = luaL_checknumber(L, 5);

// 	SDL_Color color = {r,g,b};
// 	SDL_Surface *txt = TTF_RenderUTF8_Blended(f->font, str, color);
// 	if (txt)
// 	{
// 		SDL_Surface **s = (SDL_Surface**)lua_newuserdata(L, sizeof(SDL_Surface*));
// 		auxiliar_setclass(L, "sdl{surface}", -1);
// 		*s = SDL_DisplayFormatAlpha(txt);
// 		SDL_FreeSurface(txt);
// 		return 1;
// 	}

// 	lua_pushnil(L);
// 	return 1;
// }


// static int sdl_surface_drawstring_newsurface_aa(lua_State *L)
// {
// 	if (no_text_aa) return sdl_surface_drawstring_newsurface(L);
// 	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
// 	const char *str = luaL_checkstring(L, 2);
// 	int r = luaL_checknumber(L, 3);
// 	int g = luaL_checknumber(L, 4);
// 	int b = luaL_checknumber(L, 5);

// 	SDL_Color color = {r,g,b};
// 	SDL_Surface *txt = TTF_RenderUTF8_Blended(f->font, str, color);
// 	if (txt)
// 	{
// 		SDL_Surface **s = (SDL_Surface**)lua_newuserdata(L, sizeof(SDL_Surface*));
// 		auxiliar_setclass(L, "sdl{surface}", -1);
// 		*s = SDL_DisplayFormatAlpha(txt);
// 		SDL_FreeSurface(txt);
// 		return 1;
// 	}

// 	lua_pushnil(L);
// 	return 1;
// }

// static int sdl_new_tile(lua_State *L)
// {
// 	int w = luaL_checknumber(L, 1);
// 	int h = luaL_checknumber(L, 2);
// 	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 3);
// 	const char *str = luaL_checkstring(L, 4);
// 	int x = luaL_checknumber(L, 5);
// 	int y = luaL_checknumber(L, 6);
// 	int r = luaL_checknumber(L, 7);
// 	int g = luaL_checknumber(L, 8);
// 	int b = luaL_checknumber(L, 9);
// 	int br = luaL_checknumber(L, 10);
// 	int bg = luaL_checknumber(L, 11);
// 	int bb = luaL_checknumber(L, 12);
// 	int alpha = luaL_checknumber(L, 13);

// 	SDL_Color color = {r,g,b};
// 	SDL_Surface *txt = TTF_RenderUTF8_Blended(f->font, str, color);

// 	SDL_Surface **s = (SDL_Surface**)lua_newuserdata(L, sizeof(SDL_Surface*));
// 	auxiliar_setclass(L, "sdl{surface}", -1);

// 	Uint32 rmask, gmask, bmask, amask;
// #if SDL_BYTEORDER == SDL_BIG_ENDIAN
// 	rmask = 0xff000000;
// 	gmask = 0x00ff0000;
// 	bmask = 0x0000ff00;
// 	amask = 0x000000ff;
// #else
// 	rmask = 0x000000ff;
// 	gmask = 0x0000ff00;
// 	bmask = 0x00ff0000;
// 	amask = 0xff000000;
// #endif

// 	*s = SDL_CreateRGBSurface(
// 		SDL_SWSURFACE,
// 		w,
// 		h,
// 		32,
// 		rmask, gmask, bmask, amask
// 		);

// 	SDL_FillRect(*s, NULL, SDL_MapRGBA((*s)->format, br, bg, bb, alpha));

// 	if (txt)
// 	{
// 		if (!alpha) SDL_SetAlpha(txt, 0, 0);
// 		sdlDrawImage(*s, txt, x, y);
// 		SDL_FreeSurface(txt);
// 	}

// 	return 1;
// }

// static void font_make_texture_line(lua_State *L, SDL_Surface *s, int id, bool is_separator, int id_real_line, char *line_data, int line_data_size, bool direct_uid_draw, int realsize)
// {
// 	lua_createtable(L, 0, 9);

// 	if (direct_uid_draw)
// 	{
// 		lua_pushliteral(L, "_dduids");
// 		lua_pushvalue(L, -4);
// 		lua_rawset(L, -3);

// 		// Replace dduids by a new one
// 		lua_newtable(L);
// 		lua_replace(L, -4);
// 	}

// 	lua_pushliteral(L, "_tex");
// 	texture_type *t = (texture_type*)lua_newuserdata(L, sizeof(texture_type));
// 	auxiliar_setclass(L, "gl{texture}", -1);
// 	lua_rawset(L, -3);

// 	glGenTextures(1, &t->tex);
// 	tfglBindTexture(GL_TEXTURE_2D, t->tex);
// 	int fw, fh;
// 	make_texture_for_surface(s, &fw, &fh, true);
// 	copy_surface_to_texture(s);
// 	t->w = fw;
// 	t->h = fh;
// 	t->no_free = FALSE;

// 	lua_pushliteral(L, "_tex_w");
// 	lua_pushnumber(L, fw);
// 	lua_rawset(L, -3);
// 	lua_pushliteral(L, "_tex_h");
// 	lua_pushnumber(L, fh);
// 	lua_rawset(L, -3);

// 	lua_pushliteral(L, "w");
// 	lua_pushnumber(L, s->w);
// 	lua_rawset(L, -3);
// 	lua_pushliteral(L, "h");
// 	lua_pushnumber(L, s->h);
// 	lua_rawset(L, -3);

// 	lua_pushliteral(L, "line");
// 	lua_pushnumber(L, id_real_line);
// 	lua_rawset(L, -3);

// 	lua_pushliteral(L, "realw");
// 	lua_pushnumber(L, realsize);
// 	lua_rawset(L, -3);

// 	if (line_data)
// 	{
// 		lua_pushliteral(L, "line_extra");
// 		lua_pushlstring(L, line_data, line_data_size);
// 		lua_rawset(L, -3);
// 	}

// 	if (is_separator)
// 	{
// 		lua_pushliteral(L, "is_separator");
// 		lua_pushboolean(L, TRUE);
// 		lua_rawset(L, -3);
// 	}

// 	lua_rawseti(L, -2, id);
// }

// static int sdl_font_draw(lua_State *L)
// {
// 	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
// 	const char *str = luaL_checkstring(L, 2);
// 	int max_width = luaL_checknumber(L, 3);
// 	int r = luaL_checknumber(L, 4);
// 	int g = luaL_checknumber(L, 5);
// 	int b = luaL_checknumber(L, 6);
// 	bool no_linefeed = lua_toboolean(L, 7);
// 	bool direct_uid_draw = lua_toboolean(L, 8);
// 	int h = TTF_FontHeight(f->font);
// 	SDL_Color color = {r,g,b};

// 	int fullmax = max_texture_size / 2;
// 	if (fullmax < 1024) fullmax = 1024;
// 	if (max_width >= fullmax) max_width = fullmax;

// 	Uint32 rmask, gmask, bmask, amask;
// #if SDL_BYTEORDER == SDL_BIG_ENDIAN
// 	rmask = 0xff000000; gmask = 0x00ff0000; bmask = 0x0000ff00; amask = 0x000000ff;
// #else
// 	rmask = 0x000000ff; gmask = 0x0000ff00; bmask = 0x00ff0000; amask = 0xff000000;
// #endif
// 	SDL_Surface *s = SDL_CreateRGBSurface(SDL_SWSURFACE, max_width, h, 32, rmask, gmask, bmask, amask);
// 	SDL_FillRect(s, NULL, SDL_MapRGBA(s->format, 0, 0, 0, 0));

// 	int id_dduid = 1;
// 	if (direct_uid_draw)
// 	{
// 		lua_newtable(L);
// 	}

// 	lua_newtable(L);

// 	int nb_lines = 1;
// 	int id_real_line = 1;
// 	char *line_data = NULL;
// 	int line_data_size = 0;
// 	char *start = (char*)str, *stop = (char*)str, *next = (char*)str;
// 	int max_size = 0;
// 	int size = 0;
// 	bool is_separator = FALSE;
// 	int i;
// 	bool force_nl = FALSE;
// 	SDL_Surface *txt = NULL;
// 	while (TRUE)
// 	{
// 		if ((*next == '\n') || (*next == ' ') || (*next == '\0') || (*next == '#'))
// 		{
// 			bool inced = FALSE;
// 			if (*next == ' ' && *(next+1))
// 			{
// 				inced = TRUE;
// 				stop = next;
// 				next++;
// 			}
// 			else stop = next - 1;

// 			// Make a surface for the word
// 			char old = *next;
// 			*next = '\0';
// 			if (txt) SDL_FreeSurface(txt);
// 			if (no_text_aa) txt = TTF_RenderUTF8_Blended(f->font, start, color);
// 			else txt = TTF_RenderUTF8_Blended(f->font, start, color);

// 			// If we must do a newline, flush the previous word and the start the new line
// 			if (!no_linefeed && (force_nl || (txt && (size + txt->w > max_width))))
// 			{
// 				// Push it & reset the surface
// 				font_make_texture_line(L, s, nb_lines, is_separator, id_real_line, line_data, line_data_size, direct_uid_draw, size);
// 				id_dduid = 1;
// 				is_separator = FALSE;
// 				SDL_FillRect(s, NULL, SDL_MapRGBA(s->format, 0, 0, 0, 0));
// //				printf("Ending previous line at size %d\n", size);
// 				if (size > max_size) max_size = size;
// 				size = 0;
// 				nb_lines++;
// 				if (force_nl)
// 				{
// 					id_real_line++;
// 					if (line_data) { line_data = NULL; }
// 				}
// 				force_nl = FALSE;
// 			}

// 			if (txt)
// 			{
// 				// Detect separators
// 				if ((*start == '-') && (*(start+1) == '-') && (*(start+2) == '-') && !(*(start+3))) is_separator = TRUE;

// //				printf("Drawing word '%s'\n", start);
// 				SDL_SetAlpha(txt, 0, 0);
// 				sdlDrawImage(s, txt, size, 0);
// 				size += txt->w;
// 			}
// 			*next = old;
// 			if (inced) next--;
// 			start = next + 1;

// 			// Force a linefeed
// 			if (*next == '\n') force_nl = TRUE;

// 			// Handle special codes
// 			else if (*next == '#')
// 			{
// 				char *codestop = next + 1;
// 				while (*codestop && *codestop != '#') codestop++;
// 				// Font style
// 				if (*(next+1) == '{') {
// 					if (*(next+2) == 'n') TTF_SetFontStyle(f->font, 0);
// 					else if (*(next+2) == 'b') TTF_SetFontStyle(f->font, TTF_STYLE_BOLD);
// 					else if (*(next+2) == 'i') TTF_SetFontStyle(f->font, TTF_STYLE_ITALIC);
// 					else if (*(next+2) == 'u') TTF_SetFontStyle(f->font, TTF_STYLE_UNDERLINE);
// 				}
// 				// Entity UID
// 				else if ((codestop - (next+1) > 4) && (*(next+1) == 'U') && (*(next+2) == 'I') && (*(next+3) == 'D') && (*(next+4) == ':')) {
// 					if (!direct_uid_draw)
// 					{
// 						lua_getglobal(L, "__get_uid_surface");
// 						char *colon = next + 5;
// 						while (*colon && *colon != ':') colon++;
// 						lua_pushlstring(L, next+5, colon - (next+5));
// //						printf("Drawing UID %s\n", lua_tostring(L,-1));
// 						lua_pushnumber(L, h);
// 						lua_pushnumber(L, h);
// 						lua_call(L, 3, 1);
// 						if (lua_isuserdata(L, -1))
// 						{
// 							SDL_Surface **img = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", -1);
// 							sdlDrawImage(s, *img, size, 0);
// 							size += (*img)->w;
// 						}
// 						lua_pop(L, 1);
// 					}
// 					else
// 					{
// 						lua_getglobal(L, "__get_uid_entity");
// 						char *colon = next + 5;
// 						while (*colon && *colon != ':') colon++;
// 						lua_pushlstring(L, next+5, colon - (next+5));
// 						lua_call(L, 1, 1);
// 						if (lua_istable(L, -1))
// 						{
// //							printf("DirectDrawUID in font:draw %d : %d\n", size, h);
// 							lua_createtable(L, 0, 4);

// 							lua_pushliteral(L, "e");
// 							lua_pushvalue(L, -3);
// 							lua_rawset(L, -3);

// 							lua_pushliteral(L, "x");
// 							lua_pushnumber(L, size);
// 							lua_rawset(L, -3);

// 							lua_pushliteral(L, "w");
// 							lua_pushnumber(L, h);
// 							lua_rawset(L, -3);

// 							lua_rawseti(L, -4, id_dduid++); // __dduids

// 							size += h;
// 						}
// 						lua_pop(L, 1);
// 					}
// 				}
// 				// Extra data
// 				else if (*(next+1) == '&') {
// 					line_data = next + 2;
// 					line_data_size = codestop - (next+2);
// 				}
// 				// Color
// 				else {
// 					if ((codestop - (next+1) == 4) && (*(next+1) == 'L') && (*(next+2) == 'A') && (*(next+3) == 'S') && (*(next+4) == 'T'))
// 					{
// 						color.r = r;
// 						color.g = g;
// 						color.b = b;
// 					}

// 					lua_getglobal(L, "colors");
// 					lua_pushlstring(L, next+1, codestop - (next+1));
// 					lua_rawget(L, -2);
// 					if (lua_istable(L, -1)) {
// 						r = color.r;
// 						g = color.g;
// 						b = color.b;

// 						lua_pushliteral(L, "r");
// 						lua_rawget(L, -2);
// 						color.r = lua_tonumber(L, -1);
// 						lua_pushliteral(L, "g");
// 						lua_rawget(L, -3);
// 						color.g = lua_tonumber(L, -1);
// 						lua_pushliteral(L, "b");
// 						lua_rawget(L, -4);
// 						color.b = lua_tonumber(L, -1);
// 						lua_pop(L, 3);
// 					}
// 					// Hexacolor
// 					else if (codestop - (next+1) == 6)
// 					{
// 						r = color.r;
// 						g = color.g;
// 						b = color.b;

// 						int rh = 0, gh = 0, bh = 0;

// 						if ((*(next+1) >= '0') && (*(next+1) <= '9')) rh += 16 * (*(next+1) - '0');
// 						else if ((*(next+1) >= 'a') && (*(next+1) <= 'f')) rh += 16 * (10 + *(next+1) - 'a');
// 						else if ((*(next+1) >= 'A') && (*(next+1) <= 'F')) rh += 16 * (10 + *(next+1) - 'A');
// 						if ((*(next+2) >= '0') && (*(next+2) <= '9')) rh += (*(next+2) - '0');
// 						else if ((*(next+2) >= 'a') && (*(next+2) <= 'f')) rh += (10 + *(next+2) - 'a');
// 						else if ((*(next+2) >= 'A') && (*(next+2) <= 'F')) rh += (10 + *(next+2) - 'A');

// 						if ((*(next+3) >= '0') && (*(next+3) <= '9')) gh += 16 * (*(next+3) - '0');
// 						else if ((*(next+3) >= 'a') && (*(next+3) <= 'f')) gh += 16 * (10 + *(next+3) - 'a');
// 						else if ((*(next+3) >= 'A') && (*(next+3) <= 'F')) gh += 16 * (10 + *(next+3) - 'A');
// 						if ((*(next+4) >= '0') && (*(next+4) <= '9')) gh += (*(next+4) - '0');
// 						else if ((*(next+4) >= 'a') && (*(next+4) <= 'f')) gh += (10 + *(next+4) - 'a');
// 						else if ((*(next+4) >= 'A') && (*(next+4) <= 'F')) gh += (10 + *(next+4) - 'A');

// 						if ((*(next+5) >= '0') && (*(next+5) <= '9')) bh += 16 * (*(next+5) - '0');
// 						else if ((*(next+5) >= 'a') && (*(next+5) <= 'f')) bh += 16 * (10 + *(next+5) - 'a');
// 						else if ((*(next+5) >= 'A') && (*(next+5) <= 'F')) bh += 16 * (10 + *(next+5) - 'A');
// 						if ((*(next+6) >= '0') && (*(next+6) <= '9')) bh += (*(next+6) - '0');
// 						else if ((*(next+6) >= 'a') && (*(next+6) <= 'f')) bh += (10 + *(next+6) - 'a');
// 						else if ((*(next+6) >= 'A') && (*(next+6) <= 'F')) bh += (10 + *(next+6) - 'A');

// 						color.r = rh;
// 						color.g = gh;
// 						color.b = bh;
// 					}
// 					lua_pop(L, 2);
// 				}

// 				char old = *codestop;
// 				*codestop = '\0';
// //				printf("Found code: %s\n", next+1);
// 				*codestop = old;

// 				start = codestop + 1;
// 				next = codestop; // The while will increment it, so we dont so it here
// 			}
// 		}
// 		if (*next == '\0') break;
// 		next++;
// 	}

// 	font_make_texture_line(L, s, nb_lines, is_separator, id_real_line, line_data, line_data_size, direct_uid_draw, size);
// 	id_dduid = 1;
// 	if (size > max_size) max_size = size;

// 	if (txt) SDL_FreeSurface(txt);
// 	SDL_FreeSurface(s);

// 	lua_pushnumber(L, nb_lines);
// 	lua_pushnumber(L, max_size);

// 	if (direct_uid_draw) lua_remove(L, -4);

// 	return 3;
// }

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
	// {"draw", sdl_font_draw},
	// {"drawVO", sdl_font_draw_vo},
	// {"makeAtlas", sdl_font_make_atlas},
	// {"debugAtlas", sdl_font_atlas_debug},
	// {"getAtlasSize", sdl_font_get_atlas_size},
	{NULL, NULL},
};

const luaL_Reg fontlib[] = {
	{"fontDefaultAtlasChars", set_default_atlas_chars},
	{"newFont", sdl_new_font},
	// {"newTile", sdl_new_tile},
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
