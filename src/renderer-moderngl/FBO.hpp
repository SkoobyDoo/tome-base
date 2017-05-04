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
#include <map>

class DORTarget;

struct FboTexture {

	GLuint texture;
	bool gc;
};

struct Fbo {
	GLuint fbo;
	GLuint depthbuffer;
	vector<FboTexture> textures;
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

/****************************************************************************
 ** Blur mode with a single blur shader
 ****************************************************************************/
class TargetBlur : public TargetSpecialMode {
protected:
	shader_type *blur = NULL;
	int blur_ref = LUA_NOREF;
	GLint blur_horizontal_uniform = 0;
	int blur_passes;
	Fbo fbo_blur;

	VBO vbo;
public:
	TargetBlur(DORTarget *t, int blur_passes, shader_type *blur, int blur_ref);
	virtual ~TargetBlur();
	virtual void renderMode();
};


/****************************************************************************
 ** Blur mode using downsampling
 ****************************************************************************/
struct DownsampledFbo {
	Fbo fbo;
	VBO *vbo;
	int w, h;
};
class TargetBlurDownsampling : public TargetSpecialMode {
protected:
	shader_type *blur = NULL;
	int blur_ref = LUA_NOREF;
	vector<DownsampledFbo> fbos;
	VBO vbo;
public:
	TargetBlurDownsampling(DORTarget *t, int blur_passes, shader_type *blur, int blur_ref);
	virtual ~TargetBlurDownsampling();
	virtual void renderMode();
};


/****************************************************************************
 ** Bloom mode with a single blur shader
 ****************************************************************************/
class TargetBloom2 : public TargetSpecialMode {
protected:
	shader_type *bloom = NULL;
	shader_type *blur = NULL;
	shader_type *combine = NULL;
	int bloom_ref = LUA_NOREF;
	int blur_ref = LUA_NOREF;
	int combine_ref = LUA_NOREF;

	GLint blur_horizontal_uniform = 0;

	int blur_passes;

	Fbo fbo_plain;
	Fbo fbo_bloom;
	Fbo fbo_hblur;
	Fbo fbo_vblur;

	VBO vbo;
public:
	TargetBloom2(DORTarget *t, int blur_passes, shader_type *bloom, int bloom_ref, shader_type *blur, int blur_ref,shader_type *combine, int combine_ref);
	virtual ~TargetBloom2();
	virtual void renderMode();
};


/****************************************************************************
 ** Bloom mode with a double blur shader
 ****************************************************************************/
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
 ** Pass rendering through a series of shaders
 ****************************************************************************/
struct shader_ref {
	string name;
	shader_type *shader;
	int lua_ref = LUA_NOREF;
	bool active = false;
};

class TargetPostProcess : public TargetSpecialMode {
protected:
	vector<shader_ref> shaders;

	Fbo fbo;
	VBO vbo;
public:
	TargetPostProcess(DORTarget *t);
	virtual ~TargetPostProcess();

	void add(string name, shader_type *shader, int ref);
	void disableAll();
	void enable(string name, bool v);

	virtual void renderMode();
};

/****************************************************************************
 ** A FBO that masquerades as a DORVertexes, draw stuff in it and
 ** then add it to a renderer to use the content generated
 ****************************************************************************/
class DORTarget : public DORVertexes, public IResizable {
	friend class TargetBlur;
	friend class TargetBlurDownsampling;
	friend class TargetBloom;
	friend class TargetBloom2;
	friend class TargetPostProcess;
protected:
	int w, h;
	Fbo fbo;
	int nbt = 0;
	float clear_r = 0, clear_g = 0, clear_b = 0, clear_a = 1; 
	ISubRenderer *subrender = NULL;
	int subrender_lua_ref = LUA_NOREF;
	int view_lua_ref = LUA_NOREF;
	View *view;
	TargetSpecialMode *mode = NULL;

	VBO *toscreen_vbo = NULL;

	virtual void cloneInto(DisplayObject *into);

public:
	DORTarget();
	DORTarget(int w, int h, int nbt, bool hdr=false, bool depth=false);
	virtual ~DORTarget();
	virtual DisplayObject* clone(); // We dont use the standard definition, see .cpp file
	virtual const char* getKind() { return "DORTarget"; };
	virtual void setTexture(GLuint tex, int lua_ref, int id);

	void setView(View *view, int ref);
	void setClearColor(float r, float g, float b, float a);
	void displaySize(int w, int h, bool center);
	void getDisplaySize(int *w, int *h) { *w = this->w; *h = this->h; };
	void use(bool activate);
	void setAutoRender(ISubRenderer *subrender, int ref);

	virtual void render(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible);
	virtual void renderZ(RendererGL *container, mat4 cur_model, vec4 color, bool cur_visible);
	virtual void tick();

	virtual void onScreenResize(int w, int h);

	void toScreen(int x, int y);

	void setSpecialMode(TargetSpecialMode *mode);

	void makeFramebuffer(int w, int h, int nbt, bool hdr, bool depth, Fbo *fbo);
	void deleteFramebuffer(Fbo *fbo);
	void useFramebuffer(Fbo *fbo);
};

#endif
