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
#ifndef TE4SPRITER_H
#define TE4SPRITER_H

#include <string.h>

#include "renderer-moderngl/Renderer.hpp"
#include "spriterengine/spriterengine.h"
#include "spriter/tinyxmlspriterfiledocumentwrapper.h"
#include "spriterengine/override/filefactory.h"
#include "spriterengine/override/objectfactory.h"
#include "spriterengine/override/imagefile.h"
#include "spriterengine/override/soundfile.h"
#include "spriterengine/objectinfo/boneinstanceinfo.h"
#include "spriterengine/objectinfo/boxinstanceinfo.h"
#include "spriterengine/objectinfo/pointinstanceinfo.h"
#include "spriterengine/objectinfo/triggerobjectinfo.h"

using namespace SpriterEngine;

class DORSpriter;

class TE4FileFactory : public FileFactory
{
private:
	DORSpriter *spriter = NULL;
public:
	TE4FileFactory(DORSpriter *spriter) : spriter(spriter) {};
	ImageFile *newImageFile(const std::string &initialFilePath, point initialDefaultPivot, atlasdata atlasData) override;
	SoundFile *newSoundFile(const std::string &initialFilePath) override;
	SpriterFileDocumentWrapper *newScmlDocumentWrapper() override;
};

class TE4BoneInstanceInfo : public BoneInstanceInfo
{
public:
	TE4BoneInstanceInfo(point initialSize) : BoneInstanceInfo(initialSize) {};
	void render() override {};
};
class TE4PointInstanceInfo : public PointInstanceInfo
{
public:
	TE4PointInstanceInfo() : PointInstanceInfo() {};
	void render() override {};
};
class TE4BoxInstanceInfo : public BoxInstanceInfo
{
public:
	TE4BoxInstanceInfo(point initialSize) : BoxInstanceInfo(initialSize) {};
	void render() override {};
};

class TE4ObjectFactory : public ObjectFactory
{
private:
	DORSpriter *spriter = NULL;
public:
	TE4ObjectFactory(DORSpriter *spriter);
	PointInstanceInfo *newPointInstanceInfo() override;
	BoxInstanceInfo *newBoxInstanceInfo(point size) override;
	BoneInstanceInfo *newBoneInstanceInfo(point size) override;
	TriggerObjectInfo *newTriggerObjectInfo(std::string triggerName) override;
};

class TE4SpriterTriggerObjectInfo : public TriggerObjectInfo {
private:
	std::string triggerName;
	DORSpriter *spriter = NULL;
public:
	TE4SpriterTriggerObjectInfo(DORSpriter *spriter, std::string triggerName);
	void setTriggerCount(int newTriggerCount) override;
	virtual void playTrigger() override;
};

class TE4SpriterImageFile : public ImageFile
{
private:
	DORSpriter *spriter = NULL;
	bool using_atlas = false;
	texture_type texture;
	float w = 1, h = 1, aw = 1, ah = 1, tx1 = 0, ty1 = 0, tx2 = 1, ty2 = 1, xoff = 0, yoff = 0;
	bool rotated = false;

	bool makeTexture(std::string file, texture_type *t, float *w, float *h);

public:
	TE4SpriterImageFile(DORSpriter *spriter, std::string initialFilePath, point initialDefaultPivot, atlasdata atlasData);
	virtual ~TE4SpriterImageFile();

	void renderSprite(UniversalObjectInterface *spriteInfo) override;
};

class TE4SpriterSoundFile : public SoundFile
{
public:
	TE4SpriterSoundFile(std::string initialFilePath);
	virtual ~TE4SpriterSoundFile();

	SoundObjectInfoReference * newSoundInfoReference();
};

typedef struct {
	GLuint texture;
	vec2 pos;
	vec2 size;
	vec2 origin;
	vec2 scale;
	float angle;
	vec4 tex;
	float alpha;
	bool rotated;
} spriter_quads;

class DORSpriter : public DisplayObject, public DORRealtime{
	friend class TE4SpriterImageFile; friend class TE4SpriterTriggerObjectInfo;
private:
	virtual void cloneInto(DisplayObject *into);

protected:
	texture_type atlas;
	bool atlas_loaded = false;
	SpriterModel *spritermodel = NULL;
	EntityInstance *instance = NULL;

	vector<spriter_quads> quads;
	shader_type *shader;
	string scml;

	int trigger_cb_lua_ref = LUA_NOREF;

public:
	DORSpriter();
	virtual ~DORSpriter();
	DO_STANDARD_CLONE_METHOD(DORSpriter);
	virtual const char* getKind() { return "DORSpriter"; };

	void setTriggerCallback(int ref);

	void load(const char *file, const char *name);
	void startAnim(const char *name);

	void setShader(shader_type *s) { shader = s; };
	virtual void render(RendererGL *container, mat4 cur_model, vec4 color);
	virtual void renderZ(RendererGL *container, mat4 cur_model, vec4 color);

	virtual void onKeyframe(int nb_keyframes);
};

extern void init_spriter();

#endif
