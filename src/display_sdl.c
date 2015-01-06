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
#include "display_sdl.h"
#include <stdlib.h>

#define DISPLAY_CHAR_SIZE  16
SDL_Surface *screen = NULL;

void display_put_char(SDL_Surface *surface, char c, int x, int y, int r, int g, int b)
{
	SDL_Rect rect;

	rect.x = x*DISPLAY_CHAR_SIZE;
	rect.y = y*DISPLAY_CHAR_SIZE;

	if (c == '.') {
		rect.x += DISPLAY_CHAR_SIZE*3/8;
		rect.y += DISPLAY_CHAR_SIZE*3/8;
		rect.w = rect.h = DISPLAY_CHAR_SIZE/4;
	} else {
		rect.w = rect.h = DISPLAY_CHAR_SIZE - 1;
	}

	SDL_FillRect(surface, &rect, SDL_MapRGB(screen->format, r, g, b));
}

void display_put_string(SDL_Surface *surface, const char *s, int x, int y, int r, int g, int b) {
	int i;
	for (i = 0; s[i] != '\0'; ++i) {
		display_put_char(surface, s[i], x + i, y, r, g, b);
	}
}

void sdlDrawImage(SDL_Surface *dest, SDL_Surface *image, int x, int y)
{
	SDL_Rect r;
	r.w=image->w;
	r.h=image->h;
	r.x=x;
	r.y=y;
	int errcode = SDL_BlitSurface(image, NULL, dest, &r);
        if (errcode)
          printf("ERROR! SDL_BlitSurface failed! (%d,%s)\n",errcode,SDL_GetError());
}


// Current gl color, to remove the need to call glColor4f when undeeded
float gl_c_r = 1;
float gl_c_g = 1;
float gl_c_b = 1;
float gl_c_a = 1;
float gl_c_cr = 0;
float gl_c_cg = 0;
float gl_c_cb = 0;
float gl_c_ca = 1;
GLuint gl_c_texture = 0;
GLenum gl_c_texture_unit = GL_TEXTURE0;
GLuint gl_c_fbo = 0;
GLuint gl_c_shader = 0;
int nb_draws = 0;
GLfloat *gl_c_vertices_ptr = NULL;
GLfloat *gl_c_texcoords_ptr = NULL;
GLfloat *gl_c_colors_ptr = NULL;

#if defined(USE_GLES1)
/*
 * SGI FREE SOFTWARE LICENSE B (Version 2.0, Sept. 18, 2008)
 * Copyright (C) 1991-2000 Silicon Graphics, Inc. All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice including the dates of first publication and
 * either this permission notice or a reference to
 * http://oss.sgi.com/projects/FreeB/
 * shall be included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * SILICON GRAPHICS, INC. BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
 * OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Except as contained in this notice, the name of Silicon Graphics, Inc.
 * shall not be used in advertising or otherwise to promote the sale, use or
 * other dealings in this Software without prior written authorization from
 * Silicon Graphics, Inc.
 *
 * OpenGL ES 1.0 CM port of GLU by Mike Gorchak <mike@malva.ua>
 */

#include <stdio.h>
#include <stdlib.h>

// #include "glues_error.h"

static unsigned char* __gluNurbsErrors[]=
{
   (unsigned char*) " ",
   (unsigned char*) "spline order un-supported",
   (unsigned char*) "too few knots",
   (unsigned char*) "valid knot range is empty",
   (unsigned char*) "decreasing knot sequence knot",
   (unsigned char*) "knot multiplicity greater than order of spline",
   (unsigned char*) "gluEndCurve() must follow gluBeginCurve()",
   (unsigned char*) "gluBeginCurve() must precede gluEndCurve()",
   (unsigned char*) "missing or extra geometric data",
   (unsigned char*) "can't draw piecewise linear trimming curves",
   (unsigned char*) "missing or extra domain data",
   (unsigned char*) "missing or extra domain data",
   (unsigned char*) "gluEndTrim() must precede gluEndSurface()",
   (unsigned char*) "gluBeginSurface() must precede gluEndSurface()",
   (unsigned char*) "curve of improper type passed as trim curve",
   (unsigned char*) "gluBeginSurface() must precede gluBeginTrim()",
   (unsigned char*) "gluEndTrim() must follow gluBeginTrim()",
   (unsigned char*) "gluBeginTrim() must precede gluEndTrim()",
   (unsigned char*) "invalid or missing trim curve",
   (unsigned char*) "gluBeginTrim() must precede gluPwlCurve()",
   (unsigned char*) "piecewise linear trimming curve referenced twice",
   (unsigned char*) "piecewise linear trimming curve and nurbs curve mixed",
   (unsigned char*) "improper usage of trim data type",
   (unsigned char*) "nurbs curve referenced twice",
   (unsigned char*) "nurbs curve and piecewise linear trimming curve mixed",
   (unsigned char*) "nurbs surface referenced twice",
   (unsigned char*) "invalid property",
   (unsigned char*) "gluEndSurface() must follow gluBeginSurface()",
   (unsigned char*) "intersecting or misoriented trim curves",
   (unsigned char*) "intersecting trim curves",
   (unsigned char*) "UNUSED",
   (unsigned char*) "unconnected trim curves",
   (unsigned char*) "unknown knot error",
   (unsigned char*) "negative vertex count encountered",
   (unsigned char*) "negative byte-stride encounteed",
   (unsigned char*) "unknown type descriptor",
   (unsigned char*) "null control point reference",
   (unsigned char*) "duplicate point on piecewise linear trimming curve",
};

const unsigned char* __gluNURBSErrorString(int errnum)
{
   return __gluNurbsErrors[errnum];
}

static unsigned char* __gluTessErrors[]=
{
   (unsigned char*) " ",
   (unsigned char*) "gluTessBeginPolygon() must precede a gluTessEndPolygon()",
   (unsigned char*) "gluTessBeginContour() must precede a gluTessEndContour()",
   (unsigned char*) "gluTessEndPolygon() must follow a gluTessBeginPolygon()",
   (unsigned char*) "gluTessEndContour() must follow a gluTessBeginContour()",
   (unsigned char*) "a coordinate is too large",
   (unsigned char*) "need combine callback",
};

const unsigned char* __gluTessErrorString(int errnum)
{
   return __gluTessErrors[errnum];
}

struct token_string
{
   GLuint Token;
   const char* String;
};

static const struct token_string Errors[]=
{
   /* GL */
   {GL_NO_ERROR, "no error"},
   {GL_INVALID_ENUM, "invalid enumerant"},
   {GL_INVALID_VALUE, "invalid value"},
   {GL_INVALID_OPERATION, "invalid operation"},
   // {GL_STACK_OVERFLOW, "stack overflow"},
   // {GL_STACK_UNDERFLOW, "stack underflow"},
   {GL_OUT_OF_MEMORY, "out of memory"},

   /* GLU */
   { GLU_INVALID_ENUM, "invalid enumerant"},
   { GLU_INVALID_VALUE, "invalid value"},
   { GLU_OUT_OF_MEMORY, "out of memory"},
   { GLU_INCOMPATIBLE_GL_VERSION, "incompatible gl version"},
   { GLU_INVALID_OPERATION, "invalid operation"},
   { ~0, NULL } /* end of list indicator */
};

const GLubyte* gluErrorString(GLenum errorCode)
{
   int i;

   for (i=0; Errors[i].String; i++)
   {
      if (Errors[i].Token==errorCode)
      {
         return (const GLubyte*) Errors[i].String;
      }
   }

   if ((errorCode>=GLU_NURBS_ERROR1) && (errorCode<=GLU_NURBS_ERROR37))
   {
      return (const GLubyte*)__gluNURBSErrorString(errorCode-(GLU_NURBS_ERROR1-1));
   }
   if ((errorCode>=GLU_TESS_ERROR1) && (errorCode<=GLU_TESS_ERROR6))
   {
      return (const GLubyte*) __gluTessErrorString(errorCode-(GLU_TESS_ERROR1-1));
   }

   return (const GLubyte*)0;
}
#endif
