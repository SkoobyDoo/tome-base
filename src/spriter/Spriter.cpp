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
#include "lauxlib.h"
#include "display.h"
#include "types.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "main.h"
#include "math.h"
}

#include "core_lua.hpp"
#include "displayobjects/Renderer.hpp"
#include "spriter/Spriter.hpp"
#include "spriterengine/global/settings.h"

// Note using SpriterPlusPlus from git @ 05abe101f0c937adf8b7b154ef3746e51a8a538f

/****************************************************************************
 ** Spriter file stuff
 ****************************************************************************/
ImageFile * TE4FileFactory::newImageFile(const std::string &initialFilePath, point initialDefaultPivot, atlasdata atlasData) {
	return new TE4SpriterImageFile(initialFilePath, initialDefaultPivot, atlasData);
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
TE4ObjectFactory::TE4ObjectFactory() {
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
	return new TE4SpriterTriggerObjectInfo(triggerName);
}

/****************************************************************************
 ** Spriter event trigger stuff
 ****************************************************************************/
TE4SpriterTriggerObjectInfo::TE4SpriterTriggerObjectInfo(std::string triggerName) : triggerName(triggerName) {
	// printf("[SPRITER] trigger defined %s\n", triggerName.c_str());
}
void TE4SpriterTriggerObjectInfo::setTriggerCount(int newTriggerCount)
{
	TriggerObjectInfo::setTriggerCount(newTriggerCount);
	if (newTriggerCount) playTrigger();
}
void TE4SpriterTriggerObjectInfo::playTrigger() {
	DORSpriter *spriter = DORSpriter::currently_processing;
	if (spriter->trigger_cb_lua_ref == LUA_NOREF) return;

	lua_rawgeti(L, LUA_REGISTRYINDEX, DisplayObject::weak_registry_ref);
	lua_rawgeti(L, LUA_REGISTRYINDEX, spriter->trigger_cb_lua_ref);
	lua_rawgeti(L, -2, spriter->getWeakSelfRef());
	lua_pushstring(L, triggerName.c_str());
	lua_pushnumber(L, getTriggerCount());
	if (lua_pcall(L, 3, 0, 0))
	{
		printf("DORSpriter trigger callback error: %s\n", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
	lua_pop(L, 1); // weak registery
}

/****************************************************************************
 ** Spriter image stuff
 ****************************************************************************/
TE4SpriterImageFile::TE4SpriterImageFile(std::string initialFilePath, point initialDefaultPivot, atlasdata atlasData) : ImageFile(initialFilePath,initialDefaultPivot) {	
	size_t pos = initialFilePath.find_last_of('/');
	size_t epos = initialFilePath.find_last_of('.');
	id = initialFilePath.substr(pos+1, epos-pos-1);

	if (!atlasData.active) {		
		texture = DORSpriterCache::getTexture(initialFilePath);
		aw = w = texture->tex.w; ah = h = texture->tex.h;
	} else {
		string png = DORSpriter::currently_processing->scml;
		png.replace(png.end() - 4, png.end(), "png");
		texture = DORSpriterCache::getTexture(png);

		xoff = atlasData.xoff;
		yoff = atlasData.yoff;
		float ax = atlasData.x;
		float ay = atlasData.y;
		aw = atlasData.w;
		ah = atlasData.h;
		w = atlasData.ow;
		h = atlasData.oh;
		if (atlasData.rotated) {
			tx1 = ax / texture->tex.w;
			ty1 = ay / texture->tex.h;
			tx2 = (ax + ah) / texture->tex.w;
			ty2 = (ay + aw) / texture->tex.h;
		} else {
			tx1 = ax / texture->tex.w;
			ty1 = ay / texture->tex.h;
			tx2 = (ax + aw) / texture->tex.w;
			ty2 = (ay + ah) / texture->tex.h;
		}
		rotated = atlasData.rotated;
	}
}
TE4SpriterImageFile::~TE4SpriterImageFile() {	
	DORSpriterCache::releaseTexture(texture);
}

void TE4SpriterImageFile::renderSprite(UniversalObjectInterface *spriteInfo) {
	DORSpriter *spriter = DORSpriter::currently_processing;

	if (!spriter->render_z) {
		auto dl = getDisplayList(spriter->render_container, {texture->tex.tex, 0, 0}, spriter->shader, VERTEX_BASE, RenderKind::QUADS);

		// Make the matrix corresponding to the shape
		mat4 qm = mat4();
		qm = glm::translate(qm, glm::vec3((float)spriteInfo->getPosition().x, (float)spriteInfo->getPosition().y, 0));
		qm = glm::rotate(qm, (float)spriteInfo->getAngle(), glm::vec3(0, 0, 1));
		qm = glm::scale(qm, glm::vec3((float)spriteInfo->getScale().x, (float)spriteInfo->getScale().y, 1));
		qm = spriter->render_model * qm;

		// Make the vertexes, un-rotated & unscaled
		vec2 origin = {spriteInfo->getPivot().x * w - xoff, spriteInfo->getPivot().y * h - yoff};
		vec4 color = {1, 1, 1, spriteInfo->getAlpha()};
		float px1 = -origin.x, py1 = -origin.y;
		float px2 = aw-origin.x, py2 = ah-origin.y;
		color = spriter->render_color * color;

		vertex p1;
		vertex p2;
		vertex p3;
		vertex p4;
		if (rotated) {
			p1 = {{px1, py1, 0, 1}, {tx2, ty1}, color};
			p2 = {{px2, py1, 0, 1}, {tx2, ty2}, color};
			p3 = {{px2, py2, 0, 1}, {tx1, ty2}, color};
			p4 = {{px1, py2, 0, 1}, {tx1, ty1}, color};
		} else {
			p1 = {{px1, py1, 0, 1}, {tx1, ty1}, color};
			p2 = {{px2, py1, 0, 1}, {tx2, ty1}, color};
			p3 = {{px2, py2, 0, 1}, {tx2, ty2}, color};
			p4 = {{px1, py2, 0, 1}, {tx1, ty2}, color};
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
	} else {
		// // Make the matrix corresponding to the shape
		// mat4 qm = mat4();
		// qm = glm::translate(qm, glm::vec3((float)spriteInfo->getPosition().x, (float)spriteInfo->getPosition().y, 0));
		// qm = glm::rotate(qm, (float)spriteInfo->getAngle(), glm::vec3(0, 0, 1));
		// qm = glm::scale(qm, glm::vec3((float)spriteInfo->getScale().x, (float)spriteInfo->getScale().y, 1));
		// qm = spriter->render_model * qm;

		// // Make the vertexes, un-rotated & unscaled
		// vec2 origin = {spriteInfo->getPivot().x * w - xoff, spriteInfo->getPivot().y * h - yoff};
		// vec4 color = {1, 1, 1, spriteInfo->getAlpha()};
		// float px1 = -origin.x, py1 = -origin.y;
		// float px2 = aw-origin.x, py2 = ah-origin.y;
		// color = spriter->render_color * color;

		// vertex p1;
		// vertex p2;
		// vertex p3;
		// vertex p4;
		// if (rotated) {
		// 	p1 = {{px1, py1, spriter->render_microz, 1}, {tx2, ty1}, color};
		// 	p2 = {{px2, py1, spriter->render_microz, 1}, {tx2, ty2}, color};
		// 	p3 = {{px2, py2, spriter->render_microz, 1}, {tx1, ty2}, color};
		// 	p4 = {{px1, py2, spriter->render_microz, 1}, {tx1, ty1}, color};
		// } else {
		// 	p1 = {{px1, py1, spriter->render_microz, 1}, {tx1, ty1}, color};
		// 	p2 = {{px2, py1, spriter->render_microz, 1}, {tx2, ty1}, color};
		// 	p3 = {{px2, py2, spriter->render_microz, 1}, {tx2, ty2}, color};
		// 	p4 = {{px1, py2, spriter->render_microz, 1}, {tx1, ty2}, color};
		// }

		// // Now apply the matrix on them
		// p1.pos = qm * p1.pos;
		// p2.pos = qm * p2.pos;
		// p3.pos = qm * p3.pos;
		// p4.pos = qm * p4.pos;

		// // And we're done!
		// spriter->render_container->zvertices.push_back({p1, {texture->tex.tex, 0, 0}, spriter->shader, NULL, NULL});
		// spriter->render_container->zvertices.push_back({p2, {texture->tex.tex, 0, 0}, spriter->shader, NULL, NULL});
		// spriter->render_container->zvertices.push_back({p3, {texture->tex.tex, 0, 0}, spriter->shader, NULL, NULL});
		// spriter->render_container->zvertices.push_back({p4, {texture->tex.tex, 0, 0}, spriter->shader, NULL, NULL});

		// spriter->render_microz += 0.01;
	}
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
DORSpriter *DORSpriter::currently_processing = NULL;

DORSpriter::DORSpriter() {
	shader = default_shader;
	scml = "";
}
DORSpriter::~DORSpriter() {
	if (spritermodel) DORSpriterCache::releaseModel(spritermodel);
	if (instance) delete instance;
}

void DORSpriter::cloneInto(DisplayObject* _into) {
	DisplayObject::cloneInto(_into);
	DORSpriter *into = dynamic_cast<DORSpriter*>(_into);
	// DGDGDGDG: finish me
}

void DORSpriter::setTriggerCallback(int ref) {
	refcleaner(&trigger_cb_lua_ref);
	trigger_cb_lua_ref = ref;
}

void DORSpriter::load(const char *file, const char *name) {
	currently_processing = this;
	scml = file;
	spritermodel = DORSpriterCache::getModel(file);
	instance = spritermodel->getNewEntityInstance(name);
}

void DORSpriter::applyCharacterMap(const char *name) {
	instance->applyCharacterMap(name);
}

void DORSpriter::removeCharacterMap(const char *name) {
	instance->removeCharacterMap(name);
}

vec2 DORSpriter::getObjectPosition(const char *name) {
	UniversalObjectInterface *so = instance->getObjectInstance(name);
	if (so) {
		float x = so->getPosition().x * scale_x, y = so->getPosition().y * scale_y;
		float c = cos(rot_z);
		float s = sin(rot_z);
		float xnew = x * c - y * s;
		float ynew = x * s + y * c;
		return {xnew, ynew};
	}
	return {0, 0};
}

void DORSpriter::startAnim(const char *name, float blendtime, float speed) {
	if (!instance) return;
	currently_processing = this;
	if (speed) instance->setPlaybackSpeedRatio(speed);
	else instance->setPlaybackSpeedRatio(1);
	if (blendtime) instance->setCurrentAnimation(name, blendtime * 1000.0);
	else instance->setCurrentAnimation(name);
}

void DORSpriter::onKeyframe(float nb_keyframe) {
	if (!instance) return;
	currently_processing = this;
	instance->setTimeElapsed(1000.0 * nb_keyframe / KEYFRAMES_PER_SEC);
	setChanged();

	if (instance->animationJustFinished(true)) {
		lua_rawgeti(L, LUA_REGISTRYINDEX, DisplayObject::weak_registry_ref);
		lua_rawgeti(L, LUA_REGISTRYINDEX, trigger_cb_lua_ref);
		lua_rawgeti(L, -2, getWeakSelfRef());
		lua_pushliteral(L, "animStop");
		lua_pushstring(L, instance->currentAnimationName().c_str());
		if (lua_pcall(L, 3, 0, 0))
		{
			printf("DORSpriter trigger callback error: %s\n", lua_tostring(L, -1));
			lua_pop(L, 1);
		}
		lua_pop(L, 1); // weak registery
	}
}

void DORSpriter::render(RendererGL *container, mat4& cur_model, vec4& cur_color, bool cur_visible) {
	if (!visible || !cur_visible || !instance) return;
	currently_processing = this;
	render_z = false;
	render_model = cur_model * model;
	render_color = cur_color * color;
	render_container = container;
	instance->render();
	resetChanged();
}

// void DORSpriter::renderZ(RendererGL *container, mat4& cur_model, vec4& cur_color, bool cur_visible) {
// 	if (!visible || !cur_visible || !instance) return;
// 	currently_processing = this;
// 	render_z = true;
// 	render_model = cur_model * model;
// 	render_color = cur_color * color;
// 	render_container = container; render_microz = 0;
// 	instance->render();
// 	resetChanged();
// }

void DORSpriter::sortZ(RendererGL *container, mat4& cur_model) {
	mat4 vmodel = cur_model * model;

	// We take a "virtual" point at 0 coordinates
	vec4 virtualz = vmodel * vec4(0, 0, 0, 1);
	sort_z = virtualz.z;
	sort_shader = shader;
	sort_tex = {99999,0,0}; // DGDGDGDG UGH we need a wayto find the actual texture
	container->sorted_dos.push_back(this);
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
