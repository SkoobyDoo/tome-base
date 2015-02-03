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

#include "display.h"
#include "fov/fov.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "types.h"
#include "script.h"
#include "display.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "SFMT.h"
#include "main.h"
#include "vertex_objects.h"
#include "core_lua.h"
#include "font.h"
#include "utf8proc/utf8proc.h"

static int nb_fonts = 0;
static int nb_fonts_atlas = 0;

static bool no_text_aa = FALSE;

static bool default_atlas_chars_bold = FALSE;
static char *default_atlas_chars;

static int set_default_atlas_chars(lua_State *L) {
	const char *new = luaL_checkstring(L, 1);	
	default_atlas_chars_bold = lua_toboolean(L, 2);

	free(default_atlas_chars);
	default_atlas_chars = strdup(new);
	return 0;
}

static int sdl_free_font(lua_State *L)
{
	lua_font *f = (lua_font*)auxiliar_checkclass(L, "sdl{font}", 1);
	if (f->font) TTF_CloseFont(f->font);
	if (f->atlas) {
		SDL_FreeSurface(f->atlas);
		glDeleteTextures(1, &f->atlas_tex);
		free(f->atlas_data);
		nb_fonts_atlas--;
	}
	nb_fonts--;
	lua_pushnumber(L, 1);
	return 1;
}

static int sdl_new_font(lua_State *L)
{
	const char *name = luaL_checkstring(L, 1);
	int size = luaL_checknumber(L, 2);

	lua_font *f = (lua_font*)lua_newuserdata(L, sizeof(lua_font));
	auxiliar_setclass(L, "sdl{font}", -1);

	SDL_RWops *src = PHYSFSRWOPS_openRead(name);
	if (!src)
	{
		return luaL_error(L, "could not load font: %s (%d)", name, size);
	}

	f->font = TTF_OpenFontRW(src, TRUE, size);
	f->atlas = NULL;
	f->atlas_tex = 0;
	f->atlas_changed = FALSE;
	nb_fonts++;

	if (!f->font)
	{
		return luaL_error(L, "could not load font: %s (%d)", name, size);
	}
	return 1;
}

bool font_add_atlas(lua_font *f, int32_t c, font_style style) {
	if (c < 1 || c >= MAX_ATLAS_DATA) return FALSE;

	SDL_Color color = {255, 255, 255};
	int pstyle = TTF_GetFontStyle(f->font);
	if (style == FONT_STYLE_BOLD) TTF_SetFontStyle(f->font, TTF_STYLE_BOLD);
	SDL_Surface *txt = TTF_RenderGlyph_Blended(f->font, c, color);
	TTF_SetFontStyle(f->font, pstyle);
	if (txt)
	{
		if (f->atlas_x + txt->w >= f->atlas_w) {
			f->atlas_x = 0;
			f->atlas_y += txt->h;
		}
		SDL_SetAlpha(txt, 0, 0);
		sdlDrawImage(f->atlas, txt, f->atlas_x, f->atlas_y);

		font_atlas_data_style *d = &f->atlas_data[c].data[style];
		d->tx1 = (double)f->atlas_x / (double)f->atlas_w;
		d->tx2 = (double)(f->atlas_x + txt->w) / (double)f->atlas_w;
		d->ty1 = (double)f->atlas_y / (double)f->atlas_h;
		d->ty2 = (double)(f->atlas_y + txt->h) / (double)f->atlas_h;
		d->w = txt->w;
		d->h = txt->h;

		f->atlas_x += txt->w;
		f->atlas_changed = TRUE;
		SDL_FreeSurface(txt);
	}
}

void font_make_atlas(lua_font *f, int w, int h) {
	if (!w) w = DEFAULT_ATLAS_W;
	if (!h) h = DEFAULT_ATLAS_H;

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
	f->atlas = SDL_CreateRGBSurface(SDL_SWSURFACE, w, h, 32, rmask, gmask, bmask, amask);
	SDL_FillRect(f->atlas, NULL, SDL_MapRGBA(f->atlas->format, 0, 0, 0, 0));

	f->atlas_data = calloc(MAX_ATLAS_DATA, sizeof(font_atlas_data));

	f->atlas_w = w;
	f->atlas_h = h;
	f->atlas_x = 0;
	f->atlas_y = 0;

	char *str = default_atlas_chars;
	ssize_t len = strlen(str);
	ssize_t off = 1;
	int32_t c;
	while (off > 0) {
		off = utf8proc_iterate(str, len, &c);
		printf("%c\n", c);
		str += off;
		len -= off;

		if (c > 0) {
			font_add_atlas(f, c, FONT_STYLE_NORMAL);
			if (default_atlas_chars_bold) font_add_atlas(f, c, FONT_STYLE_BOLD);
		}
	}

	if (!f->atlas_tex) {
		glGenTextures(1, &f->atlas_tex);
		tfglBindTexture(GL_TEXTURE_2D, f->atlas_tex);
		make_texture_for_surface(f->atlas, NULL, NULL, false);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		copy_surface_to_texture(f->atlas);
	} else {
		tfglBindTexture(GL_TEXTURE_2D, f->atlas_tex);
		copy_surface_to_texture(f->atlas);
	}
	f->atlas_changed = FALSE;
	nb_fonts_atlas++;
}

static int sdl_font_make_atlas(lua_State *L)
{
	lua_font *f = (lua_font*)auxiliar_checkclass(L, "sdl{font}", 1);
	if (!f->atlas) font_make_atlas(f, lua_tonumber(L, 2), lua_tonumber(L, 3));
	return 0;
}

static int sdl_font_atlas_debug(lua_State *L)
{
	lua_font *f = (lua_font*)auxiliar_checkclass(L, "sdl{font}", 1);
	if (!f->atlas) font_make_atlas(f, 0, 0);
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);
	int w = luaL_checknumber(L, 4);
	int h = luaL_checknumber(L, 5);

	GLfloat texcoords[2*4] = {
		0, 0,
		0, 1,
		1, 1,
		1, 0,
	};
	GLfloat colors[4*4] = {
		1, 1, 1, 1,
		1, 1, 1, 1,
		1, 1, 1, 1,
		1, 1, 1, 1,
	};
	GLfloat vertices[2*4] = {
		x, y,
		x, y + h,
		x + w, y + h,
		x + w, y,
	};
	tglBindTexture(GL_TEXTURE_2D, f->atlas_tex);
	glColorPointer(4, GL_FLOAT, 0, colors);
	glTexCoordPointer(2, GL_FLOAT, 0, texcoords);
	glVertexPointer(2, GL_FLOAT, 0, vertices);
	glDrawArrays(GL_QUADS, 0, 4);

	return 0;
}

static int sdl_font_size(lua_State *L)
{
	lua_font *f = (lua_font*)auxiliar_checkclass(L, "sdl{font}", 1);
	const char *str = luaL_checkstring(L, 2);
	int w, h;

	if (!TTF_SizeUTF8(f->font, str, &w, &h))
	{
		lua_pushnumber(L, w);
		lua_pushnumber(L, h);
		return 2;
	}
	return 0;
}

static int sdl_font_height(lua_State *L)
{
	lua_font *f = (lua_font*)auxiliar_checkclass(L, "sdl{font}", 1);
	lua_pushnumber(L, TTF_FontHeight(f->font));
	return 1;
}

static int sdl_font_lineskip(lua_State *L)
{
	lua_font *f = (lua_font*)auxiliar_checkclass(L, "sdl{font}", 1);
	lua_pushnumber(L, TTF_FontLineSkip(f->font));
	return 1;
}

static int sdl_font_style_get(lua_State *L)
{
	lua_font *f = (lua_font*)auxiliar_checkclass(L, "sdl{font}", 1);
	int style = TTF_GetFontStyle(f->font);

	if (style & TTF_STYLE_BOLD) lua_pushliteral(L, "bold");
	else if (style & TTF_STYLE_ITALIC) lua_pushliteral(L, "italic");
	else if (style & TTF_STYLE_UNDERLINE) lua_pushliteral(L, "underline");
	else lua_pushliteral(L, "normal");

	return 1;
}

static int sdl_font_style(lua_State *L)
{
	lua_font *f = (lua_font*)auxiliar_checkclass(L, "sdl{font}", 1);
	const char *style = luaL_checkstring(L, 2);

	if (!strcmp(style, "normal")) TTF_SetFontStyle(f->font, 0);
	else if (!strcmp(style, "bold")) TTF_SetFontStyle(f->font, TTF_STYLE_BOLD);
	else if (!strcmp(style, "italic")) TTF_SetFontStyle(f->font, TTF_STYLE_ITALIC);
	else if (!strcmp(style, "underline")) TTF_SetFontStyle(f->font, TTF_STYLE_UNDERLINE);
	return 0;
}

int sdl_surface_drawstring(lua_State *L)
{
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	lua_font *f = (lua_font*)auxiliar_checkclass(L, "sdl{font}", 2);
	const char *str = luaL_checkstring(L, 3);
	int x = luaL_checknumber(L, 4);
	int y = luaL_checknumber(L, 5);
	int r = luaL_checknumber(L, 6);
	int g = luaL_checknumber(L, 7);
	int b = luaL_checknumber(L, 8);
	bool alpha_from_texture = lua_toboolean(L, 9);

	SDL_Color color = {r,g,b};
	SDL_Surface *txt = TTF_RenderUTF8_Blended(f->font, str, color);
	if (txt)
	{
		if (alpha_from_texture) SDL_SetAlpha(txt, 0, 0);
		sdlDrawImage(*s, txt, x, y);
		SDL_FreeSurface(txt);
	}

	return 0;
}

int sdl_surface_drawstring_aa(lua_State *L)
{
	if (no_text_aa) return sdl_surface_drawstring(L);
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	lua_font *f = (lua_font*)auxiliar_checkclass(L, "sdl{font}", 2);
	const char *str = luaL_checkstring(L, 3);
	int x = luaL_checknumber(L, 4);
	int y = luaL_checknumber(L, 5);
	int r = luaL_checknumber(L, 6);
	int g = luaL_checknumber(L, 7);
	int b = luaL_checknumber(L, 8);
	bool alpha_from_texture = lua_toboolean(L, 9);

	SDL_Color color = {r,g,b};
	SDL_Surface *txt = TTF_RenderUTF8_Blended(f->font, str, color);
	if (txt)
	{
		if (alpha_from_texture) SDL_SetAlpha(txt, 0, 0);
		sdlDrawImage(*s, txt, x, y);
		SDL_FreeSurface(txt);
	}

	return 0;
}

static int sdl_surface_drawstring_newsurface(lua_State *L)
{
	lua_font *f = (lua_font*)auxiliar_checkclass(L, "sdl{font}", 1);
	const char *str = luaL_checkstring(L, 2);
	int r = luaL_checknumber(L, 3);
	int g = luaL_checknumber(L, 4);
	int b = luaL_checknumber(L, 5);

	SDL_Color color = {r,g,b};
	SDL_Surface *txt = TTF_RenderUTF8_Blended(f->font, str, color);
	if (txt)
	{
		SDL_Surface **s = (SDL_Surface**)lua_newuserdata(L, sizeof(SDL_Surface*));
		auxiliar_setclass(L, "sdl{surface}", -1);
		*s = SDL_DisplayFormatAlpha(txt);
		SDL_FreeSurface(txt);
		return 1;
	}

	lua_pushnil(L);
	return 1;
}


static int sdl_surface_drawstring_newsurface_aa(lua_State *L)
{
	if (no_text_aa) return sdl_surface_drawstring_newsurface(L);
	lua_font *f = (lua_font*)auxiliar_checkclass(L, "sdl{font}", 1);
	const char *str = luaL_checkstring(L, 2);
	int r = luaL_checknumber(L, 3);
	int g = luaL_checknumber(L, 4);
	int b = luaL_checknumber(L, 5);

	SDL_Color color = {r,g,b};
	SDL_Surface *txt = TTF_RenderUTF8_Blended(f->font, str, color);
	if (txt)
	{
		SDL_Surface **s = (SDL_Surface**)lua_newuserdata(L, sizeof(SDL_Surface*));
		auxiliar_setclass(L, "sdl{surface}", -1);
		*s = SDL_DisplayFormatAlpha(txt);
		SDL_FreeSurface(txt);
		return 1;
	}

	lua_pushnil(L);
	return 1;
}

static int sdl_new_tile(lua_State *L)
{
	int w = luaL_checknumber(L, 1);
	int h = luaL_checknumber(L, 2);
	lua_font *f = (lua_font*)auxiliar_checkclass(L, "sdl{font}", 3);
	const char *str = luaL_checkstring(L, 4);
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
	SDL_Surface *txt = TTF_RenderUTF8_Blended(f->font, str, color);

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

	if (txt)
	{
		if (!alpha) SDL_SetAlpha(txt, 0, 0);
		sdlDrawImage(*s, txt, x, y);
		SDL_FreeSurface(txt);
	}

	return 1;
}

static void font_make_texture_line(lua_State *L, SDL_Surface *s, int id, bool is_separator, int id_real_line, char *line_data, int line_data_size, bool direct_uid_draw, int realsize)
{
	lua_createtable(L, 0, 9);

	if (direct_uid_draw)
	{
		lua_pushliteral(L, "_dduids");
		lua_pushvalue(L, -4);
		lua_rawset(L, -3);

		// Replace dduids by a new one
		lua_newtable(L);
		lua_replace(L, -4);
	}

	lua_pushliteral(L, "_tex");
	GLuint *t = (GLuint*)lua_newuserdata(L, sizeof(GLuint));
	auxiliar_setclass(L, "gl{texture}", -1);
	lua_rawset(L, -3);

	glGenTextures(1, t);
	tfglBindTexture(GL_TEXTURE_2D, *t);
	int fw, fh;
	make_texture_for_surface(s, &fw, &fh, true);
	copy_surface_to_texture(s);

	lua_pushliteral(L, "_tex_w");
	lua_pushnumber(L, fw);
	lua_rawset(L, -3);
	lua_pushliteral(L, "_tex_h");
	lua_pushnumber(L, fh);
	lua_rawset(L, -3);

	lua_pushliteral(L, "w");
	lua_pushnumber(L, s->w);
	lua_rawset(L, -3);
	lua_pushliteral(L, "h");
	lua_pushnumber(L, s->h);
	lua_rawset(L, -3);

	lua_pushliteral(L, "line");
	lua_pushnumber(L, id_real_line);
	lua_rawset(L, -3);

	lua_pushliteral(L, "realw");
	lua_pushnumber(L, realsize);
	lua_rawset(L, -3);

	if (line_data)
	{
		lua_pushliteral(L, "line_extra");
		lua_pushlstring(L, line_data, line_data_size);
		lua_rawset(L, -3);
	}

	if (is_separator)
	{
		lua_pushliteral(L, "is_separator");
		lua_pushboolean(L, TRUE);
		lua_rawset(L, -3);
	}

	lua_rawseti(L, -2, id);
}

static int sdl_font_draw(lua_State *L)
{
	lua_font *f = (lua_font*)auxiliar_checkclass(L, "sdl{font}", 1);
	const char *str = luaL_checkstring(L, 2);
	int max_width = luaL_checknumber(L, 3);
	int r = luaL_checknumber(L, 4);
	int g = luaL_checknumber(L, 5);
	int b = luaL_checknumber(L, 6);
	bool no_linefeed = lua_toboolean(L, 7);
	bool direct_uid_draw = lua_toboolean(L, 8);
	int h = TTF_FontHeight(f->font);
	SDL_Color color = {r,g,b};

	int fullmax = max_texture_size / 2;
	if (fullmax < 1024) fullmax = 1024;
	if (max_width >= fullmax) max_width = fullmax;

	Uint32 rmask, gmask, bmask, amask;
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
	rmask = 0xff000000; gmask = 0x00ff0000; bmask = 0x0000ff00; amask = 0x000000ff;
#else
	rmask = 0x000000ff; gmask = 0x0000ff00; bmask = 0x00ff0000; amask = 0xff000000;
#endif
	SDL_Surface *s = SDL_CreateRGBSurface(SDL_SWSURFACE, max_width, h, 32, rmask, gmask, bmask, amask);
	SDL_FillRect(s, NULL, SDL_MapRGBA(s->format, 0, 0, 0, 0));

	int id_dduid = 1;
	if (direct_uid_draw)
	{
		lua_newtable(L);
	}

	lua_newtable(L);

	int nb_lines = 1;
	int id_real_line = 1;
	char *line_data = NULL;
	int line_data_size = 0;
	char *start = (char*)str, *stop = (char*)str, *next = (char*)str;
	int max_size = 0;
	int size = 0;
	bool is_separator = FALSE;
	int i;
	bool force_nl = FALSE;
	SDL_Surface *txt = NULL;
	while (TRUE)
	{
		if ((*next == '\n') || (*next == ' ') || (*next == '\0') || (*next == '#'))
		{
			bool inced = FALSE;
			if (*next == ' ' && *(next+1))
			{
				inced = TRUE;
				stop = next;
				next++;
			}
			else stop = next - 1;

			// Make a surface for the word
			char old = *next;
			*next = '\0';
			if (txt) SDL_FreeSurface(txt);
			if (no_text_aa) txt = TTF_RenderUTF8_Blended(f->font, start, color);
			else txt = TTF_RenderUTF8_Blended(f->font, start, color);

			// If we must do a newline, flush the previous word and the start the new line
			if (!no_linefeed && (force_nl || (txt && (size + txt->w > max_width))))
			{
				// Push it & reset the surface
				font_make_texture_line(L, s, nb_lines, is_separator, id_real_line, line_data, line_data_size, direct_uid_draw, size);
				id_dduid = 1;
				is_separator = FALSE;
				SDL_FillRect(s, NULL, SDL_MapRGBA(s->format, 0, 0, 0, 0));
//				printf("Ending previous line at size %d\n", size);
				if (size > max_size) max_size = size;
				size = 0;
				nb_lines++;
				if (force_nl)
				{
					id_real_line++;
					if (line_data) { line_data = NULL; }
				}
				force_nl = FALSE;
			}

			if (txt)
			{
				// Detect separators
				if ((*start == '-') && (*(start+1) == '-') && (*(start+2) == '-') && !(*(start+3))) is_separator = TRUE;

//				printf("Drawing word '%s'\n", start);
				SDL_SetAlpha(txt, 0, 0);
				sdlDrawImage(s, txt, size, 0);
				size += txt->w;
			}
			*next = old;
			if (inced) next--;
			start = next + 1;

			// Force a linefeed
			if (*next == '\n') force_nl = TRUE;

			// Handle special codes
			else if (*next == '#')
			{
				char *codestop = next + 1;
				while (*codestop && *codestop != '#') codestop++;
				// Font style
				if (*(next+1) == '{') {
					if (*(next+2) == 'n') TTF_SetFontStyle(f->font, 0);
					else if (*(next+2) == 'b') TTF_SetFontStyle(f->font, TTF_STYLE_BOLD);
					else if (*(next+2) == 'i') TTF_SetFontStyle(f->font, TTF_STYLE_ITALIC);
					else if (*(next+2) == 'u') TTF_SetFontStyle(f->font, TTF_STYLE_UNDERLINE);
				}
				// Entity UID
				else if ((codestop - (next+1) > 4) && (*(next+1) == 'U') && (*(next+2) == 'I') && (*(next+3) == 'D') && (*(next+4) == ':')) {
					if (!direct_uid_draw)
					{
						lua_getglobal(L, "__get_uid_surface");
						char *colon = next + 5;
						while (*colon && *colon != ':') colon++;
						lua_pushlstring(L, next+5, colon - (next+5));
//						printf("Drawing UID %s\n", lua_tostring(L,-1));
						lua_pushnumber(L, h);
						lua_pushnumber(L, h);
						lua_call(L, 3, 1);
						if (lua_isuserdata(L, -1))
						{
							SDL_Surface **img = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", -1);
							sdlDrawImage(s, *img, size, 0);
							size += (*img)->w;
						}
						lua_pop(L, 1);
					}
					else
					{
						lua_getglobal(L, "__get_uid_entity");
						char *colon = next + 5;
						while (*colon && *colon != ':') colon++;
						lua_pushlstring(L, next+5, colon - (next+5));
						lua_call(L, 1, 1);
						if (lua_istable(L, -1))
						{
//							printf("DirectDrawUID in font:draw %d : %d\n", size, h);
							lua_createtable(L, 0, 4);

							lua_pushliteral(L, "e");
							lua_pushvalue(L, -3);
							lua_rawset(L, -3);

							lua_pushliteral(L, "x");
							lua_pushnumber(L, size);
							lua_rawset(L, -3);

							lua_pushliteral(L, "w");
							lua_pushnumber(L, h);
							lua_rawset(L, -3);

							lua_rawseti(L, -4, id_dduid++); // __dduids

							size += h;
						}
						lua_pop(L, 1);
					}
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
						color.r = r;
						color.g = g;
						color.b = b;
					}

					lua_getglobal(L, "colors");
					lua_pushlstring(L, next+1, codestop - (next+1));
					lua_rawget(L, -2);
					if (lua_istable(L, -1)) {
						r = color.r;
						g = color.g;
						b = color.b;

						lua_pushliteral(L, "r");
						lua_rawget(L, -2);
						color.r = lua_tonumber(L, -1);
						lua_pushliteral(L, "g");
						lua_rawget(L, -3);
						color.g = lua_tonumber(L, -1);
						lua_pushliteral(L, "b");
						lua_rawget(L, -4);
						color.b = lua_tonumber(L, -1);
						lua_pop(L, 3);
					}
					// Hexacolor
					else if (codestop - (next+1) == 6)
					{
						r = color.r;
						g = color.g;
						b = color.b;

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

						color.r = rh;
						color.g = gh;
						color.b = bh;
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

	font_make_texture_line(L, s, nb_lines, is_separator, id_real_line, line_data, line_data_size, direct_uid_draw, size);
	id_dduid = 1;
	if (size > max_size) max_size = size;

	if (txt) SDL_FreeSurface(txt);
	SDL_FreeSurface(s);

	lua_pushnumber(L, nb_lines);
	lua_pushnumber(L, max_size);

	if (direct_uid_draw) lua_remove(L, -4);

	return 3;
}

static int vo_font_add_string(lua_font *f, lua_vertexes *vx, const char *str, size_t len, font_style style, int bx, int by, float r, float g, float b, float a, int *vertexes_start_id, int *vertexes_stop_id) {
	int x = 0, y = by;
	ssize_t off = 1;
	int32_t c;
	float italic = 0;
	if (style == FONT_STYLE_ITALIC) { style = FONT_STYLE_NORMAL; italic = 0.2; }
	while (off > 0) {
		off = utf8proc_iterate(str, len, &c);
		str += off;
		len -= off;

		if (c > 0 && c < MAX_ATLAS_DATA) {
			font_atlas_data_style *d = &f->atlas_data[c].data[style];
			if (!d->w) font_add_atlas(f, c, style);
			if (d->w) {
				*vertexes_stop_id = vertex_add_quad(vx,
					d->w * italic + bx + x,		y,		d->tx1, d->ty1,
					d->w * italic + bx + x + d->w,	y,		d->tx2, d->ty1,
					bx + x + d->w,			y + d->h,	d->tx2, d->ty2,
					bx + x,				y + d->h,	d->tx1, d->ty2,
					r, g, b, a
				);
				if (*vertexes_start_id == -1) *vertexes_start_id = *vertexes_stop_id;
				x += d->w;
			}
		}
	}
	return x;
}

static int vo_font_get_string_size(lua_font *f, const char *str, size_t len, font_style style) {
	int x = 0, y = 0;
	ssize_t off = 1;
	int32_t c;
	float italic = 0;
	if (style == FONT_STYLE_ITALIC) { style = FONT_STYLE_NORMAL; italic = 0.2; }
	while (off > 0) {
		off = utf8proc_iterate(str, len, &c);
		str += off;
		len -= off;

		if (c > 0 && c < MAX_ATLAS_DATA) {
			font_atlas_data_style *d = &f->atlas_data[c].data[style];
			if (!d->w) font_add_atlas(f, c, style);
			if (d->w) {
				x += d->w;
			}
		}
	}
	return x;
}

static int sdl_font_draw_vo(lua_State *L)
{
	lua_font *f = (lua_font*)auxiliar_checkclass(L, "sdl{font}", 1);
	if (!f->atlas) font_make_atlas(f, 0, 0);
	lua_vertexes *vx = NULL;
	if (lua_isuserdata(L, 2)) vx = (lua_vertexes*)auxiliar_checkclass(L, "gl{vertexes}", 2);
	size_t len;
	const char *str = luaL_checklstring(L, 3, &len);
	float r = 1, g = 1, b = 1, a = 1;
	float lr = 1, lg = 1, lb = 1, la = 1;
	int max_width = lua_tonumber(L, 4);
	if (lua_isnumber(L, 5)) {
		r = luaL_checknumber(L, 5) / 255;
		g = luaL_checknumber(L, 6) / 255;
		b = luaL_checknumber(L, 7) / 255;
		if (lua_isnumber(L, 8)) a = luaL_checknumber(L, 8) / 255;
	}
	int bx = lua_tonumber(L, 9);
	int by = lua_tonumber(L, 10);
	bool no_linefeed = lua_toboolean(L, 11);

	if (!vx) {
		gl_new_vertex(L);
		vx = (lua_vertexes*)auxiliar_checkclass(L, "gl{vertexes}", -1);
	} else lua_pushvalue(L, 2);

	vx->tex = f->atlas_tex;

	// Update VO size once, we are allocating a few more than neede in case of utf8 or control sequences, but we dont care
	update_vertex_size(vx, vx->size + len * VERTEX_QUAD_SIZE);

	int vertexes_start_id = -1;
	int vertexes_stop_id = -1;
	int font_h = TTF_FontHeight(f->font);
	int id_dduid = 1;
	int nb_lines = 1;
	int id_real_line = 1;
	char *line_data = NULL;
	int line_data_size = 0;
	char *start = (char*)str, *stop = (char*)str, *next = (char*)str;
	int max_size = 0;
	int size = 0;
	bool is_separator = FALSE;
	int i;
	bool force_nl = FALSE;
	font_style style = FONT_STYLE_NORMAL;
	while (TRUE)
	{
		if ((*next == '\n') || (*next == ' ') || (*next == '\0') || (*next == '#'))
		{
			bool inced = FALSE;
			if (*next == ' ' && *(next+1))
			{
				inced = TRUE;
				stop = next;
				next++;
			}
			else stop = next - 1;

			// Make a surface for the word
			int len = next - start;
			int future_size = vo_font_get_string_size(f, start, len, style);

			// If we must do a newline, flush the previous word and the start the new line
			if (!no_linefeed && (force_nl || (future_size && max_width && (size + future_size > max_width))))
			{
				// Push it & reset the surface
				id_dduid = 1;
				is_separator = FALSE;
//				printf("Ending previous line at size %d\n", size);
				if (size > max_size) max_size = size;
				size = 0;
				nb_lines++;
				if (force_nl)
				{
					id_real_line++;
					if (line_data) { line_data = NULL; }
				}
				force_nl = FALSE;
			}

			if (len)
			{
				// Detect separators
				if ((*start == '-') && (*(start+1) == '-') && (*(start+2) == '-') && !(*(start+3))) is_separator = TRUE;

//				printf("Drawing word '%s'\n", start);
				size += vo_font_add_string(f, vx, start, len, style, bx + size, by + (nb_lines-1) * font_h, r, g, b, a, &vertexes_start_id, &vertexes_stop_id);
			}
			if (inced) next--;
			start = next + 1;

			// Force a linefeed
			if (*next == '\n') force_nl = TRUE;

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
// 					lua_getglobal(L, "__get_uid_entity");
// 					char *colon = next + 5;
// 					while (*colon && *colon != ':') colon++;
// 					lua_pushlstring(L, next+5, colon - (next+5));
// 					lua_call(L, 1, 1);
// 					if (lua_istable(L, -1))
// 					{
// //							printf("DirectDrawUID in font:draw %d : %d\n", size, h);
// 						lua_createtable(L, 0, 4);

// 						lua_pushliteral(L, "e");
// 						lua_pushvalue(L, -3);
// 						lua_rawset(L, -3);

// 						lua_pushliteral(L, "x");
// 						lua_pushnumber(L, size);
// 						lua_rawset(L, -3);

// 						lua_pushliteral(L, "w");
// 						lua_pushnumber(L, h);
// 						lua_rawset(L, -3);

// 						lua_rawseti(L, -4, id_dduid++); // __dduids

// 						size += h;
// 					}
// 					lua_pop(L, 1);
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

	// font_make_texture_line(L, s, nb_lines, is_separator, id_real_line, line_data, line_data_size, direct_uid_draw, size);
	id_dduid = 1;
	if (size > max_size) max_size = size;


	lua_pushnumber(L, vertexes_start_id);
	lua_pushnumber(L, vertexes_stop_id);
	lua_pushnumber(L, nb_lines);
	lua_pushnumber(L, max_size);
	lua_pushnumber(L, nb_lines * font_h);
	lua_pushvalue(L, -6);

	if (f->atlas_changed) {
		tfglBindTexture(GL_TEXTURE_2D, f->atlas_tex);
		copy_surface_to_texture(f->atlas);
	}
	return 6;
}

static int set_text_aa(lua_State *L)
{
	bool active = !lua_toboolean(L, 1);
	no_text_aa = active;
	return 0;
}

static int get_text_aa(lua_State *L)
{
	lua_pushboolean(L, !no_text_aa);
	return 1;
}

static int sdl_font_total(lua_State *L)
{
	lua_pushnumber(L, nb_fonts);
	lua_pushnumber(L, nb_fonts_atlas);
	return 2;
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
	{"draw", sdl_font_draw},
	{"drawVO", sdl_font_draw_vo},
	{"makeAtlas", sdl_font_make_atlas},
	{"debugAtlas", sdl_font_atlas_debug},
	{NULL, NULL},
};

const luaL_Reg fontlib[] = {
	{"fontDefaultAtlasChars", set_default_atlas_chars},
	{"setTextBlended", set_text_aa},
	{"getTextBlended", get_text_aa},
	{"newFont", sdl_new_font},
	{"newTile", sdl_new_tile},
	{"drawStringNewSurface", sdl_surface_drawstring_newsurface},
	{"drawStringBlendedNewSurface", sdl_surface_drawstring_newsurface_aa},
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
	return 1;
}
