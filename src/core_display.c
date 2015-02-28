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
#include "mzip.h"
#include "zlib.h"
#include "main.h"
#include "useshader.h"
#include "core_lua.h"
#include "vertex_objects.h"
#include "core_display.h"
#include <math.h>
#include <time.h>
#include <locale.h>

#ifdef __APPLE__
#include <libpng/png.h>
#else
#include <png.h>
#endif

extern SDL_Window *window;

lua_vertexes *generic_vx = NULL;
lua_vertexes *generic_vx_fan = NULL;

#define SDL_SRCALPHA        0x00010000
int SDL_SetAlpha(SDL_Surface * surface, Uint32 flag, Uint8 value)
{
    if (flag & SDL_SRCALPHA) {
        /* According to the docs, value is ignored for alpha surfaces */
        if (surface->format->Amask) {
            value = 0xFF;
        }
        SDL_SetSurfaceAlphaMod(surface, value);
        SDL_SetSurfaceBlendMode(surface, SDL_BLENDMODE_BLEND);
    } else {
        SDL_SetSurfaceAlphaMod(surface, 0xFF);
        SDL_SetSurfaceBlendMode(surface, SDL_BLENDMODE_NONE);
    }
    SDL_SetSurfaceRLE(surface, (flag & SDL_RLEACCEL));

    return 0;
}

SDL_Surface *SDL_DisplayFormatAlpha(SDL_Surface *surface)
{
	SDL_Surface *image;
	SDL_Rect area;
	Uint8  saved_alpha;
	SDL_BlendMode saved_mode;

	image = SDL_CreateRGBSurface(
			SDL_SWSURFACE,
			surface->w, surface->h,
			32,
#if SDL_BYTEORDER == SDL_LIL_ENDIAN /* OpenGL RGBA masks */
			0x000000FF,
			0x0000FF00,
			0x00FF0000,
			0xFF000000
#else
			0xFF000000,
			0x00FF0000,
			0x0000FF00,
			0x000000FF
#endif
			);
	if ( image == NULL ) {
		return 0;
	}

	/* Save the alpha blending attributes */
	SDL_GetSurfaceAlphaMod(surface, &saved_alpha);
	SDL_SetSurfaceAlphaMod(surface, 0xFF);
	SDL_GetSurfaceBlendMode(surface, &saved_mode);
	SDL_SetSurfaceBlendMode(surface, SDL_BLENDMODE_NONE);

	/* Copy the surface into the GL texture image */
	area.x = 0;
	area.y = 0;
	area.w = surface->w;
	area.h = surface->h;
	SDL_BlitSurface(surface, &area, image, &area);

	/* Restore the alpha blending attributes */
	SDL_SetSurfaceAlphaMod(surface, saved_alpha);
	SDL_SetSurfaceBlendMode(surface, saved_mode);

	return image;
}

typedef struct SDL_VideoInfo
{
    Uint32 hw_available:1;
    Uint32 wm_available:1;
    Uint32 UnusedBits1:6;
    Uint32 UnusedBits2:1;
    Uint32 blit_hw:1;
    Uint32 blit_hw_CC:1;
    Uint32 blit_hw_A:1;
    Uint32 blit_sw:1;
    Uint32 blit_sw_CC:1;
    Uint32 blit_sw_A:1;
    Uint32 blit_fill:1;
    Uint32 UnusedBits3:16;
    Uint32 video_mem;

    SDL_PixelFormat *vfmt;

    int current_w;
    int current_h;
} SDL_VideoInfo;

static int
GetVideoDisplay()
{
    const char *variable = SDL_getenv("SDL_VIDEO_FULLSCREEN_DISPLAY");
    if ( !variable ) {
        variable = SDL_getenv("SDL_VIDEO_FULLSCREEN_HEAD");
    }
    if ( variable ) {
        return SDL_atoi(variable);
    } else {
        return 0;
    }
}

const SDL_VideoInfo *SDL_GetVideoInfo(void)
{
    static SDL_VideoInfo info;
    SDL_DisplayMode mode;

    /* Memory leak, compatibility code, who cares? */
    if (!info.vfmt && SDL_GetDesktopDisplayMode(GetVideoDisplay(), &mode) == 0) {
        info.vfmt = SDL_AllocFormat(mode.format);
        info.current_w = mode.w;
        info.current_h = mode.h;
    }
    return &info;
}

SDL_Rect **
SDL_ListModes(const SDL_PixelFormat * format, Uint32 flags)
{
    int i, nmodes;
    SDL_Rect **modes;

/*    if (!SDL_GetVideoDevice()) {
        return NULL;
    }
  */
/*    if (!(flags & SDL_FULLSCREEN)) {
        return (SDL_Rect **) (-1);
    }
*/
    if (!format) {
        format = SDL_GetVideoInfo()->vfmt;
    }

    /* Memory leak, but this is a compatibility function, who cares? */
    nmodes = 0;
    modes = NULL;
    for (i = 0; i < SDL_GetNumDisplayModes(GetVideoDisplay()); ++i) {
        SDL_DisplayMode mode;
        int bpp;

        SDL_GetDisplayMode(GetVideoDisplay(), i, &mode);
        if (!mode.w || !mode.h) {
            return (SDL_Rect **) (-1);
        }

        /* Copied from src/video/SDL_pixels.c:SDL_PixelFormatEnumToMasks */
        if (SDL_BYTESPERPIXEL(mode.format) <= 2) {
            bpp = SDL_BITSPERPIXEL(mode.format);
        } else {
            bpp = SDL_BYTESPERPIXEL(mode.format) * 8;
        }

        if (bpp != format->BitsPerPixel) {
            continue;
        }
        if (nmodes > 0 && modes[nmodes - 1]->w == mode.w
            && modes[nmodes - 1]->h == mode.h) {
            continue;
        }

        modes = SDL_realloc(modes, (nmodes + 2) * sizeof(*modes));
        if (!modes) {
            return NULL;
        }
        modes[nmodes] = (SDL_Rect *) SDL_malloc(sizeof(SDL_Rect));
        if (!modes[nmodes]) {
            return NULL;
        }
        modes[nmodes]->x = 0;
        modes[nmodes]->y = 0;
        modes[nmodes]->w = mode.w;
        modes[nmodes]->h = mode.h;
        ++nmodes;
    }
    if (modes) {
        modes[nmodes] = NULL;
    }
    return modes;
}


/***** Helpers *****/
static GLenum sdl_gl_texture_format(SDL_Surface *s) {
	// get the number of channels in the SDL surface
	GLint nOfColors = s->format->BytesPerPixel;
	GLenum texture_format;
	if (nOfColors == 4)	 // contains an alpha channel
	{
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
		if (s->format->Rmask == 0xff000000)
#else
		if (s->format->Rmask == 0x000000ff)
#endif
			texture_format = GL_RGBA;
		else
			texture_format = GL_BGRA;
	} else if (nOfColors == 3)	 // no alpha channel
	{
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
		if (s->format->Rmask == 0x00ff0000)
#else
		if (s->format->Rmask == 0x000000ff)
#endif
			texture_format = GL_RGB;
		else
			texture_format = GL_BGR;
	} else {
		printf("warning: the image is not truecolor..  this will probably break %d\n", nOfColors);
		// this error should not go unhandled
	}

	return texture_format;
}


// allocate memory for a texture without copying pixels in
// caller binds texture
static char *largest_black = NULL;
static int largest_size = 0;
void make_texture_for_surface(SDL_Surface *s, int *fw, int *fh, bool clamp) {
	// Paramétrage de la texture.
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, clamp ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, clamp ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

	// get the number of channels in the SDL surface
	GLint nOfColors = s->format->BytesPerPixel;
	GLenum texture_format = sdl_gl_texture_format(s);

	// In case we can't support NPOT textures round up to nearest POT
	int realw=1;
	int realh=1;

	while (realw < s->w) realw *= 2;
	while (realh < s->h) realh *= 2;

	if (fw) *fw = realw;
	if (fh) *fh = realh;
	//printf("request size (%d,%d), producing size (%d,%d)\n",s->w,s->h,realw,realh);

	if (!largest_black || largest_size < realw * realh * 4) {
		if (largest_black) free(largest_black);
		largest_black = calloc(realh*realw*4, sizeof(char));
		largest_size = realh*realw*4;
		printf("Upgrading black texture to size %d\n", largest_size);
	}
	glTexImage2D(GL_TEXTURE_2D, 0, nOfColors, realw, realh, 0, texture_format, GL_UNSIGNED_BYTE, largest_black);

#ifdef _DEBUG
	GLenum err = glGetError();
	if (err != GL_NO_ERROR) {
		printf("make_texture_for_surface: glTexImage2D : %s\n",gluErrorString(err));
	}
#endif
}

// copy pixels into previous allocated surface
void copy_surface_to_texture(SDL_Surface *s) {
	GLenum texture_format = sdl_gl_texture_format(s);

	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, s->w, s->h, texture_format, GL_UNSIGNED_BYTE, s->pixels);

#ifdef _DEBUG
	GLenum err = glGetError();
	if (err != GL_NO_ERROR) {
		printf("copy_surface_to_texture : glTexSubImage2D : %s\n",gluErrorString(err));
	}
#endif
}

/******************************************************************
 ******************************************************************
 *                           Display                              *
 ******************************************************************
 ******************************************************************/
extern bool is_fullscreen;
extern bool is_borderless;
static int sdl_screen_size(lua_State *L)
{
	lua_pushnumber(L, screen->w);
	lua_pushnumber(L, screen->h);
	lua_pushboolean(L, is_fullscreen);
	lua_pushboolean(L, is_borderless);
	return 4;
}

static int sdl_window_pos(lua_State *L)
{
	int x, y;
	SDL_GetWindowPosition(window, &x, &y);
	lua_pushnumber(L, x);
	lua_pushnumber(L, y);
	return 2;
}

static int sdl_new_surface(lua_State *L)
{
	int w = luaL_checknumber(L, 1);
	int h = luaL_checknumber(L, 2);

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

	if (s == NULL)
		printf("ERROR : SDL_CreateRGBSurface : %s\n",SDL_GetError());

	return 1;
}

static int gl_texture_to_sdl(lua_State *L)
{
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 1);

	SDL_Surface **s = (SDL_Surface**)lua_newuserdata(L, sizeof(SDL_Surface*));
	auxiliar_setclass(L, "sdl{surface}", -1);

	// Bind the texture to read
	tglBindTexture(GL_TEXTURE_2D, t->tex);

	// Get texture size
	GLint w = t->w, h = t->h;
//	printf("Making surface from texture %dx%d\n", w, h);
	// Get texture data
	GLubyte *tmp = calloc(w*h*4, sizeof(GLubyte));
#ifndef NO_OLD_GL
	glGetTexImage(GL_TEXTURE_2D, 0, GL_BGRA, GL_UNSIGNED_BYTE, tmp);
#endif
	// Make sdl surface from it
	*s = SDL_CreateRGBSurfaceFrom(tmp, w, h, 32, w*4, 0,0,0,0);

	return 1;
}

typedef struct
{
	int x, y;
} Vector;
static inline float clamp(float val, float min, float max) { return val < min ? min : (val > max ? max : val); }
static void build_sdm_ex(const unsigned char *texData, int srcWidth, int srcHeight, unsigned char *sdmTexData, int dstWidth, int dstHeight, int dstx, int dsty)
{

	int maxSize = dstWidth > dstHeight ? dstWidth : dstHeight;
	int minSize = dstWidth < dstHeight ? dstWidth : dstHeight;

	Vector *pixelStack = (Vector *)malloc(dstWidth * dstHeight * sizeof(Vector));
	Vector *vectorMap = (Vector *)malloc(dstWidth * dstHeight * sizeof(Vector));
	int *pixelStackIndex = (int *) malloc(dstWidth * dstHeight * sizeof(int));
	
	int currSize = 0;
	int prevSize = 0;
	int newSize = 0;

	int x, y;
	for(y = 0; y < dstHeight; y++)
	{
		for(x = 0; x < dstWidth; x++)
		{
			pixelStackIndex[x + y * dstWidth] = -1;
			vectorMap[x + y * dstWidth].x = 0;
			vectorMap[x + y * dstWidth].y = 0;

			int srcx = x - dstx;
			int srcy = y - dsty;
			if(srcx < 0 || srcx >= srcWidth || srcy < 0 || srcy >= srcHeight) continue;
			
			/*sdmTexData[(x + y * dstWidth) * 4 + 0] = texData[(srcx + srcy * srcWidth) * 4 + 0];
			sdmTexData[(x + y * dstWidth) * 4 + 1] = texData[(srcx + srcy * srcWidth) * 4 + 1];
			sdmTexData[(x + y * dstWidth) * 4 + 2] = texData[(srcx + srcy * srcWidth) * 4 + 2];
			sdmTexData[(x + y * dstWidth) * 4 + 3] = texData[(srcx + srcy * srcWidth) * 4 + 3];*/			
			

			if(texData[(srcx + srcy * srcWidth) * 4 + 3] > 128)
			{
				pixelStackIndex[x + y * dstWidth] = currSize;
				pixelStack[currSize].x = x;
				pixelStack[currSize].y = y;
				currSize++;
			}
		}
	}
	
	int dist = 0;
	bool done = 0;
	while(!done)
	{
		dist++;
		int newSize = currSize;
		int pixelIndex;
		int neighbourNumber;
		for(pixelIndex = prevSize; pixelIndex < currSize; pixelIndex++)
		{
			for(neighbourNumber = 0; neighbourNumber < 8; neighbourNumber++)
			{
				int xoffset = 0;
				int yoffset = 0;
				switch(neighbourNumber)
				{
					case 0: xoffset =  1; yoffset =  0; break;
					case 1: xoffset =  0; yoffset =  1; break;
					case 2: xoffset = -1; yoffset =  0; break;
					case 3: xoffset =  0; yoffset = -1; break;
					case 4: xoffset =  1; yoffset =  1; break;
					case 5: xoffset = -1; yoffset =  1; break;
					case 6: xoffset = -1; yoffset = -1; break;
					case 7: xoffset =  1; yoffset = -1; break;
				}
				if(pixelStack[pixelIndex].x + xoffset >= dstWidth  || pixelStack[pixelIndex].x + xoffset < 0 ||
					 pixelStack[pixelIndex].y + yoffset >= dstHeight || pixelStack[pixelIndex].y + yoffset < 0) continue;

				int currIndex = pixelStack[pixelIndex].x + pixelStack[pixelIndex].y * dstWidth;
				int neighbourIndex = (pixelStack[pixelIndex].x + xoffset) + (pixelStack[pixelIndex].y + yoffset) * dstWidth;
				
				Vector currOffset;
				currOffset.x = vectorMap[currIndex].x + xoffset;
				currOffset.y = vectorMap[currIndex].y + yoffset;
				if(pixelStackIndex[neighbourIndex] == -1)
				{
					vectorMap[neighbourIndex] = currOffset;

					pixelStackIndex[neighbourIndex] = newSize;

					pixelStack[newSize].x = pixelStack[pixelIndex].x + xoffset;
					pixelStack[newSize].y = pixelStack[pixelIndex].y + yoffset;
					newSize++;
				}else
				{
					if(vectorMap[neighbourIndex].x * vectorMap[neighbourIndex].x + vectorMap[neighbourIndex].y * vectorMap[neighbourIndex].y >
						 currOffset.x * currOffset.x + currOffset.y * currOffset.y)
					{
						vectorMap[neighbourIndex] = currOffset;
						/*float weight0 = sqrtf(vectorMap[neighbourIndex].x * vectorMap[neighbourIndex].x + vectorMap[neighbourIndex].y * vectorMap[neighbourIndex].y);
						float weight1 = sqrtf(currOffset.x * currOffset.x + currOffset.y * currOffset.y);
						vectorMap[neighbourIndex].x = vectorMap[neighbourIndex].x * weight1 / (weight0 + weight1) + currOffset.x * weight0 / (weight0 + weight1);
						vectorMap[neighbourIndex].y = vectorMap[neighbourIndex].y * weight1 / (weight0 + weight1) + currOffset.y * weight0 / (weight0 + weight1);*/
					}
				}        
			}
		}
		if(currSize == newSize)
		{
			done = 1;
		}
		prevSize = currSize;
		currSize = newSize;
	}

	for(y = 0; y < dstHeight; y++)
	{
		for(x = 0; x < dstWidth; x++)
		{
			Vector offset = vectorMap[x + y * dstWidth];
			float offsetLen = sqrtf((float)(offset.x * offset.x + offset.y * offset.y));

			Vector currPoint;
			currPoint.x = x;
			currPoint.y = y;


			Vector basePoint;
			basePoint.x = currPoint.x - offset.x*0;
			basePoint.y = currPoint.y - offset.y*0;

			Vector centerPoint;
			centerPoint.x = dstx + srcWidth  / 2;
			centerPoint.y = dsty + srcHeight / 2;
			//float ang = atan2((float)(basePoint.x - centerPoint.x), -(float)(basePoint.y - centerPoint.y)); //0 is at up
			float ang = atan2((float)(basePoint.x - centerPoint.x), (float)(basePoint.y - centerPoint.y));
			//float ang = atan2((float)(offset.x), -(float)(offset.y));
			sdmTexData[(x + y * dstWidth) * 4 + 0] = 127 + (float)(-vectorMap[x + y * dstWidth].x) / maxSize * 127;
			sdmTexData[(x + y * dstWidth) * 4 + 1] = 127 + (float)(-vectorMap[x + y * dstWidth].y) / maxSize * 127;
			sdmTexData[(x + y * dstWidth) * 4 + 2] = (unsigned char)(clamp(ang / 3.141592f * 0.5f + 0.5f, 0.0f, 1.0f) * 255);
			sdmTexData[(x + y * dstWidth) * 4 + 3] = (unsigned char)(offsetLen / sqrtf(dstWidth * dstWidth + dstHeight * dstHeight) * 255);
		}
	}

	/*for(y = 0; y < dstHeight; y++)
	{
		for(x = 0; x < dstWidth; x++)
		{
			int dstPointx = x + (sdmTexData[(x + y * dstWidth) * 4 + 0] / 255.0 - 0.5) * maxSize;
			int dstPointy = y + (sdmTexData[(x + y * dstWidth) * 4 + 1] / 255.0 - 0.5) * maxSize;

			float planarx = sdmTexData[(x + y * dstWidth) * 4 + 2] / 255.0;
			float planary = sdmTexData[(x + y * dstWidth) * 4 + 3] / 255.0;
			
			char resultColor[4];
			GetBackgroundColor(Vector2f(planarx, planary), 0.1f, resultColor);


			for(int componentIndex = 0; componentIndex < 4; componentIndex++)
			{
				sdmTexData[(x + y * dstWidth) * 4 + componentIndex] = resultColor[componentIndex];
			}
		}
	}*/
	free(pixelStack);
	free(vectorMap);
	free(pixelStackIndex);
}

static int gl_texture_alter_sdm(lua_State *L) {
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 1);
	bool doubleheight = lua_toboolean(L, 2);

	// Bind the texture to read
	tglBindTexture(GL_TEXTURE_2D, t->tex);

	// Get texture size
	GLint w, h, dh;
	w = t->w;
	h = t->h;
	dh = doubleheight ? h * 2 : h;
	GLubyte *tmp = calloc(w*h*4, sizeof(GLubyte));
#ifndef NO_OLD_GL
	glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE, tmp);
#endif
	GLubyte *sdm = calloc(w*dh*4, sizeof(GLubyte));
	build_sdm_ex(tmp, w, h, sdm, w, dh, 0, doubleheight ? h : 0);

	texture_type *st = (texture_type*)lua_newuserdata(L, sizeof(texture_type));
	auxiliar_setclass(L, "gl{texture}", -1);
	st->w = w;
	st->h = dh;

	glGenTextures(1, &st->tex);
	tfglBindTexture(GL_TEXTURE_2D, st->tex);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
	glTexImage2D(GL_TEXTURE_2D, 0, 4, w, dh, 0, GL_RGBA, GL_UNSIGNED_BYTE, sdm);

	free(tmp);
	free(sdm);

	lua_pushnumber(L, 1);
	lua_pushnumber(L, 1);

	return 3;
}

int gl_tex_white = 0;
int init_blank_surface()
{
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
	SDL_Surface *s = SDL_CreateRGBSurface(
		SDL_SWSURFACE,
		4,
		4,
		32,
		rmask, gmask, bmask, amask
		);
	SDL_FillRect(s, NULL, SDL_MapRGBA(s->format, 255, 255, 255, 255));

	glGenTextures(1, &gl_tex_white);
	tfglBindTexture(GL_TEXTURE_2D, gl_tex_white);
	int fw, fh;
	make_texture_for_surface(s, &fw, &fh, false);
	copy_surface_to_texture(s);
	return gl_tex_white;
}

static int gl_draw_quad(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	int y = luaL_checknumber(L, 2);
	int w = luaL_checknumber(L, 3);
	int h = luaL_checknumber(L, 4);
	float r = luaL_checknumber(L, 5) / 255;
	float g = luaL_checknumber(L, 6) / 255;
	float b = luaL_checknumber(L, 7) / 255;
	float a = luaL_checknumber(L, 8) / 255;

	if (lua_isuserdata(L, 9))
	{
		texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 9);
		generic_vx->tex = t->tex;
	}
	else if (lua_toboolean(L, 9))
	{
		// Do nothing, we keep the currently bound texture
	}
	else
	{
		generic_vx->tex = gl_tex_white;
	}

	vertex_clear(generic_vx);
	vertex_add_quad(generic_vx,
		0, 0, 0, 0,
		0, h, 0, 1,
		w, h, 1, 1,
		w, 0, 1, 0,
		r, g, b, a
	);
	vertex_toscreen(generic_vx, x, y, -1, 1, 1, 1, 1);
	return 0;
}

static int gl_draw_quad_part(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	int y = luaL_checknumber(L, 2);
	int w = luaL_checknumber(L, 3);
	int h = luaL_checknumber(L, 4);
	float angle = luaL_checknumber(L, 5);
	float r = luaL_checknumber(L, 6) / 255;
	float g = luaL_checknumber(L, 7) / 255;
	float b = luaL_checknumber(L, 8) / 255;
	float a = luaL_checknumber(L, 9) / 255;

	int xw = w + x;
	int yh = h + y;
	int midx = x + w / 2, midy = y + h / 2;

	if (lua_isuserdata(L, 10))
	{
		texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 10);
		tglBindTexture(GL_TEXTURE_2D, t->tex);
	}
	else if (lua_toboolean(L, 10))
	{
		// Do nothing, we keep the currently bound texture
	}
	else
	{
		tfglBindTexture(GL_TEXTURE_2D, gl_tex_white);
	}

	if (angle < 0) angle = 0;
	else if (angle > 360) angle = 360;

	// Shortcut
	if (angle == 360)
	{
		return 0;
	}


	int i = 4;
	float quadrant = angle / 45;
	float rad = (angle - (45 * (int)quadrant)) * M_PI / 180;
	float s = sin(rad) / 2;

	vertex_clear(generic_vx_fan);

	vertex_add_point(generic_vx_fan, midx, midy,	0, 0, r, g, b, a);
	vertex_add_point(generic_vx_fan, midx, y,	0, 1, r, g, b, a);
	if (quadrant >= 7)                 { vertex_add_point(generic_vx_fan, x + w * s, y,	1, 0, r, g, b, a); }
	else if (quadrant < 7)             { vertex_add_point(generic_vx_fan, x, y,		1, 0, r, g, b, a); }
	if (quadrant >= 6 && quadrant < 7) { vertex_add_point(generic_vx_fan, x, midy - h * s,	1, 0, r, g, b, a); }
	else if (quadrant < 6)             { vertex_add_point(generic_vx_fan, x, midy,		1, 0, r, g, b, a); }
	if (quadrant >= 5 && quadrant < 6) { vertex_add_point(generic_vx_fan, x, yh - h * s,	1, 0, r, g, b, a); }
	else if (quadrant < 5)             { vertex_add_point(generic_vx_fan, x, yh,		1, 0, r, g, b, a); }
	if (quadrant >= 4 && quadrant < 5) { vertex_add_point(generic_vx_fan, midx - w * s, yh,	1, 0, r, g, b, a); }
	else if (quadrant < 4)             { vertex_add_point(generic_vx_fan, midx, yh,		1, 0, r, g, b, a); }
	if (quadrant >= 3 && quadrant < 4) { vertex_add_point(generic_vx_fan, xw - w * s, yh,	1, 0, r, g, b, a); }
	else if (quadrant < 3)             { vertex_add_point(generic_vx_fan, xw, yh,		1, 0, r, g, b, a); }
	if (quadrant >= 2 && quadrant < 3) { vertex_add_point(generic_vx_fan, xw, midy + h * s,	1, 0, r, g, b, a); }
	else if (quadrant < 2)             { vertex_add_point(generic_vx_fan, xw, midy,		1, 0, r, g, b, a); }
	if (quadrant >= 1 && quadrant < 2) { vertex_add_point(generic_vx_fan, xw, y + h * s,	1, 0, r, g, b, a); }
	else if (quadrant < 1)             { vertex_add_point(generic_vx_fan, xw, y,		1, 0, r, g, b, a); }
	if (quadrant >= 0 && quadrant < 1) { vertex_add_point(generic_vx_fan, midx + w * s, y,	1, 0, r, g, b, a); }

	vertex_toscreen(generic_vx_fan, 0, 0, 0, 1, 1, 1, 1);
	return 0;
}


static int sdl_load_image(lua_State *L)
{
	const char *name = luaL_checkstring(L, 1);

	SDL_Surface **s = (SDL_Surface**)lua_newuserdata(L, sizeof(SDL_Surface*));
	auxiliar_setclass(L, "sdl{surface}", -1);

	*s = IMG_Load_RW(PHYSFSRWOPS_openRead(name), TRUE);
	if (!*s) return 0;

	lua_pushnumber(L, (*s)->w);
	lua_pushnumber(L, (*s)->h);

	return 3;
}

static int sdl_load_image_mem(lua_State *L)
{
	size_t len;
	const char *data = luaL_checklstring(L, 1, &len);

	SDL_Surface **s = (SDL_Surface**)lua_newuserdata(L, sizeof(SDL_Surface*));
	auxiliar_setclass(L, "sdl{surface}", -1);

	*s = IMG_Load_RW(SDL_RWFromConstMem(data, len), TRUE);
	if (!*s) return 0;

	lua_pushnumber(L, (*s)->w);
	lua_pushnumber(L, (*s)->h);

	return 3;
}

static int sdl_free_surface(lua_State *L)
{
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	if (*s)
	{
		if ((*s)->flags & SDL_PREALLOC) free((*s)->pixels);
		SDL_FreeSurface(*s);
	}
	lua_pushnumber(L, 1);
	return 1;
}

static int lua_display_char(lua_State *L)
{
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	const char *c = luaL_checkstring(L, 2);
	int x = luaL_checknumber(L, 3);
	int y = luaL_checknumber(L, 4);
	int r = luaL_checknumber(L, 5);
	int g = luaL_checknumber(L, 6);
	int b = luaL_checknumber(L, 7);

	display_put_char(*s, c[0], x, y, r, g, b);

	return 0;
}

static int sdl_surface_erase(lua_State *L)
{
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	int r = lua_tonumber(L, 2);
	int g = lua_tonumber(L, 3);
	int b = lua_tonumber(L, 4);
	int a = lua_isnumber(L, 5) ? lua_tonumber(L, 5) : 255;
	if (lua_isnumber(L, 6))
	{
		SDL_Rect rect;
		rect.x = lua_tonumber(L, 6);
		rect.y = lua_tonumber(L, 7);
		rect.w = lua_tonumber(L, 8);
		rect.h = lua_tonumber(L, 9);
		SDL_FillRect(*s, &rect, SDL_MapRGBA((*s)->format, r, g, b, a));
	}
	else
		SDL_FillRect(*s, NULL, SDL_MapRGBA((*s)->format, r, g, b, a));
	return 0;
}

static int sdl_surface_get_size(lua_State *L)
{
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	lua_pushnumber(L, (*s)->w);
	lua_pushnumber(L, (*s)->h);
	return 2;
}


static int sdl_surface_update_texture(lua_State *L)
{
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 2);

	tglBindTexture(GL_TEXTURE_2D, t->tex);
	copy_surface_to_texture(*s);

	return 0;
}

static int sdl_surface_to_texture(lua_State *L)
{
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	bool nearest = lua_toboolean(L, 2);
	bool norepeat = lua_toboolean(L, 3);

	texture_type *t = (texture_type*)lua_newuserdata(L, sizeof(texture_type));
	auxiliar_setclass(L, "gl{texture}", -1);

	glGenTextures(1, &t->tex);
	tfglBindTexture(GL_TEXTURE_2D, t->tex);

	int fw, fh;
	make_texture_for_surface(*s, &fw, &fh, norepeat);
	if (nearest) glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	copy_surface_to_texture(*s);
	t->w = fw;
	t->h = fh;

	lua_pushnumber(L, fw);
	lua_pushnumber(L, fh);
	lua_pushnumber(L, (double)fw / (*s)->w);
	lua_pushnumber(L, (double)fh / (*s)->h);
	lua_pushnumber(L, (*s)->w);
	lua_pushnumber(L, (*s)->h);

	return 7;
}

static int sdl_surface_merge(lua_State *L)
{
	SDL_Surface **dst = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	SDL_Surface **src = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 2);
	int x = luaL_checknumber(L, 3);
	int y = luaL_checknumber(L, 4);
	if (dst && *dst && src && *src)
	{
		sdlDrawImage(*dst, *src, x, y);
	}
	return 0;
}

static int sdl_surface_alpha(lua_State *L)
{
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	if (lua_isnumber(L, 2))
	{
		int a = luaL_checknumber(L, 2);
		SDL_SetAlpha(*s, /*SDL_SRCALPHA | */SDL_RLEACCEL, (a < 0) ? 0 : (a > 255) ? 255 : a);
	}
	else
	{
		SDL_SetAlpha(*s, 0, 0);
	}
	return 0;
}

static int sdl_free_texture(lua_State *L)
{
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 1);
	glDeleteTextures(1, &t->tex);
	lua_pushnumber(L, 1);
//	printf("freeing texture %d\n", t->tex);
	return 1;
}

static int sdl_texture_toscreen(lua_State *L)
{
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 1);
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);
	int w = luaL_checknumber(L, 4);
	int h = luaL_checknumber(L, 5);
	float r = 1, g = 1, b = 1, a = 1;
	if (lua_isnumber(L, 6))
	{
		r = luaL_checknumber(L, 6);
		g = luaL_checknumber(L, 7);
		b = luaL_checknumber(L, 8);
		a = luaL_checknumber(L, 9);
	}

	vertex_clear(generic_vx);
	vertex_add_quad(generic_vx,
		0, 0, 0, 0,
		0, h, 0, 1,
		w, h, 1, 1,
		w, 0, 1, 0,
		r, g, b, a
	);
	vertex_toscreen(generic_vx, x, y, t->tex, 1, 1, 1, 1);

	return 0;
}

static int sdl_texture_toscreen_highlight_hex(lua_State *L)
{
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 1);
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);
	int w = luaL_checknumber(L, 4);
	int h = luaL_checknumber(L, 5);

	float f = x - w/6.0;
	float v = 4.0*w/3.0;

	if (lua_isnumber(L, 6))
	{
		float r = luaL_checknumber(L, 6);
		float g = luaL_checknumber(L, 7);
		float b = luaL_checknumber(L, 8);
		float a = luaL_checknumber(L, 9);
		vertex_add_point(generic_vx_fan, x + 0.5*v,  y + 0.5*h,	0, 0, r, g, b, a);
		vertex_add_point(generic_vx_fan, f + 0.25*v, y,		0, 1, r, g, b, a);
		vertex_add_point(generic_vx_fan, f,          y + 0.5*h,	1, 1, r, g, b, a);
		vertex_add_point(generic_vx_fan, f + 0.25*v, y + h,	1, 0, r, g, b, a);
		vertex_add_point(generic_vx_fan, f + 0.75*v, y + h,	1, 0, r, g, b, a);
		vertex_add_point(generic_vx_fan, f + v,      y + 0.5*h,	1, 0, r, g, b, a);
		vertex_add_point(generic_vx_fan, f + 0.75*v, y,		1, 0, r, g, b, a);
		vertex_add_point(generic_vx_fan, f + 0.25*v, y,		1, 0, r, g, b, a);
	} else {
		vertex_add_point(generic_vx_fan, x + 0.5*v,  y + 0.5*h,	0, 0, 0.9, 0.9, 0.9, 1);
		vertex_add_point(generic_vx_fan, f + 0.25*v, y,		0, 1, 0.9, 0.9, 0.9, 1);
		vertex_add_point(generic_vx_fan, f,          y + 0.5*h,	1, 1, 1, 1, 1, 1);
		vertex_add_point(generic_vx_fan, f + 0.25*v, y + h,	1, 0, 1, 1, 1, 1);
		vertex_add_point(generic_vx_fan, f + 0.75*v, y + h,	1, 0, 0.9, 0.9, 0.9, 1);
		vertex_add_point(generic_vx_fan, f + v,      y + 0.5*h,	1, 0, 0.8, 0.8, 0.8, 1);
		vertex_add_point(generic_vx_fan, f + 0.75*v, y,		1, 0, 0.8, 0.8, 0.8, 1);
		vertex_add_point(generic_vx_fan, f + 0.25*v, y,		1, 0, 0.9, 0.9, 0.9, 1);
	}

	vertex_toscreen(generic_vx_fan, 0, 0, 0, 1, 1, 1, 1);
	return 0;
}

static int sdl_texture_toscreen_full(lua_State *L)
{
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 1);
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);
	int w = luaL_checknumber(L, 4);
	int h = luaL_checknumber(L, 5);
	int rw = luaL_checknumber(L, 6);
	int rh = luaL_checknumber(L, 7);
	float r = 1, g = 1, b = 1, a = 1;
	if (lua_isnumber(L, 8))
	{
		r = luaL_checknumber(L, 8);
		g = luaL_checknumber(L, 9);
		b = luaL_checknumber(L, 10);
		a = luaL_checknumber(L, 11);
	}
	GLfloat texw = (GLfloat)w/rw;
	GLfloat texh = (GLfloat)h/rh;

	vertex_clear(generic_vx);
	vertex_add_quad(generic_vx,
		0, 0, 0, 0,
		0, h, 0, texh,
		w, h, texw, texh,
		w, 0, texw, 0,
		r, g, b, a
	);
	vertex_toscreen(generic_vx, x, y, t->tex, 1, 1, 1, 1);

	return 0;
}

static int sdl_texture_toscreen_precise(lua_State *L)
{
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 1);
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);
	int w = luaL_checknumber(L, 4);
	int h = luaL_checknumber(L, 5);
	GLfloat x1 = luaL_checknumber(L, 6);
	GLfloat x2 = luaL_checknumber(L, 7);
	GLfloat y1 = luaL_checknumber(L, 8);
	GLfloat y2 = luaL_checknumber(L, 9);
	float r = 1, g = 1, b = 1, a = 1;
	if (lua_isnumber(L, 10))
	{
		r = luaL_checknumber(L, 10);
		g = luaL_checknumber(L, 11);
		b = luaL_checknumber(L, 12);
		a = luaL_checknumber(L, 13);
	}

	vertex_clear(generic_vx);
	vertex_add_quad(generic_vx,
		0, 0, x1, y1,
		0, h, x1, y2,
		w, h, x2, y2,
		w, 0, x2, y1,
		r, g, b, a
	);
	vertex_toscreen(generic_vx, x, y, t->tex, 1, 1, 1, 1);

	return 0;
}

static int gl_scale(lua_State *L)
{
	if (lua_isnumber(L, 1))
	{
		renderer_pushstate(TRUE);
		renderer_scale(lua_tonumber(L, 1), lua_tonumber(L, 2), lua_tonumber(L, 3));
	}
	else
		renderer_popstate(TRUE);
	return 0;
}

static int gl_translate(lua_State *L)
{
	renderer_translate(lua_tonumber(L, 1), lua_tonumber(L, 2), lua_tonumber(L, 3));
	return 0;
}

static int gl_rotate(lua_State *L)
{
	renderer_rotate(lua_tonumber(L, 1), lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4));
	return 0;
}

static int gl_push(lua_State *L)
{
	renderer_pushstate(TRUE);
	return 0;
}

static int gl_pop(lua_State *L)
{
	renderer_popstate(TRUE);
	return 0;
}

static int gl_identity(lua_State *L)
{
	renderer_identity(TRUE);
	return 0;
}

static int gl_matrix(lua_State *L)
{
	if (lua_toboolean(L, 1)) renderer_pushstate(TRUE);
	else renderer_popstate(TRUE);
	return 0;
}

static int gl_depth_test(lua_State *L)
{
	if (lua_toboolean(L, 1)) glEnable(GL_DEPTH_TEST);
	else glDisable(GL_DEPTH_TEST);
	return 0;
}

static int gl_scissor(lua_State *L)
{
	if (lua_toboolean(L, 1)) {
		glEnable(GL_SCISSOR_TEST);
		glScissor(luaL_checknumber(L, 2), screen->h - luaL_checknumber(L, 3) - luaL_checknumber(L, 5), luaL_checknumber(L, 4), luaL_checknumber(L, 5));
	} else glDisable(GL_SCISSOR_TEST);
	return 0;
}

static int gl_color(lua_State *L)
{
#ifndef NO_OLD_GL
	tglColor4f(luaL_checknumber(L, 1), luaL_checknumber(L, 2), luaL_checknumber(L, 3), luaL_checknumber(L, 4));
#endif
	return 0;
}

static int sdl_texture_id(lua_State *L)
{
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 1);
	lua_pushnumber(L, t->tex);
	return 1;
}

static int sdl_texture_bind(lua_State *L)
{
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 1);
	int i = luaL_checknumber(L, 2);
	bool is3d = lua_toboolean(L, 3);

	if (i > 0)
	{
		if (multitexture_active && shaders_active)
		{
			tglActiveTexture(GL_TEXTURE0+i);
			tglBindTexture(is3d ? GL_TEXTURE_3D : GL_TEXTURE_2D, t->tex);
			tglActiveTexture(GL_TEXTURE0);
		}
	}
	else
	{
		tglBindTexture(is3d ? GL_TEXTURE_3D : GL_TEXTURE_2D, t->tex);
	}

	return 0;
}

static bool _CheckGL_Error(const char* GLcall, const char* file, const int line)
{
    GLenum errCode;
    if((errCode = glGetError())!=GL_NO_ERROR)
    {
		printf("OPENGL ERROR #%i: (%s) in file %s on line %i\n",errCode,gluErrorString(errCode), file, line);
        printf("OPENGL Call: %s\n",GLcall);
        return FALSE;
    }
    return TRUE;
}

//#define _DEBUG
#ifdef _DEBUG
#define CHECKGL( GLcall )                               		\
    GLcall;                                             		\
    if(!_CheckGL_Error( #GLcall, __FILE__, __LINE__))     		\
    exit(-1);
#else
#define CHECKGL( GLcall)        \
    GLcall;
#endif

static int sdl_texture_outline(lua_State *L)
{
	if (!fbo_active) return 0;

	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 1);
	float x = luaL_checknumber(L, 2);
	float y = luaL_checknumber(L, 3);
	int w = luaL_checknumber(L, 4);
	int h = luaL_checknumber(L, 5);
	float r = luaL_checknumber(L, 6);
	float g = luaL_checknumber(L, 7);
	float b = luaL_checknumber(L, 8);
	float a = luaL_checknumber(L, 9);
	int i;

	// Setup our FBO
	// WARNING: this is a static, only one FBO is ever made, and never deleted, for some reasons
	// deleting it makes the game crash when doing a chain lightning spell under luajit1 ... (yeah I know .. weird)
	static GLuint fbo = 0;
	if (!fbo) glGenFramebuffers(1, &fbo);
	glBindFramebuffer(GL_FRAMEBUFFER, fbo);

	// Now setup a texture to render to
	texture_type *img = (texture_type*)lua_newuserdata(L, sizeof(texture_type));
	img->w = w;
	img->h = h;
	auxiliar_setclass(L, "gl{texture}", -1);
	glGenTextures(1, &img->tex);
	tfglBindTexture(GL_TEXTURE_2D, img->tex);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8,  w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, img->tex, 0);

	GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
	if(status != GL_FRAMEBUFFER_COMPLETE) return 0;

	// Set the viewport and save the old one
	renderer_push_ortho_state(w, h);

	tglClearColor( 0.0f, 0.0f, 0.0f, 0.0f );
	glClear(GL_COLOR_BUFFER_BIT);

	tglBindTexture(GL_TEXTURE_2D, t->tex);

	/* Render to buffer: shadow */
	vertex_clear(generic_vx);
	vertex_add_quad(generic_vx,
		0, 0, 0, 0,
		w, 0, 1, 0,
		w, h, 1, 1,
		0, h, 0, 1,
		r, g, b, a
	);
	vertex_toscreen(generic_vx, x, y, 0, 1, 1, 1, 1);

	/* Render to buffer: original */
	vertex_clear(generic_vx);
	vertex_add_quad(generic_vx,
		0, 0, 0, 0,
		w, 0, 1, 0,
		w, h, 1, 1,
		0, h, 0, 1,
		1, 1, 1, 1
	);
	vertex_toscreen(generic_vx, 0, 0, 0, 1, 1, 1, 1);

	// Unbind texture from FBO and then unbind FBO
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, 0, 0);
	glBindFramebuffer(GL_FRAMEBUFFER, gl_c_fbo);

	// Cleanup
	// No, dot not it's a static, see upwards
//	CHECKGL(glDeleteFramebuffers(1, &fbo));

	renderer_pop_ortho_state();

	tglClearColor( 0.0f, 0.0f, 0.0f, 1.0f );

	return 1;
}

static int sdl_set_window_title(lua_State *L)
{
	const char *title = luaL_checkstring(L, 1);
	SDL_SetWindowTitle(window, title);
	return 0;
}

static int sdl_set_window_size(lua_State *L)
{
	int w = luaL_checknumber(L, 1);
	int h = luaL_checknumber(L, 2);
	bool fullscreen = lua_toboolean(L, 3);
	bool borderless = lua_toboolean(L, 4);

	printf("Setting resolution to %dx%d (%s, %s)\n", w, h, fullscreen ? "fullscreen" : "windowed", borderless ? "borderless" : "with borders");
	do_resize(w, h, fullscreen, borderless);

	lua_pushboolean(L, TRUE);
	return 1;
}

static int sdl_set_window_size_restart_check(lua_State *L)
{
	int w = luaL_checknumber(L, 1);
	int h = luaL_checknumber(L, 2);
	bool fullscreen = lua_toboolean(L, 3);
	bool borderless = lua_toboolean(L, 4);

	lua_pushboolean(L, resizeNeedsNewWindow(w, h, fullscreen, borderless));
	return 1;
}

static int sdl_set_window_pos(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	int y = luaL_checknumber(L, 2);

	do_move(x, y);

	lua_pushboolean(L, TRUE);
	return 1;
}

extern void on_redraw();
static int sdl_redraw_screen(lua_State *L)
{
	on_redraw();
	return 0;
}

int mouse_cursor_s_ref = LUA_NOREF;
int mouse_cursor_down_s_ref = LUA_NOREF;
SDL_Surface *mouse_cursor_s = NULL;
SDL_Surface *mouse_cursor_down_s = NULL;
SDL_Cursor *mouse_cursor = NULL;
SDL_Cursor *mouse_cursor_down = NULL;
extern int mouse_cursor_ox, mouse_cursor_oy;
static int sdl_set_mouse_cursor(lua_State *L)
{
	mouse_cursor_ox = luaL_checknumber(L, 1);
	mouse_cursor_oy = luaL_checknumber(L, 2);

	/* Down */
	if (mouse_cursor_down_s_ref != LUA_NOREF)
	{
		luaL_unref(L, LUA_REGISTRYINDEX, mouse_cursor_down_s_ref);
		mouse_cursor_down_s_ref = LUA_NOREF;
	}

	if (!lua_isnil(L, 4))
	{
		SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 4);
		mouse_cursor_down_s = *s;
		mouse_cursor_down_s_ref = luaL_ref(L, LUA_REGISTRYINDEX);

		if (mouse_cursor_down) { SDL_FreeCursor(mouse_cursor_down); mouse_cursor_down = NULL; }
		mouse_cursor_down = SDL_CreateColorCursor(mouse_cursor_down_s, -mouse_cursor_ox, -mouse_cursor_oy);
		if (mouse_cursor_down) SDL_SetCursor(mouse_cursor_down);
	}

	/* Default */
	if (mouse_cursor_s_ref != LUA_NOREF)
	{
		luaL_unref(L, LUA_REGISTRYINDEX, mouse_cursor_s_ref);
		mouse_cursor_s_ref = LUA_NOREF;
	}

	if (!lua_isnil(L, 3))
	{
		SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 3);
		mouse_cursor_s = *s;
		mouse_cursor_s_ref = luaL_ref(L, LUA_REGISTRYINDEX);

		if (mouse_cursor) { SDL_FreeCursor(mouse_cursor); mouse_cursor = NULL; }
		mouse_cursor = SDL_CreateColorCursor(mouse_cursor_s, -mouse_cursor_ox, -mouse_cursor_oy);
		if (mouse_cursor) SDL_SetCursor(mouse_cursor);
	}
	return 0;
}

extern int mouse_drag_tex, mouse_drag_tex_ref;
extern int mouse_drag_w, mouse_drag_h;
static int sdl_set_mouse_cursor_drag(lua_State *L)
{
	mouse_drag_w = luaL_checknumber(L, 2);
	mouse_drag_h = luaL_checknumber(L, 3);

	/* Default */
	if (mouse_drag_tex_ref != LUA_NOREF)
	{
		luaL_unref(L, LUA_REGISTRYINDEX, mouse_drag_tex_ref);
		mouse_drag_tex_ref = LUA_NOREF;
	}

	if (lua_isnil(L, 1))
	{
		mouse_drag_tex = 0;
	}
	else
	{
		texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 1);
		mouse_drag_tex = t->tex;
		mouse_drag_tex_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	}
	return 0;
}


/**************************************************************
 * Quadratic Objects
 **************************************************************/
static int gl_new_quadratic(lua_State *L)
{
	GLUquadricObj **quadratic = (GLUquadricObj**)lua_newuserdata(L, sizeof(GLUquadricObj*));
	auxiliar_setclass(L, "gl{quadratic}", -1);

	*quadratic = gluNewQuadric( );
	gluQuadricNormals(*quadratic, GLU_SMOOTH);
	gluQuadricTexture(*quadratic, GL_TRUE);

	return 1;
}

static int gl_free_quadratic(lua_State *L)
{
	GLUquadricObj **quadratic = (GLUquadricObj**)auxiliar_checkclass(L, "gl{quadratic}", 1);

	gluDeleteQuadric(*quadratic);

	lua_pushnumber(L, 1);
	return 1;
}

static int gl_quadratic_sphere(lua_State *L)
{
	GLUquadricObj **quadratic = (GLUquadricObj**)auxiliar_checkclass(L, "gl{quadratic}", 1);
	float rad = luaL_checknumber(L, 2);

	gluSphere(*quadratic, rad, 64, 64);

	return 0;
}

/**************************************************************
 * Framebuffer Objects
 **************************************************************/

static int gl_fbo_supports_transparency(lua_State *L) {
	lua_pushboolean(L, TRUE);
	return 1;
}

static int gl_new_fbo(lua_State *L)
{
	if (!fbo_active) return 0;

	int w = luaL_checknumber(L, 1);
	int h = luaL_checknumber(L, 2);

	lua_fbo *fbo = (lua_fbo*)lua_newuserdata(L, sizeof(lua_fbo));
	auxiliar_setclass(L, "gl{fbo}", -1);
	fbo->w = w;
	fbo->h = h;

	glGenFramebuffers(1, &(fbo->fbo));
	glBindFramebuffer(GL_FRAMEBUFFER, fbo->fbo);

	// Now setup a texture to render to
	glGenTextures(1, &(fbo->texture));
	tfglBindTexture(GL_TEXTURE_2D, fbo->texture);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8,  w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, fbo->texture, 0);

	GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
	if(status != GL_FRAMEBUFFER_COMPLETE) return 0;

	glBindFramebuffer(GL_FRAMEBUFFER, 0);

	return 1;
}

static int gl_free_fbo(lua_State *L)
{
	lua_fbo *fbo = (lua_fbo*)auxiliar_checkclass(L, "gl{fbo}", 1);

	glBindFramebuffer(GL_FRAMEBUFFER, fbo->fbo);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, 0, 0);
	glBindFramebuffer(GL_FRAMEBUFFER, 0);

	glDeleteTextures(1, &(fbo->texture));
	glDeleteFramebuffers(1, &(fbo->fbo));

	lua_pushnumber(L, 1);
	return 1;
}

static int gl_fbo_use(lua_State *L)
{
	lua_fbo *fbo = (lua_fbo*)auxiliar_checkclass(L, "gl{fbo}", 1);
	bool active = lua_toboolean(L, 2);

	if (active)
	{
		float r = 0, g = 0, b = 0, a = 1;
		if (lua_isnumber(L, 3))
		{
			r = luaL_checknumber(L, 3);
			g = luaL_checknumber(L, 4);
			b = luaL_checknumber(L, 5);
			a = luaL_checknumber(L, 6);
		}

		tglBindFramebuffer(GL_FRAMEBUFFER, fbo->fbo);

		renderer_push_ortho_state(fbo->w, fbo->h);

		tglClearColor(r, g, b, a);
		glClear(GL_COLOR_BUFFER_BIT);
	}
	else
	{
		renderer_pop_ortho_state();

		// Unbind texture from FBO and then unbind FBO
		if (!lua_isuserdata(L, 3)) { tglBindFramebuffer(GL_FRAMEBUFFER, 0); }
		else
		{
			lua_fbo *pfbo = (lua_fbo*)auxiliar_checkclass(L, "gl{fbo}", 3);
			tglBindFramebuffer(GL_FRAMEBUFFER, pfbo->fbo);
		}


	}
	return 0;
}

static int gl_fbo_toscreen(lua_State *L)
{
	lua_fbo *fbo = (lua_fbo*)auxiliar_checkclass(L, "gl{fbo}", 1);
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);
	int w = luaL_checknumber(L, 4);
	int h = luaL_checknumber(L, 5);
	bool allowblend = lua_toboolean(L, 11);
	float r = 1, g = 1, b = 1, a = 1;
	if (lua_isnumber(L, 7))
	{
		r = luaL_checknumber(L, 7);
		g = luaL_checknumber(L, 8);
		b = luaL_checknumber(L, 9);
		a = luaL_checknumber(L, 10);
	}
	bool has_shader = FALSE;
	if (lua_isuserdata(L, 6))
	{
		shader_type *s = (shader_type*)lua_touserdata(L, 6);
		useShader(s, fbo->w, fbo->h, w, h, 0, 0, 1, 1, r, g, b, a);
		has_shader = TRUE;
	}

	if (!allowblend) glDisable(GL_BLEND);

	vertex_clear(generic_vx);
	vertex_add_quad(generic_vx,
		0, 0, 0, 1,
		0, h, 0, 0,
		w, h, 1, 0,
		w, 0, 1, 1,
		r, g, b, a
	);
	vertex_toscreen(generic_vx, x, y, fbo->texture, 1, 1, 1, 1);

	if (has_shader) useNoShader();
	if (!allowblend) glEnable(GL_BLEND);
	return 0;
}

static int gl_fbo_posteffects(lua_State *L)
{
	lua_fbo *fbo = (lua_fbo*)auxiliar_checkclass(L, "gl{fbo}", 1);
	lua_fbo *fbo2 = (lua_fbo*)auxiliar_checkclass(L, "gl{fbo}", 2);
	lua_fbo *fbo_final = (lua_fbo*)auxiliar_checkclass(L, "gl{fbo}", 3);
	lua_fbo *tmpfbo;
	lua_fbo *srcfbo = fbo;
	lua_fbo *dstfbo = fbo2;
	int x = luaL_checknumber(L, 4);
	int y = luaL_checknumber(L, 5);
	int w = luaL_checknumber(L, 6);
	int h = luaL_checknumber(L, 7);

	glDisable(GL_BLEND);

	vertex_clear(generic_vx);
	vertex_add_quad(generic_vx,
		0, 0, 0, 1,
		0, h, 0, 0,
		w, h, 1, 0,
		w, 0, 1, 1,
		1, 1, 1, 1
	);

	// Set the viewport and save the old one
	renderer_push_ortho_state(fbo->w, fbo->h);

	tglClearColor(0, 0, 0, 1);

	int shad_idx = 8;
	while (lua_isuserdata(L, shad_idx) && lua_isuserdata(L, shad_idx+1)) {
		shader_type *s = (shader_type*)lua_touserdata(L, shad_idx);
		useShader(s, fbo->w, fbo->h, w, h, 0, 0, 1, 1, 1, 1, 1, 1);

		tglBindFramebuffer(GL_FRAMEBUFFER, dstfbo->fbo);
		glClear(GL_COLOR_BUFFER_BIT);
		vertex_toscreen(generic_vx, 0, 0, srcfbo->texture, 1, 1, 1, 1);

		shad_idx++;
		tmpfbo = srcfbo;
		srcfbo = dstfbo;
		dstfbo = tmpfbo;
	}

	// Bind final fbo (must have bee previously activated)
	shader_type *s = (shader_type*)lua_touserdata(L, shad_idx);
	useShader(s, fbo_final->w, fbo_final->h, w, h, 0, 0, 1, 1, 1, 1, 1, 1);

	renderer_pop_ortho_state();

	tglBindFramebuffer(GL_FRAMEBUFFER, fbo_final->fbo);
	glClear(GL_COLOR_BUFFER_BIT);
	vertex_toscreen(generic_vx, x, y, srcfbo->texture, 1, 1, 1, 1);

	useNoShader();

	glEnable(GL_BLEND);
	return 0;
}

static int gl_fbo_is_active(lua_State *L)
{
	lua_pushboolean(L, fbo_active);
	return 1;
}

static int gl_fbo_disable(lua_State *L)
{
	fbo_active = FALSE;
	return 0;
}

static int is_safe_mode(lua_State *L)
{
	lua_pushboolean(L, safe_mode);
	return 1;
}

static int set_safe_mode(lua_State *L)
{
	safe_mode = TRUE;
	fbo_active = FALSE;
	shaders_active = FALSE;
	multitexture_active = FALSE;
	return 0;
}

static int sdl_get_modes_list(lua_State *L)
{
	SDL_PixelFormat format;
	SDL_Rect **modes = NULL;
	int loops = 0;
	int bpp = 0;
	int nb = 1;
	lua_newtable(L);
	do
	{
		//format.BitsPerPixel seems to get zeroed out on my windows box
		switch(loops)
		{
			case 0://32 bpp
				format.BitsPerPixel = 32;
				bpp = 32;
				break;
			case 1://24 bpp
				format.BitsPerPixel = 24;
				bpp = 24;
				break;
			case 2://16 bpp
				format.BitsPerPixel = 16;
				bpp = 16;
				break;
		}

		//get available fullscreen/hardware modes
		modes = SDL_ListModes(&format, 0);
		if (modes)
		{
			int i;
			for(i=0; modes[i]; ++i)
			{
				printf("Available resolutions: %dx%dx%d\n", modes[i]->w, modes[i]->h, bpp/*format.BitsPerPixel*/);
				lua_pushnumber(L, nb++);
				lua_newtable(L);

				lua_pushliteral(L, "w");
				lua_pushnumber(L, modes[i]->w);
				lua_settable(L, -3);

				lua_pushliteral(L, "h");
				lua_pushnumber(L, modes[i]->h);
				lua_settable(L, -3);

				lua_settable(L, -3);
			}
		}
	}while(++loops != 3);
	return 1;
}

extern float gamma_correction;
static int sdl_set_gamma(lua_State *L)
{
	if (lua_isnumber(L, 1))
	{
		gamma_correction = lua_tonumber(L, 1);

		Uint16 red_ramp[256];
		Uint16 green_ramp[256];
		Uint16 blue_ramp[256];

		SDL_CalculateGammaRamp(gamma_correction, red_ramp);
		SDL_memcpy(green_ramp, red_ramp, sizeof(red_ramp));
		SDL_memcpy(blue_ramp, red_ramp, sizeof(red_ramp));
		SDL_SetWindowGammaRamp(window, red_ramp, green_ramp, blue_ramp);
	}
	lua_pushnumber(L, gamma_correction);
	return 1;
}

static void png_write_data_fn(png_structp png_ptr, png_bytep data, png_size_t length)
{
	luaL_Buffer *B = (luaL_Buffer*)png_get_io_ptr(png_ptr);
	luaL_addlstring(B, data, length);
}
static void png_output_flush_fn(png_structp png_ptr)
{
}

#ifndef png_infopp_NULL
#define png_infopp_NULL (png_infopp)NULL
#endif
static int sdl_get_png_screenshot(lua_State *L)
{
	unsigned int x = luaL_checknumber(L, 1);
	unsigned int y = luaL_checknumber(L, 2);
	unsigned long width = luaL_checknumber(L, 3);
	unsigned long height = luaL_checknumber(L, 4);
	unsigned long i;
	png_structp png_ptr;
	png_infop info_ptr;
	png_colorp palette;
	png_byte *image;
	png_bytep *row_pointers;

	png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);

	if (png_ptr == NULL)
	{
		return 0;
	}

	info_ptr = png_create_info_struct(png_ptr);
	if (info_ptr == NULL)
	{
		png_destroy_write_struct(&png_ptr, png_infopp_NULL);
		return 0;
	}

	if (setjmp(png_jmpbuf(png_ptr)))
	{
		png_destroy_write_struct(&png_ptr, &info_ptr);
		return 0;
	}

	luaL_Buffer B;
	luaL_buffinit(L, &B);
	png_set_write_fn(png_ptr, &B, png_write_data_fn, png_output_flush_fn);

	png_set_IHDR(png_ptr, info_ptr, width, height, 8, PNG_COLOR_TYPE_RGB,
		PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);

	image = (png_byte *)malloc(width * height * 3 * sizeof(png_byte));
	if(image == NULL)
	{
		png_destroy_write_struct(&png_ptr, &info_ptr);
		luaL_pushresult(&B); lua_pop(L, 1);
		return 0;
	}

	row_pointers = (png_bytep *)malloc(height * sizeof(png_bytep));
	if(row_pointers == NULL)
	{
		png_destroy_write_struct(&png_ptr, &info_ptr);
		free(image);
		image = NULL;
		luaL_pushresult(&B); lua_pop(L, 1);
		return 0;
	}

	glPixelStorei(GL_PACK_ALIGNMENT, 1);
	glReadPixels(x, y, width, height, GL_RGB, GL_UNSIGNED_BYTE, (GLvoid *)image);

	for (i = 0; i < height; i++)
	{
		row_pointers[i] = (png_bytep)image + (height - 1 - i) * width * 3;
	}

	png_set_rows(png_ptr, info_ptr, row_pointers);
	png_write_png(png_ptr, info_ptr, PNG_TRANSFORM_IDENTITY, NULL);

	png_destroy_write_struct(&png_ptr, &info_ptr);

	free(row_pointers);
	row_pointers = NULL;

	free(image);
	image = NULL;

	luaL_pushresult(&B);

	return 1;
}

static int gl_fbo_to_png(lua_State *L)
{
	lua_fbo *fbo = (lua_fbo*)auxiliar_checkclass(L, "gl{fbo}", 1);
	unsigned int x = 0;
	unsigned int y = 0;
	unsigned long width = fbo->w;
	unsigned long height = fbo->h;
	unsigned long i;
	png_structp png_ptr;
	png_infop info_ptr;
	png_colorp palette;
	png_byte *image;
	png_bytep *row_pointers;

	png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);

	if (png_ptr == NULL)
	{
		return 0;
	}

	info_ptr = png_create_info_struct(png_ptr);
	if (info_ptr == NULL)
	{
		png_destroy_write_struct(&png_ptr, png_infopp_NULL);
		return 0;
	}

	if (setjmp(png_jmpbuf(png_ptr)))
	{
		png_destroy_write_struct(&png_ptr, &info_ptr);
		return 0;
	}

	luaL_Buffer B;
	luaL_buffinit(L, &B);
	png_set_write_fn(png_ptr, &B, png_write_data_fn, png_output_flush_fn);

	png_set_IHDR(png_ptr, info_ptr, width, height, 8, PNG_COLOR_TYPE_RGB,
		PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);

	image = (png_byte *)malloc(width * height * 3 * sizeof(png_byte));
	if(image == NULL)
	{
		png_destroy_write_struct(&png_ptr, &info_ptr);
		luaL_pushresult(&B); lua_pop(L, 1);
		return 0;
	}

	row_pointers = (png_bytep *)malloc(height * sizeof(png_bytep));
	if(row_pointers == NULL)
	{
		png_destroy_write_struct(&png_ptr, &info_ptr);
		free(image);
		image = NULL;
		luaL_pushresult(&B); lua_pop(L, 1);
		return 0;
	}

	tglBindTexture(GL_TEXTURE_2D, fbo->texture);
#ifndef NO_OLD_GL
	glPixelStorei(GL_PACK_ALIGNMENT, 1);
	glGetTexImage(GL_TEXTURE_2D, 0, GL_RGB, GL_UNSIGNED_BYTE, (GLvoid *)image);
#endif
	for (i = 0; i < height; i++)
	{
		row_pointers[i] = (png_bytep)image + (height - 1 - i) * width * 3;
	}

	png_set_rows(png_ptr, info_ptr, row_pointers);
	png_write_png(png_ptr, info_ptr, PNG_TRANSFORM_IDENTITY, NULL);

	png_destroy_write_struct(&png_ptr, &info_ptr);

	free(row_pointers);
	row_pointers = NULL;

	free(image);
	image = NULL;

	luaL_pushresult(&B);

	return 1;
}


static int fbo_texture_bind(lua_State *L)
{
	lua_fbo *fbo = (lua_fbo*)auxiliar_checkclass(L, "gl{fbo}", 1);
	int i = luaL_checknumber(L, 2);

	if (i > 0)
	{
		if (multitexture_active && shaders_active)
		{
			tglActiveTexture(GL_TEXTURE0+i);
			tglBindTexture(GL_TEXTURE_2D, fbo->texture);
			tglActiveTexture(GL_TEXTURE0);
		}
	}
	else
	{
		tglBindTexture(GL_TEXTURE_2D, fbo->texture);
	}

	return 0;
}

static int pause_anims_started = 0;
static int display_pause_anims(lua_State *L) {
	bool new_state = lua_toboolean(L, 1);
	if (new_state == anims_paused) return 0;

	if (new_state) {
		anims_paused = TRUE;
		pause_anims_started = SDL_GetTicks();
	} else {
		anims_paused = FALSE;
		frame_tick_paused_time += SDL_GetTicks() - pause_anims_started;
	}
	printf("[DISPLAY] Animations paused: %d\n", anims_paused);
	return 0;
}

static int gl_get_max_texture_size(lua_State *L) {
	lua_pushnumber(L, max_texture_size);
	return 1;
}

static int gl_counts_draws(lua_State *L) {
	lua_pushnumber(L, nb_draws);
	nb_draws = 0;
	return 1;
}

static int is_modern_gl(lua_State *L) {
	lua_pushnumber(L, use_modern_gl);
	return 1;
}

static const struct luaL_Reg displaylib[] =
{
	{"forceRedraw", sdl_redraw_screen},
	{"size", sdl_screen_size},
	{"windowPos", sdl_window_pos},
	{"newSurface", sdl_new_surface},
	{"newFBO", gl_new_fbo},
	{"fboSupportsTransparency", gl_fbo_supports_transparency},
	{"newQuadratic", gl_new_quadratic},
	{"drawQuad", gl_draw_quad},
	{"drawQuadPart", gl_draw_quad_part},
	{"FBOActive", gl_fbo_is_active},
	{"isModernGL", is_modern_gl},
	{"safeMode", is_safe_mode},
	{"forceSafeMode", set_safe_mode},
	{"disableFBO", gl_fbo_disable},
	{"loadImage", sdl_load_image},
	{"loadImageMemory", sdl_load_image_mem},
	{"setWindowTitle", sdl_set_window_title},
	{"setWindowSize", sdl_set_window_size},
	{"setWindowSizeRequiresRestart", sdl_set_window_size_restart_check},
	{"setWindowPos", sdl_set_window_pos},
	{"getModesList", sdl_get_modes_list},
	{"setMouseCursor", sdl_set_mouse_cursor},
	{"setMouseDrag", sdl_set_mouse_cursor_drag},
	{"setGamma", sdl_set_gamma},
	{"pauseAnims", display_pause_anims},
	{"glTranslate", gl_translate},
	{"glScale", gl_scale},
	{"glRotate", gl_rotate},
	{"glPush", gl_push},
	{"glPop", gl_pop},
	{"glIdentity", gl_identity},
	{"glColor", gl_color},
	{"glMatrix", gl_matrix},
	{"glDepthTest", gl_depth_test},
	{"glScissor", gl_scissor},
	{"getScreenshot", sdl_get_png_screenshot},
	{"glMaxTextureSize", gl_get_max_texture_size},
	{"countDraws", gl_counts_draws},
	{NULL, NULL},
};

static const struct luaL_Reg sdl_surface_reg[] =
{
	{"__gc", sdl_free_surface},
	{"close", sdl_free_surface},
	{"erase", sdl_surface_erase},
	{"getSize", sdl_surface_get_size},
	{"merge", sdl_surface_merge},
	{"putChar", lua_display_char},
	{"drawString", sdl_surface_drawstring},
	{"drawStringBlended", sdl_surface_drawstring_aa},
	{"alpha", sdl_surface_alpha},
	{"glTexture", sdl_surface_to_texture},
	{"updateTexture", sdl_surface_update_texture},
	{NULL, NULL},
};

static const struct luaL_Reg sdl_texture_reg[] =
{
	{"__gc", sdl_free_texture},
	{"close", sdl_free_texture},
	{"toScreen", sdl_texture_toscreen},
	{"toScreenFull", sdl_texture_toscreen_full},
	{"toScreenPrecise", sdl_texture_toscreen_precise},
	{"toScreenHighlightHex", sdl_texture_toscreen_highlight_hex},
	{"makeOutline", sdl_texture_outline},
	{"toSurface", gl_texture_to_sdl},
	{"generateSDM", gl_texture_alter_sdm},
	{"bind", sdl_texture_bind},
	{"id", sdl_texture_id},
	{NULL, NULL},
};

static const struct luaL_Reg gl_fbo_reg[] =
{
	{"__gc", gl_free_fbo},
	{"toScreen", gl_fbo_toscreen},
	{"postEffects", gl_fbo_posteffects},
	{"bind", fbo_texture_bind},
	{"use", gl_fbo_use},
	{"png", gl_fbo_to_png},
	{NULL, NULL},
};

static const struct luaL_Reg gl_quadratic_reg[] =
{
	{"__gc", gl_free_quadratic},
	{"sphere", gl_quadratic_sphere},
	{NULL, NULL},
};

int luaopen_core_display(lua_State *L)
{
	auxiliar_newclass(L, "gl{texture}", sdl_texture_reg);
	auxiliar_newclass(L, "gl{fbo}", gl_fbo_reg);
	auxiliar_newclass(L, "gl{quadratic}", gl_quadratic_reg);
	auxiliar_newclass(L, "sdl{surface}", sdl_surface_reg);
	luaL_openlib(L, "core.display", displaylib, 0);
	lua_settop(L, 0);
	return 1;
}

void core_display_init() {
	generic_vx = vertex_new(NULL, 4, 0, VO_QUADS, VERTEX_STREAM);
	generic_vx_fan = vertex_new(NULL, 4, 0, VO_TRIANGLE_FAN, VERTEX_STREAM);
}
