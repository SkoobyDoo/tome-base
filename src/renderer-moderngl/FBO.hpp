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

#ifndef FBO_GL_HPP
#define FBO_GL_HPP

#include "renderer-moderngl/Renderer.hpp"

class DORTarget;

struct Fbo {
	GLuint fbo;
	vector<GLuint> textures;
	vector<GLenum> buffers;
};

/****************************************************************************
 ** Special modes for Target to render as
 ****************************************************************************/
class TargetSpecialMode {
protected:
	DORTarget *target;
public:
	TargetSpecialMode(DORTarget *t) { target = t; };
	virtual ~TargetSpecialMode() {};
	virtual void renderMode() = 0;
};

class TargetBloom : public TargetSpecialMode {
protected:
	shader_type *bloom = NULL;
	shader_type *hblur = NULL;
	shader_type *vblur = NULL;
	shader_type *combine = NULL;
	int bloom_ref = LUA_NOREF;
	int hblur_ref = LUA_NOREF;
	int vblur_ref = LUA_NOREF;
	int combine_ref = LUA_NOREF;

	int blur_passes;

	Fbo fbo_plain;
	Fbo fbo_bloom;
	Fbo fbo_hblur;
	Fbo fbo_vblur;

	VBO vbo;
public:
	TargetBloom(DORTarget *t, int blur_passes, shader_type *bloom, int bloom_ref, shader_type *hblur, int hblur_ref, shader_type *vblur, int vblur_ref, shader_type *combine, int combine_ref);
	virtual ~TargetBloom();
	virtual void renderMode();
};

/****************************************************************************
 ** A FBO that masquerades as a DORVertexes, draw stuff in it and
 ** then add it to a renderer to use the content generated
 ****************************************************************************/
class DORTarget : public DORVertexes, public IResizable {
	friend class TargetBloom;
protected:
	int w, h;
	Fbo fbo;
	int nbt = 0;
	float clear_r = 0, clear_g = 0, clear_b = 0, clear_a = 1; 
	SubRenderer *subrender = NULL;
	int subrender_lua_ref = LUA_NOREF;
	int view_lua_ref = LUA_NOREF;
	View *view;
	TargetSpecialMode *mode = NULL;

	virtual void cloneInto(DisplayObject *into);

public:
	DORTarget();
	DORTarget(int w, int h, int nbt, bool hdr=false);
	virtual ~DORTarget();
	virtual DisplayObject* clone(); // We dont use the standard definition, see .cpp file
	virtual const char* getKind() { return "DORTarget"; };
	virtual void setTexture(GLuint tex, int lua_ref, int id);

	void setView(View *view, int ref);
	void setClearColor(float r, float g, float b, float a);
	void displaySize(int w, int h, bool center);
	void getDisplaySize(int *w, int *h) { *w = this->w; *h = this->h; };
	void use(bool activate);
	void setAutoRender(SubRenderer *subrender, int ref);

	virtual void render(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible);
	virtual void renderZ(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible);
	virtual void tick();

	virtual void onScreenResize(int w, int h);

	void setSpecialMode(TargetSpecialMode *mode);

	void makeFramebuffer(int w, int h, int nbt, bool hdr, Fbo *fbo);
	void deleteFramebuffer(Fbo *fbo);
	void useFramebuffer(Fbo *fbo);
};

#endif
