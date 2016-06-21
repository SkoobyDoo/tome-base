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
}

#include "renderer-moderngl/Renderer.hpp"
#include "spriter/Spriter.hpp"
#include "spriterengine/global/settings.h"

/****************************************************************************
 ** Spriter file stuff
 ****************************************************************************/
ImageFile * TE4FileFactory::newImageFile(const std::string &initialFilePath, point initialDefaultPivot) {
	return new TE4SpriterImageFile(initialFilePath, initialDefaultPivot);
}

SoundFile * TE4FileFactory::newSoundFile(const std::string &initialFilePath) {
	return NULL; //new TE4SpriterSoundFile(initialFilePath);
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

/****************************************************************************
 ** Spriter image stuff
 ****************************************************************************/
TE4SpriterImageFile::TE4SpriterImageFile(std::string initialFilePath, point initialDefaultPivot) : ImageFile(initialFilePath,initialDefaultPivot)
{	
	SDL_Surface *s = IMG_Load_RW(PHYSFSRWOPS_openRead(initialFilePath.c_str()), TRUE);
	if (!s) {
		printf("[SPRITER] texture file not found %s\n", initialFilePath.c_str());
		texture.tex = 0;
	}

	glGenTextures(1, &texture.tex);
	tfglBindTexture(GL_TEXTURE_2D, texture.tex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

	GLint nOfColors = s->format->BytesPerPixel;
	GLenum texture_format = sdl_gl_texture_format(s);
	glTexImage2D(GL_TEXTURE_2D, 0, nOfColors, s->w, s->h, 0, texture_format, GL_UNSIGNED_BYTE, s->pixels);

	w = texture.w = s->w;
	h = texture.h = s->h;
	texture.no_free = FALSE;

	SDL_FreeSurface(s);

	printf("[SPRITER] New texture %s = %d\n", initialFilePath.c_str(), texture.tex);
}
TE4SpriterImageFile::~TE4SpriterImageFile() {	
	glDeleteTextures(1, &texture.tex);
}

static DORSpriter *renderInto = NULL;
void TE4SpriterImageFile::renderSprite(UniversalObjectInterface *spriteInfo) {
	if (!renderInto) return;

	// sprite.setColor(sf::Color(255, 255, 255, 255 * spriteInfo->getAlpha()));
	// sprite.setPosition(spriteInfo->getPosition().x, spriteInfo->getPosition().y);
	// sprite.setRotation(toDegrees(spriteInfo->getAngle()));
	// sprite.setScale(spriteInfo->getScale().x, spriteInfo->getScale().y);
	// sprite.setOrigin(spriteInfo->getPivot().x*texture.getSize().x, spriteInfo->getPivot().y*texture.getSize().y);
	// renderWindow->draw(sprite);
	
	renderInto->quads.push_back({
		texture.tex,
		{spriteInfo->getPosition().x, spriteInfo->getPosition().y},
		{w, h},
		{spriteInfo->getPivot().x * w, spriteInfo->getPivot().y * h},
		{spriteInfo->getScale().x, spriteInfo->getScale().y},
		spriteInfo->getAngle(),
		{0, 0, 1, 1}, // DGDGDGDG support atlases !!!
		spriteInfo->getAlpha()
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
}
DORSpriter::~DORSpriter() {
	if (spritermodel) delete spritermodel;
	if (instance) delete instance;
}

void DORSpriter::cloneInto(DisplayObject* _into) {
	DisplayObject::cloneInto(_into);
	DORSpriter *into = dynamic_cast<DORSpriter*>(_into);
}

void DORSpriter::load(const char *file, const char *name) {
	spritermodel = new SpriterModel(file, new TE4FileFactory(), new TE4ObjectFactory());
	instance = spritermodel->getNewEntityInstance(name);
	instance->setCurrentAnimation("walk");
}

void DORSpriter::onKeyframe(int nb_keyframe) {
	instance->setTimeElapsed(1000.0 * (float)nb_keyframe / KEYFRAMES_PER_SEC);

	renderInto = this;
	this->quads.clear();
	instance->render();
	renderInto = NULL;
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
		vertex p1 = {{px1, py1, 0, 1}, {quad->tex.x, quad->tex.y}, color};
		vertex p2 = {{px2, py1, 0, 1}, {quad->tex.z, quad->tex.y}, color};
		vertex p3 = {{px2, py2, 0, 1}, {quad->tex.z, quad->tex.w}, color};
		vertex p4 = {{px1, py2, 0, 1}, {quad->tex.x, quad->tex.w}, color};

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
		vertex p1 = {{px1, py1, microz, 1}, {quad->tex.x, quad->tex.y}, color};
		vertex p2 = {{px2, py1, microz, 1}, {quad->tex.z, quad->tex.y}, color};
		vertex p3 = {{px2, py2, microz, 1}, {quad->tex.z, quad->tex.w}, color};
		vertex p4 = {{px1, py2, microz, 1}, {quad->tex.x, quad->tex.w}, color};

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
