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

#include "renderer-moderngl/FBO.hpp"
extern "C" {
#include "shaders.h"
}

/*************************************************************************
 ** DORTarget
 *************************************************************************/
DisplayObject* DORTarget::clone() {
	DORTarget *into = new DORTarget(w, h, nbt);
	this->cloneInto(into);
	return into;
}
void DORTarget::cloneInto(DisplayObject* _into) {
	DORVertexes::cloneInto(_into);
	DORTarget *into = dynamic_cast<DORTarget*>(_into);
	into->clear_r = clear_r;
	into->clear_g = clear_g;
	into->clear_b = clear_b;
	into->clear_a = clear_a;
	into->mode = NULL;
}

DORTarget::DORTarget() : DORTarget(screen->w / screen_zoom, screen->h / screen_zoom, 1) {
}
DORTarget::DORTarget(int w, int h, int nbt, bool hdr, bool depth) {
	this->nbt = nbt;
	this->w = w;
	this->h = h;

	view = NULL;

	makeFramebuffer(w, h, nbt, hdr, depth, &fbo);

	// For display as a DO
	for (int i = 0; i < (nbt > 3 ? 3 : nbt); i++) tex[i] = fbo.textures[i].texture;

	// Default display quad, can be removed and altered if needed with clear & addQuad
	addQuad(
		0, 0, 0, 1,
		0, h, 0, 0,
		w, h, 1, 0,
		w, 0, 1, 1,
		1, 1, 1, 1
	);
	printf("[RendererGL] New FBO %dx%d\n", w, h);
}
DORTarget::~DORTarget() {
	if (mode) delete mode;
	if (toscreen_vbo) delete toscreen_vbo;

	if (view_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, view_lua_ref);
	if (subrender_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, subrender_lua_ref);

	deleteFramebuffer(&fbo);
}

void DORTarget::makeFramebuffer(int w, int h, int nbt, bool hdr, bool depth, Fbo *fbo) {
	glGenFramebuffers(1, &fbo->fbo);
	tglBindFramebuffer(GL_FRAMEBUFFER, fbo->fbo);

	// Now setup a texture to render to
	int i;
	fbo->textures.resize(nbt);
	fbo->buffers.resize(nbt);
	vector<GLuint> td(nbt);
	glGenTextures(nbt, td.data());

	if (depth) {
		glGenTextures(1, &fbo->depthbuffer);
		glBindTexture(GL_TEXTURE_2D, fbo->depthbuffer);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT, w, h, 0, GL_DEPTH_COMPONENT, GL_FLOAT, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, fbo->depthbuffer, 0);
	} else {
		fbo->depthbuffer = 0;
	}

	for (i = 0; i < nbt; i++) {
		fbo->textures[i].texture = td[i];
		fbo->textures[i].gc = true;
		tfglBindTexture(GL_TEXTURE_2D, fbo->textures[i].texture);
		glTexImage2D(GL_TEXTURE_2D, 0, hdr ? GL_RGBA16F : GL_RGBA8,  w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + i, GL_TEXTURE_2D, fbo->textures[i].texture, 0);
		fbo->buffers[i] = GL_COLOR_ATTACHMENT0 + i;
	}

	tglBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void DORTarget::deleteFramebuffer(Fbo *fbo) {
	int nbt = fbo->textures.size();
	tglBindFramebuffer(GL_FRAMEBUFFER, fbo->fbo);
	for (int i = 0; i < nbt; i++) {
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + i, GL_TEXTURE_2D, 0, 0);
		auto &t = fbo->textures[i];
		if (t.gc) {
			glDeleteTextures(1, &t.texture);
		}
	}

	if (fbo->depthbuffer) {
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, 0, 0);
		glDeleteTextures(1, &fbo->depthbuffer);
	}

	tglBindFramebuffer(GL_FRAMEBUFFER, 0);

	glDeleteFramebuffers(1, &fbo->fbo);
}

void DORTarget::setView(View *view, int ref) {
	if (view_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, view_lua_ref);
	this->view = view;
	view_lua_ref = ref;
}

void DORTarget::setTexture(GLuint tex, int lua_ref, int id) {
	if (id == 0) printf("Error, trying to set DORTarget texture 0.\n");
	else DORVertexes::setTexture(tex, lua_ref, id);
}

void DORTarget::displaySize(int w, int h, bool center) {
	clear();
	int x1 = 0, x2 = w;
	int y1 = 0, y2 = h;
	if (center) {
		w = w / 2;
		h = h / 2;
		x1 = -w; x2 = w;
		y1 = -h; y2 = h;
	}
	addQuad(
		x1, y1, 0, 1,
		x1, y2, 0, 0,
		x2, y2, 1, 0,
		x2, y1, 1, 1,
		1, 1, 1, 1
	);
}

void DORTarget::setClearColor(float r, float g, float b, float a) {
	clear_r = r;
	clear_g = g;
	clear_b = b;
	clear_a = a;
}

void DORTarget::useFramebuffer(Fbo *fbo) {
	tglBindFramebuffer(GL_FRAMEBUFFER, fbo->fbo);
	glDrawBuffers(fbo->buffers.size(), fbo->buffers.data());
	tglClearColor(clear_r, clear_g, clear_b, clear_a);
	if (fbo->depthbuffer) glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	else glClear(GL_COLOR_BUFFER_BIT);
}

static stack<GLuint> fbo_stack;
void DORTarget::use(bool activate) {
	if (activate)
	{
		useFramebuffer(&fbo);
		fbo_stack.push(fbo.fbo);
		if (view) view->use(true);
	}
	else
	{
		fbo_stack.pop();
		tglClearColor(0, 0, 0, 1);

		// If we have a special mode to do stuff, do it now!
		if (mode) mode->renderMode();
		
		if (view) view->use(false);

		// Unbind texture from FBO and then unbind FBO
		if (!fbo_stack.empty()) {
			tglBindFramebuffer(GL_FRAMEBUFFER, fbo_stack.top());
		} else {
			tglBindFramebuffer(GL_FRAMEBUFFER, 0);
		}
	}
}

void DORTarget::setAutoRender(SubRenderer *o, int ref) {
	if (subrender_lua_ref != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, subrender_lua_ref);
	subrender_lua_ref = ref;
	subrender = o;
	setChanged();
}

void DORTarget::render(RendererGL *container, mat4& cur_model, vec4& cur_color, bool cur_visible) {
	if (subrender) {
		stopDisplayList(); // Needed to make sure we break texture chaining
		auto dl = getDisplayList(container);
		dl->tick = this;
	}

	DORVertexes::render(container, cur_model, cur_color, cur_visible);
}

// void DORTarget::renderZ(RendererGL *container, mat4& cur_model, vec4& cur_color, bool cur_visible) {
// 	if (subrender) {
// 		int startat = container->zvertices.size();
// 		container->zvertices.resize(startat + 1);
// 		sortable_vertex *dest = container->zvertices.data();
// 		dest[startat].tick = this;
// 	}

// 	DORVertexes::renderZ(container, cur_model, cur_color, cur_visible);
// }

void DORTarget::tick() {
	if (!subrender) return;
	use(true);
	subrender->toScreenSimple();
	use(false);
}

void DORTarget::onScreenResize(int w, int h) {
	// DGDGDGDG: Do something !!!!!
}

void DORTarget::setSpecialMode(TargetSpecialMode *mode) {
	this->mode = mode;
}

void DORTarget::toScreen(int x, int y) {
	if (!toscreen_vbo) {
		toscreen_vbo = new VBO(VBOMode::STATIC);
		toscreen_vbo->addQuad(
			0, 0, 0, 1,
			w, 0, 1, 1,
			w, h, 1, 0,
			0, h, 0, 0,
			1, 1, 1, 1
		);
		toscreen_vbo->setTexture(fbo.textures[0].texture);
		toscreen_vbo->setShader(shader);
	}
	toscreen_vbo->toScreen(x, y, 0, 1, 1);
}

/*************************************************************************
 ** TargetPostProcess
 *************************************************************************/
TargetPostProcess::TargetPostProcess(DORTarget *t)
	: TargetSpecialMode(t), vbo(VBOMode::STATIC)
{
	target->makeFramebuffer(target->w, target->h, 1, false, false, &fbo);

	vbo.addQuad(
		0, 0, 0, 1,
		target->w, 0, 1, 1,
		target->w, target->h, 1, 0,
		0, target->h, 0, 0,
		1, 1, 1, 1
	);
}
TargetPostProcess::~TargetPostProcess() {
	for (auto &it : shaders) {
		if (it.lua_ref != LUA_NOREF) { luaL_unref(L, LUA_REGISTRYINDEX, it.lua_ref); }
	}
	target->deleteFramebuffer(&fbo);
}

void TargetPostProcess::add(string name, shader_type *shader, int ref) {
	shader_ref sref;
	sref.name = name;
	sref.shader = shader;
	sref.lua_ref = ref;
	sref.active = false;
	shaders.push_back(sref);
}

void TargetPostProcess::disableAll() {
	for (auto &ref : shaders) {
		ref.active = false;
	}
}

void TargetPostProcess::enable(string name, bool v) {
	for (auto &ref : shaders) {
		if (ref.name == name) {
			ref.active = v;
			break;
		}
	}
}

void TargetPostProcess::renderMode() {
	if (!shaders.size()) return;
	mat4 model = mat4();
	glDisable(GL_BLEND);
	
	// Draw all passes
	bool nothing = true;
	Fbo *use_fbo_prev = &target->fbo;
	Fbo *use_fbo = &fbo;
	for (auto &ref : shaders) { if (ref.active) {
		nothing = false;
		target->useFramebuffer(use_fbo);
		vbo.setTexture(use_fbo_prev->textures[0].texture);
		vbo.setShader(ref.shader);
		vbo.toScreen(model);

		swap(use_fbo_prev, use_fbo);
	} }
	if (nothing) { glEnable(GL_BLEND); return; }

	// If we didnt end up in the rigth buffer, draw back into the normal FBO
	if (use_fbo == &target->fbo) {
		target->useFramebuffer(&target->fbo);
		vbo.setTexture(use_fbo_prev->textures[0].texture);
		vbo.setShader(NULL);
		vbo.toScreen(model);
	}

	glEnable(GL_BLEND);
}	

/*************************************************************************
 ** TargetBlur
 *************************************************************************/
TargetBlur::TargetBlur(DORTarget *t, int blur_passes, float renderscale, shader_type *blur, int blur_ref)
	: TargetSpecialMode(t), vbo(VBOMode::STATIC)
{
	this->blur = blur;
	this->blur_ref = blur_ref;

	this->blur_passes = blur_passes;
	this->renderscale = renderscale;

	useShaderSimple(blur);
	blur_horizontal_uniform = glGetUniformLocation(blur->shader, "horizontal");

	target->makeFramebuffer(target->w, target->h, 1, true, false, &fbo_blur);
	view.setOrthoView(target->w, target->h, false);

	vbo.addQuad(
		0, 0, 0, 1,
		target->w, 0, 1, 1,
		target->w, target->h, 1, 0,
		0, target->h, 0, 0,
		1, 1, 1, 1
	);
}
TargetBlur::~TargetBlur() {
	target->deleteFramebuffer(&fbo_blur);

	if (blur_ref != LUA_NOREF) { luaL_unref(L, LUA_REGISTRYINDEX, blur_ref); blur_ref = LUA_NOREF; }
}

void TargetBlur::renderMode() {
	mat4 model = mat4();
	model = glm::scale(model, glm::vec3(1.f/renderscale, 1.f/renderscale, 1));

	vbo.resetTexture();
	glDisable(GL_BLEND);
	// glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); // DGDGDGDG: probably betetr to use premultipled alpha, work on me!

	// Draw all passes
	view.use(true);
	vbo.setShader(blur);
	Fbo *use_fbo_prev = &target->fbo;
	Fbo *use_fbo = &fbo_blur;
	for (int i = 0; i < blur_passes; i++) {
		target->useFramebuffer(use_fbo);

		vbo.setTexture(use_fbo_prev->textures[0].texture);
		float radius = blur_passes + 1 - i;
		GLfloat uni[2] = {radius, 0};
		if (i % 2 == 1) { uni[0] = 0; uni[1] = radius; }
		glUniform2fv(blur_horizontal_uniform, 1, uni);
		vbo.toScreen(model);

		swap(use_fbo_prev, use_fbo);
	}

	// If we didnt end up in the rigth buffer, draw back into the normal FBO
	// Usage note: you probably want to avoid an odd number of passes, since this means doing a useless copy at the end
	if (use_fbo == &target->fbo) {
		target->useFramebuffer(&target->fbo);
		vbo.setTexture(use_fbo_prev->textures[0].texture);
		vbo.setShader(NULL);
		vbo.toScreen(model);
	}
	view.use(false);

	// glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_BLEND);
}	

/*************************************************************************
 ** TargetBlurDownsampling
 *************************************************************************/
TargetBlurDownsampling::TargetBlurDownsampling(DORTarget *t, int blur_passes, shader_type *blur, int blur_ref)
	: TargetSpecialMode(t), vbo(VBOMode::STATIC)
{
	this->blur = blur;
	this->blur_ref = blur_ref;

	fbos.resize(blur_passes);
	int w = target->w, h = target->h;
	vbo.setShader(blur);
	vbo.addQuad(
		0, 0, 0, 1,
		w, 0, 1, 1,
		w, h, 1, 0,
		0, h, 0, 0,
		1, 1, 1, 1
	);

	int ph = h;
	for (int i = 0; i < blur_passes; i++) {
		w /= 2; h /= 2;
		fbos[i].w = w;
		fbos[i].h = h;
		target->makeFramebuffer(w, h, 1, true, false, &fbos[i].fbo);

		fbos[i].vbo = new VBO(VBOMode::STATIC);
		fbos[i].vbo->setShader(NULL);
		fbos[i].vbo->setTexture(i == 0 ? target->fbo.textures[0].texture : fbos[i-1].fbo.textures[0].texture);
		fbos[i].vbo->addQuad(
			0, ph, 0, 0,
			w, ph, 1, 0,
			w, ph-h, 1, 1,
			0, ph-h, 0, 1,
			1, 1, 1, 1
		);
		vbo.setTexture(fbos[i].fbo.textures[0].texture, i);
		printf("TargetBlurDownsampling: %dx%d\n", w, h);
	}
}
TargetBlurDownsampling::~TargetBlurDownsampling() {
	for (auto &fbo : fbos) {
		target->deleteFramebuffer(&fbo.fbo);
		delete fbo.vbo;
	}

	if (blur_ref != LUA_NOREF) { luaL_unref(L, LUA_REGISTRYINDEX, blur_ref); blur_ref = LUA_NOREF; }
}

void TargetBlurDownsampling::renderMode() {
	mat4 model = mat4();
	glDisable(GL_BLEND);

	for (auto &fbo : fbos) {
		target->useFramebuffer(&fbo.fbo);
		fbo.vbo->toScreen(model);
	}

	target->useFramebuffer(&target->fbo);
	vbo.toScreen(model);

	// target->useFramebuffer(&target->fbo);
	// vbo.setTexture(use_fbo_prev->textures[0].texture);
	// vbo.setShader(NULL);
	// vbo.toScreen(model);

	// Draw all passes
	// vbo.setShader(blur);
	// Fbo *use_fbo_prev = &target->fbo;
	// Fbo *use_fbo = &fbo_blur;
	// for (int i = 0; i < blur_passes; i++) {
	// 	target->useFramebuffer(use_fbo);

	// 	vbo.setTexture(use_fbo_prev->textures[0].texture);
	// 	float radius = blur_passes + 1 - i;
	// 	GLfloat uni[2] = {radius, 0};
	// 	if (i % 2 == 1) { uni[0] = 0; uni[1] = radius; }
	// 	glUniform2fv(blur_horizontal_uniform, 1, uni);
	// 	vbo.toScreen(model);

	// 	swap(use_fbo_prev, use_fbo);
	// }

	// // If we didnt end up in the rigth buffer, draw back into the normal FBO
	// if (use_fbo == &target->fbo) {
	// 	target->useFramebuffer(&target->fbo);
	// 	vbo.setTexture(use_fbo_prev->textures[0].texture);
	// 	vbo.setShader(NULL);
	// 	vbo.toScreen(model);
	// }

	// glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_BLEND);
}	
