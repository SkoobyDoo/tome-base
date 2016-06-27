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
#include "lauxlib.h"
#include "display.h"
#include "types.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "main.h"
#include "core_lua.h"
#include "math.h"
}

#include "renderer-moderngl/Renderer.hpp"
#include "spriter/Spriter.hpp"
#include "spriterengine/global/settings.h"

// Note using SpriterPlusPlus from git @ 05abe101f0c937adf8b7b154ef3746e51a8a538f

/****************************************************************************
 ** Spriter file stuff
 ****************************************************************************/
ImageFile * TE4FileFactory::newImageFile(const std::string &initialFilePath, point initialDefaultPivot, atlasdata atlasData) {
	return new TE4SpriterImageFile(spriter, initialFilePath, initialDefaultPivot, atlasData);
}

SoundFile * TE4FileFactory::newSoundFile(const std::string &initialFilePath) {
	return NULL; //new TE4SpriterSoundFile(spriter, initialFilePath);
}

SpriterFileDocumentWrapper * TE4FileFactory::newScmlDocumentWrapper() {
	return new TinyXmlSpriterFileDocumentWrapper();
}

/****************************************************************************
 ** Spriter object stuff
 ****************************************************************************/
TE4ObjectFactory::TE4ObjectFactory(DORSpriter *spriter) : spriter(spriter) {
}

PointInstanceInfo * TE4ObjectFactory::newPointInstanceInfo() {
	return new TE4PointInstanceInfo();
}

BoxInstanceInfo * TE4ObjectFactory::newBoxInstanceInfo(point size) {
	return new TE4BoxInstanceInfo(size);
}

BoneInstanceInfo * TE4ObjectFactory::newBoneInstanceInfo(point size) {
	return new TE4BoneInstanceInfo(size);
}

TriggerObjectInfo *TE4ObjectFactory::newTriggerObjectInfo(std::string triggerName) {
	return new TE4SpriterTriggerObjectInfo(spriter, triggerName);
}

/****************************************************************************
 ** Spriter event trigger stuff
 ****************************************************************************/
TE4SpriterTriggerObjectInfo::TE4SpriterTriggerObjectInfo(DORSpriter *spriter, std::string triggerName) : triggerName(triggerName), spriter(spriter) {
	printf("[SPRITER] trigger defined %s\n", triggerName.c_str());
}
void TE4SpriterTriggerObjectInfo::setTriggerCount(int newTriggerCount)
{
	TriggerObjectInfo::setTriggerCount(newTriggerCount);
	if (newTriggerCount) playTrigger();
}
void TE4SpriterTriggerObjectInfo::playTrigger() {
	if (spriter->trigger_cb_lua_ref == LUA_NOREF) return;

	lua_rawgeti(L, LUA_REGISTRYINDEX, spriter->trigger_cb_lua_ref);
	lua_pushnumber(L, getTriggerCount());
	if (lua_pcall(L, 1, 0, 0))
	{
		printf("DORSpriter trigger callback error: %s\n", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
}

/****************************************************************************
 ** Spriter image stuff
 ****************************************************************************/
TE4SpriterImageFile::TE4SpriterImageFile(DORSpriter *spriter, std::string initialFilePath, point initialDefaultPivot, atlasdata atlasData) : ImageFile(initialFilePath,initialDefaultPivot), spriter(spriter)
{	
	if (!atlasData.active) {
		makeTexture(initialFilePath, &texture, &w, &h);
		aw = w; ah = h;
	} else {
		if (!spriter->atlas_loaded) {
			float dummy;
			string png = spriter->scml;
			png.replace(png.end() - 4, png.end(), "png");
			makeTexture(png, &spriter->atlas, &dummy, &dummy);
			spriter->atlas_loaded =true;
		}
		using_atlas = true;
		texture = spriter->atlas;
		xoff = atlasData.xoff;
		yoff = atlasData.yoff;
		float ax = atlasData.x;
		float ay = atlasData.y;
		aw = atlasData.w;
		ah = atlasData.h;
		w = atlasData.ow;
		h = atlasData.oh;
		if (atlasData.rotated) {
			tx1 = ax / spriter->atlas.w;
			ty1 = ay / spriter->atlas.h;
			tx2 = (ax + ah) / spriter->atlas.w;
			ty2 = (ay + aw) / spriter->atlas.h;
		} else {
			tx1 = ax / spriter->atlas.w;
			ty1 = ay / spriter->atlas.h;
			tx2 = (ax + aw) / spriter->atlas.w;
			ty2 = (ay + ah) / spriter->atlas.h;
		}
		rotated = atlasData.rotated;
	}
}
TE4SpriterImageFile::~TE4SpriterImageFile() {	
	if (!using_atlas) glDeleteTextures(1, &texture.tex);
}

bool TE4SpriterImageFile::makeTexture(std::string file, texture_type *t, float *w, float *h) {
	SDL_Surface *s = IMG_Load_RW(PHYSFSRWOPS_openRead(file.c_str()), TRUE);
	if (!s) {
		printf("[SPRITER] texture file not found %s\n", file.c_str());
		t->tex = 0;
		return false;
	}

	glGenTextures(1, &t->tex);
	tfglBindTexture(GL_TEXTURE_2D, t->tex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

	GLint nOfColors = s->format->BytesPerPixel;
	GLenum texture_format = sdl_gl_texture_format(s);
	glTexImage2D(GL_TEXTURE_2D, 0, nOfColors, s->w, s->h, 0, texture_format, GL_UNSIGNED_BYTE, s->pixels);

	*w = t->w = s->w;
	*h = t->h = s->h;
	t->no_free = FALSE;

	SDL_FreeSurface(s);
	printf("[SPRITER] New texture %s = %d\n", file.c_str(), t->tex);
	return true;
}

void TE4SpriterImageFile::renderSprite(UniversalObjectInterface *spriteInfo) {
	spriter->quads.push_back({
		texture.tex,
		{spriteInfo->getPosition().x, spriteInfo->getPosition().y},
		{aw, ah},
		{spriteInfo->getPivot().x * w - xoff, spriteInfo->getPivot().y * h - yoff},
		{spriteInfo->getScale().x, spriteInfo->getScale().y},
		spriteInfo->getAngle(),
		{tx1, ty1, tx2, ty2},
		spriteInfo->getAlpha(),
		rotated
	});
}

/****************************************************************************
 ** Spriter sounds stuff
 ****************************************************************************/
// TE4SpriterSoundFile::TE4SpriterSoundFile(std::string initialFilePath) :	SoundFile(initialFilePath)
// {
// 	Settings::error("TE4SpriterSoundFile::initializeFile - sound unsupported yet");
// }

// SoundObjectInfoReference * TE4SpriterSoundFile::newSoundInfoReference()
// {
// 	// return new SfmlSoundObjectInfoReference(buffer);
// }

/****************************************************************************
 ** Spriter Display Object interface
 ****************************************************************************/
DORSpriter::DORSpriter() {
	shader = default_shader;
	scml = "";
}
DORSpriter::~DORSpriter() {
	if (spritermodel) delete spritermodel;
	if (instance) delete instance;
	if (atlas_loaded) glDeleteTextures(1, &atlas.tex);
}

void DORSpriter::cloneInto(DisplayObject* _into) {
	DisplayObject::cloneInto(_into);
	DORSpriter *into = dynamic_cast<DORSpriter*>(_into);
}

void DORSpriter::setTriggerCallback(int ref) {
	if (trigger_cb_lua_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, trigger_cb_lua_ref);
	trigger_cb_lua_ref = ref;
}

void DORSpriter::load(const char *file, const char *name) {
	printf("[SPRITER] Loading %s (%s)\n", file, name);
	scml = file;
	spritermodel = new SpriterModel(file, new TE4FileFactory(this), new TE4ObjectFactory(this));
	instance = spritermodel->getNewEntityInstance(name);
}

void DORSpriter::startAnim(const char *name) {
	if (!instance) return;
	instance->setCurrentAnimation(name);
}

void DORSpriter::onKeyframe(int nb_keyframe) {
	if (!instance) return;
	this->quads.clear();
	instance->setTimeElapsed(1000.0 * (float)nb_keyframe / KEYFRAMES_PER_SEC);
	instance->render();
	setChanged();
}

void DORSpriter::render(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	if (!visible || !instance) return;
	cur_model *= model;
	cur_color *= color;
	for (auto quad = quads.begin(); quad != quads.end(); quad++) {
		auto dl = getDisplayList(container, quad->texture, shader);

		// Make the matrix corresponding to the shape
		mat4 qm = mat4();
		qm = glm::translate(qm, glm::vec3(quad->pos.x, quad->pos.y, 0));
		qm = glm::rotate(qm, quad->angle, glm::vec3(0, 0, 1));
		qm = glm::scale(qm, glm::vec3(quad->scale.x, quad->scale.y, 1));
		qm = cur_model * qm;

		// Make the vertexes, un-rotated & unscaled
		vec4 color = {1, 1, 1, quad->alpha};
		float px1 = -quad->origin.x, py1 = -quad->origin.y;
		float px2 = quad->size.x-quad->origin.x, py2 = quad->size.y-quad->origin.y;
		color = cur_color * color;

		vertex p1;
		vertex p2;
		vertex p3;
		vertex p4;
		if (quad->rotated) {
			p1 = {{px1, py1, 0, 1}, {quad->tex.z, quad->tex.y}, color};
			p2 = {{px2, py1, 0, 1}, {quad->tex.z, quad->tex.w}, color};
			p3 = {{px2, py2, 0, 1}, {quad->tex.x, quad->tex.w}, color};
			p4 = {{px1, py2, 0, 1}, {quad->tex.x, quad->tex.y}, color};
		} else {
			p1 = {{px1, py1, 0, 1}, {quad->tex.x, quad->tex.y}, color};
			p2 = {{px2, py1, 0, 1}, {quad->tex.z, quad->tex.y}, color};
			p3 = {{px2, py2, 0, 1}, {quad->tex.z, quad->tex.w}, color};
			p4 = {{px1, py2, 0, 1}, {quad->tex.x, quad->tex.w}, color};
		}

		// Now apply the matrix on them
		p1.pos = qm * p1.pos;
		p2.pos = qm * p2.pos;
		p3.pos = qm * p3.pos;
		p4.pos = qm * p4.pos;

		// And we're done!
		dl->list.push_back(p1);
		dl->list.push_back(p2);
		dl->list.push_back(p3);
		dl->list.push_back(p4);
	}

	resetChanged();
}

void DORSpriter::renderZ(RendererGL *container, mat4 cur_model, vec4 cur_color) {
	if (!visible) return;
	cur_model *= model;
	cur_color *= color;

	float microz = 0;
	for (auto quad = quads.begin(); quad != quads.end(); quad++) {
		// Make the matrix corresponding to the shape
		mat4 qm = mat4();
		qm = glm::translate(qm, glm::vec3(quad->pos.x, quad->pos.y, 0));
		qm = glm::rotate(qm, quad->angle, glm::vec3(0, 0, 1));
		qm = glm::scale(qm, glm::vec3(quad->scale.x, quad->scale.y, 1));
		qm = cur_model * qm;

		// Make the vertexes, un-rotated & unscaled
		vec4 color = {1, 1, 1, quad->alpha};
		float px1 = -quad->origin.x, py1 = -quad->origin.y;
		float px2 = quad->size.x-quad->origin.x, py2 = quad->size.y-quad->origin.y;
		color = cur_color * color;

		vertex p1;
		vertex p2;
		vertex p3;
		vertex p4;
		if (quad->rotated) {
			p1 = {{px1, py1, 0, 1}, {quad->tex.z, quad->tex.y}, color};
			p2 = {{px2, py1, 0, 1}, {quad->tex.z, quad->tex.w}, color};
			p3 = {{px2, py2, 0, 1}, {quad->tex.x, quad->tex.w}, color};
			p4 = {{px1, py2, 0, 1}, {quad->tex.x, quad->tex.y}, color};
		} else {
			p1 = {{px1, py1, 0, 1}, {quad->tex.x, quad->tex.y}, color};
			p2 = {{px2, py1, 0, 1}, {quad->tex.z, quad->tex.y}, color};
			p3 = {{px2, py2, 0, 1}, {quad->tex.z, quad->tex.w}, color};
			p4 = {{px1, py2, 0, 1}, {quad->tex.x, quad->tex.w}, color};
		}

		// Now apply the matrix on them
		p1.pos = qm * p1.pos;
		p2.pos = qm * p2.pos;
		p3.pos = qm * p3.pos;
		p4.pos = qm * p4.pos;

		// And we're done!
		container->zvertices.push_back({p1, quad->texture, shader, NULL, NULL});
		container->zvertices.push_back({p2, quad->texture, shader, NULL, NULL});
		container->zvertices.push_back({p3, quad->texture, shader, NULL, NULL});
		container->zvertices.push_back({p4, quad->texture, shader, NULL, NULL});

		microz += 0.01;
	}

	resetChanged();
}

static void spriterErrorHandler(const std::string &err) {
	lua_pushstring(L, "Spriter Error: ");
	lua_pushstring(L, err.c_str());
	lua_concat(L, 2);
	lua_error(L);
}

void init_spriter() {
	Settings::setErrorFunction(spriterErrorHandler);
}
