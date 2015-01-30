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
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "types.h"
#include "script.h"
#include "main.h"
#include "core_lua.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "spine.h"

extern GLenum sdl_gl_texture_format(SDL_Surface *s);

#ifndef SPINE_MESH_VERTEX_COUNT_MAX
#define SPINE_MESH_VERTEX_COUNT_MAX 1000
#endif

void _spAtlasPage_createTexture(AtlasPage* self, const char* path){
	GLuint *t = malloc(sizeof(GLuint));
	glGenTextures(1, t);
	tfglBindTexture(GL_TEXTURE_2D, *t);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, (self->minFilter == SP_ATLAS_NEAREST) ? GL_NEAREST : GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, (self->magFilter == SP_ATLAS_NEAREST) ? GL_NEAREST : GL_LINEAR);

	SDL_Surface *s = IMG_Load_RW(PHYSFSRWOPS_openRead(path), TRUE);

	self->rendererObject = t;
	self->width = s->w;
	self->height = s->h;

	GLint nOfColors = s->format->BytesPerPixel;
	GLenum texture_format = sdl_gl_texture_format(s);
	glTexImage2D(GL_TEXTURE_2D, 0, nOfColors, s->w, s->h, 0, texture_format, GL_UNSIGNED_BYTE, s->pixels);
	if (s->flags & SDL_PREALLOC) free(s->pixels);
	SDL_FreeSurface(s);
}

void _spAtlasPage_disposeTexture(AtlasPage* self){
	glDeleteTextures(1, self->rendererObject);
	free(self->rendererObject);
}

char* _spUtil_readFile(const char* path, int* length){
	PHYSFS_File *f = PHYSFS_openRead(path);
	*length = PHYSFS_fileLength(f);
	char *data = malloc(*length);
	PHYSFS_read(f, data, (PHYSFS_uint32)*length, 1);
	PHYSFS_close(f);
	return data;
}

static int spine_new_data(lua_State *L)
{
	const char *path = lua_tostring(L, 1);
	float scale = luaL_checknumber(L, 2);

	int baselen = strlen(path);
	char *rpath = calloc(baselen+1+6, sizeof(char));

	spine_data_type *sd = (spine_data_type*)lua_newuserdata(L, sizeof(spine_data_type));
	auxiliar_setclass(L, "display{spine-data}", -1);

	// Load atlas, skeleton, and animations.
	strcpy(rpath, path); strcat(rpath+baselen, ".atlas");
	if (!PHYSFS_exists(rpath)) { lua_pushstring(L, "Spine Atlas file not found: "); lua_pushstring(L, rpath); lua_concat(L, 2); lua_error(L); return 1; }
	Atlas* atlas = Atlas_createFromFile(rpath, 0);
	SkeletonJson* json = SkeletonJson_create(atlas);
	json->scale = scale;
	strcpy(rpath, path); strcat(rpath+baselen, ".json");
	if (!PHYSFS_exists(rpath)) { lua_pushstring(L, "Spine Json file not found: "); lua_pushstring(L, rpath); lua_concat(L, 2); lua_error(L); return 1; }
	SkeletonData *skeletonData = SkeletonJson_readSkeletonDataFile(json, rpath);
	if (!skeletonData) { lua_pushstring(L, json->error); lua_error(L); return 1; }
	SkeletonJson_dispose(json);
	SkeletonBounds* bounds = SkeletonBounds_create();

	AnimationStateData* stateData = AnimationStateData_create(skeletonData);

	sd->skeleton_data = skeletonData;
	sd->state_data = stateData;
	printf("[SPINE] New spine data for %s\n", path);

	return 1;
}

static int spine_data_free(lua_State *L)
{
	spine_data_type *sd = (spine_data_type*)auxiliar_checkclass(L, "display{spine-data}", 1);
	AnimationStateData_dispose(sd->state_data);
	SkeletonData_dispose(sd->skeleton_data);
	lua_pushnumber(L, 1);
	return 1;
}

static int spine_animmix(lua_State *L)
{
	spine_data_type *sd = (spine_data_type*)auxiliar_checkclass(L, "display{spine-data}", 1);
	const char *anim1 = luaL_checkstring(L, 2);
	const char *anim2 = luaL_checkstring(L, 3);
	float secs = lua_tonumber(L, 4);

	AnimationStateData_setMixByName(sd->state_data, anim1, anim2, secs);
	return 0;
}

static int spine_new(lua_State *L)
{
	spine_data_type *sd = (spine_data_type*)auxiliar_checkclass(L, "display{spine-data}", 1);

	spine_type *s = (spine_type*)lua_newuserdata(L, sizeof(spine_type));
	auxiliar_setclass(L, "display{spine}", -1);

	Skeleton *skeleton = Skeleton_create(sd->skeleton_data);
	s->skeleton = skeleton;
	s->skeleton->flipY = TRUE;

	s->state = AnimationState_create(sd->state_data);
	s->state->udata = s;

	s->cb_to_execute = NULL;
	s->rotation = 0;
	s->timeScale = 1.0;
	s->worldVertices = calloc(SPINE_MESH_VERTEX_COUNT_MAX, sizeof(float));

	int i, nb_vertices = 0;
	for (i = 0; i < skeleton->slotsCount; ++i) {
		Slot* slot = skeleton->drawOrder[i];
		Attachment* attachment = slot->attachment;
		if (!attachment) { continue; }
		if (attachment->type == ATTACHMENT_REGION) {
			nb_vertices += 6;
		} else if (attachment->type == ATTACHMENT_MESH) {
			MeshAttachment* mesh = (MeshAttachment*)attachment;
			if (mesh->verticesCount > SPINE_MESH_VERTEX_COUNT_MAX) { continue; }
			nb_vertices += mesh->trianglesCount;
		} else if (attachment->type == ATTACHMENT_SKINNED_MESH) {
			SkinnedMeshAttachment* mesh = (SkinnedMeshAttachment*)attachment;
			if (mesh->uvsCount > SPINE_MESH_VERTEX_COUNT_MAX) { continue; }
			nb_vertices += mesh->trianglesCount;
		}
	}

	printf("[SPINE] New spine spawn with %d vertices\n", nb_vertices);
	s->vertices = malloc(sizeof(GLfloat) * nb_vertices * 2);
	s->colors = malloc(sizeof(GLfloat) * nb_vertices * 4);
	s->texcoords = malloc(sizeof(GLfloat) * nb_vertices * 2);

	lua_pushvalue(L, 1);
	s->data_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	s->cb_ref = LUA_NOREF;
	s->cb_to_execute = NULL;

	return 1;
}

static int spine_free(lua_State *L)
{
	spine_type *s = (spine_type*)auxiliar_checkclass(L, "display{spine}", 1);
	AnimationState_dispose(s->state);
	Skeleton_dispose(s->skeleton);
	free(s->worldVertices);
	if (s->cb_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, s->cb_ref);
	luaL_unref(L, LUA_REGISTRYINDEX, s->data_ref);
	lua_pushnumber(L, 1);
	return 1;
}

static void spine_add_event(spine_type *s, const char *anim, const char *event, const char *what, int n1, float n2) {
	spine_events_list *e = malloc(sizeof(spine_events_list));
	spine_events_list *next = s->cb_to_execute;

	e->anim = anim;
	e->event = event;
	e->what = what;
	e->n1 = n1;
	e->n2 = n2;
	e->next = NULL;

	if (!next) s->cb_to_execute = e;
	else {
		while (next->next) next = next->next;
		next->next = e;
	}
}

static void spine_callback(AnimationState* state, int trackIndex, EventType type, Event* event, int loopCount) {
	TrackEntry* entry = AnimationState_getCurrent(state, trackIndex);
	const char* animationName = (entry && entry->animation) ? entry->animation->name : 0;
	spine_type *s = (spine_type*)state->udata;

	switch (type) {
	case ANIMATION_START:
		spine_add_event(s, animationName, "state", "start", 0, 0);
		break;
	case ANIMATION_END:
		spine_add_event(s, animationName, "state", "end", 0, 0);
		break;
	case ANIMATION_COMPLETE:
		spine_add_event(s, animationName, "state", "complete", 0, 0);
		break;
	case ANIMATION_EVENT:
		spine_add_event(s, animationName, event->data->name, event->stringValue, event->intValue, event->floatValue);
		break;
	}
}

static int spine_cb(lua_State *L)
{
	spine_type *s = (spine_type*)auxiliar_checkclass(L, "display{spine}", 1);
	if (s->cb_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, s->cb_ref);
	if (lua_isfunction(L, 2)) {
		s->cb_ref = luaL_ref(L, LUA_REGISTRYINDEX);
		s->state->listener = spine_callback;
	} else {
		s->cb_ref = LUA_NOREF;
		s->state->listener = NULL;
	}
	return 0;
}

static int spine_rotation(lua_State *L)
{
	spine_type *s = (spine_type*)auxiliar_checkclass(L, "display{spine}", 1);
	s->rotation = lua_tonumber(L, 2);
	return 0;
}

static int spine_setanim(lua_State *L)
{
	spine_type *s = (spine_type*)auxiliar_checkclass(L, "display{spine}", 1);
	const char *anim = luaL_checkstring(L, 2);
	bool loop = lua_toboolean(L, 3);

	AnimationState_setAnimationByName(s->state, 0, anim, loop);
	return 0;
}

static int spine_addanim(lua_State *L)
{
	spine_type *s = (spine_type*)auxiliar_checkclass(L, "display{spine}", 1);
	const char *anim = luaL_checkstring(L, 2);
	bool loop = lua_toboolean(L, 3);
	float secs = lua_tonumber(L, 4);

	AnimationState_addAnimationByName(s->state, 0, anim, loop, secs);
	return 0;
}

#define addVertex(x, y, u, v) { \
	s->colors[c_idx++] = (r); s->colors[c_idx++] = (g); s->colors[c_idx++] = (b); s->colors[c_idx++] = (a); \
	s->vertices[v_idx++] = (x); s->vertices[v_idx++] = (y); \
	s->texcoords[t_idx++] = (u); s->texcoords[t_idx++] = (v); \
}

void spine_draw(lua_State *L, spine_type *s, float bx, float by, float nb_keyframes) {
	Skeleton* skeleton = s->skeleton;
	AnimationState* state = s->state;
	float* worldVertices = s->worldVertices;

	if (nb_keyframes) {
		Skeleton_update(skeleton, (float)nb_keyframes / 30);
		AnimationState_update(state, (float)nb_keyframes / 30 * s->timeScale);
		AnimationState_apply(state, skeleton);
		Skeleton_updateWorldTransform(skeleton);
	}

	glTexCoordPointer(2, GL_FLOAT, 0, s->texcoords);
	glVertexPointer(2, GL_FLOAT, 0, s->vertices);
	glColorPointer(4, GL_FLOAT, 0, s->colors);	

	bool additiveBlend = TRUE;
	GLuint texture;
	int i;
	int v_idx = 0, c_idx = 0, t_idx = 0;
	for (i = 0; i < skeleton->slotsCount; ++i) {
		Slot* slot = skeleton->drawOrder[i];
		Attachment* attachment = slot->attachment;
		if (!attachment) { continue; }
		if (attachment->type == ATTACHMENT_REGION) {
			RegionAttachment* regionAttachment = (RegionAttachment*)attachment;
			texture = *(GLuint*)((AtlasRegion*)regionAttachment->rendererObject)->page->rendererObject;
			RegionAttachment_computeWorldVertices(regionAttachment, slot->bone, worldVertices);

			float r = skeleton->r * slot->r;
			float g = skeleton->g * slot->g;
			float b = skeleton->b * slot->b;
			float a = skeleton->a * slot->a;

			addVertex(worldVertices[VERTEX_X1], worldVertices[VERTEX_Y1], regionAttachment->uvs[VERTEX_X1], regionAttachment->uvs[VERTEX_Y1]);
			addVertex(worldVertices[VERTEX_X2], worldVertices[VERTEX_Y2], regionAttachment->uvs[VERTEX_X2], regionAttachment->uvs[VERTEX_Y2]);
			addVertex(worldVertices[VERTEX_X3], worldVertices[VERTEX_Y3], regionAttachment->uvs[VERTEX_X3], regionAttachment->uvs[VERTEX_Y3]);

			addVertex(worldVertices[VERTEX_X1], worldVertices[VERTEX_Y1], regionAttachment->uvs[VERTEX_X1], regionAttachment->uvs[VERTEX_Y1]);
			addVertex(worldVertices[VERTEX_X3], worldVertices[VERTEX_Y3], regionAttachment->uvs[VERTEX_X3], regionAttachment->uvs[VERTEX_Y3]);
			addVertex(worldVertices[VERTEX_X4], worldVertices[VERTEX_Y4], regionAttachment->uvs[VERTEX_X4], regionAttachment->uvs[VERTEX_Y4]);

		} else if (attachment->type == ATTACHMENT_MESH) {
			MeshAttachment* mesh = (MeshAttachment*)attachment;
			if (mesh->verticesCount > SPINE_MESH_VERTEX_COUNT_MAX) { continue; }
			texture = *(GLuint*)((AtlasRegion*)mesh->rendererObject)->page->rendererObject;
			MeshAttachment_computeWorldVertices(mesh, slot, worldVertices);

			float r = skeleton->r * slot->r;
			float g = skeleton->g * slot->g;
			float b = skeleton->b * slot->b;
			float a = skeleton->a * slot->a;
			for (i = 0; i < mesh->trianglesCount; ++i) {
				int index = mesh->triangles[i] << 1;
				addVertex(worldVertices[index], worldVertices[index + 1], mesh->uvs[index], mesh->uvs[index + 1])
			}

		} else if (attachment->type == ATTACHMENT_SKINNED_MESH) {
			SkinnedMeshAttachment* mesh = (SkinnedMeshAttachment*)attachment;
			if (mesh->uvsCount > SPINE_MESH_VERTEX_COUNT_MAX) { continue; }
			texture = *(GLuint*)((AtlasRegion*)mesh->rendererObject)->page->rendererObject;
			SkinnedMeshAttachment_computeWorldVertices(mesh, slot, worldVertices);

			float r = skeleton->r * slot->r;
			float g = skeleton->g * slot->g;
			float b = skeleton->b * slot->b;
			float a = skeleton->a * slot->a;
			for (i = 0; i < mesh->trianglesCount; ++i) {
				int index = mesh->triangles[i] << 1;
				addVertex(worldVertices[index], worldVertices[index + 1], mesh->uvs[index], mesh->uvs[index + 1])
			}
		}

		// if (texture) {
		// 	// if (additiveBlend == slot->data->additiveBlending) {
		// 		if (v_idx) glDrawArrays(GL_TRIANGLES, 0, v_idx / 2);
		// 		v_idx = c_idx = t_idx = 0;
		// 	// }
		// }
	}
	if (v_idx) {
		tfglBindTexture(GL_TEXTURE_2D, texture);
		glTranslatef(bx, by, 0);
		glRotatef(s->rotation, 0, 0, 1);
		glDrawArrays(GL_TRIANGLES, 0, v_idx / 2);
		glRotatef(-s->rotation, 0, 0, 1);
		glTranslatef(-bx, -by, 0);
	}

	// Empty events if any
	if (L) {
		while (s->cb_to_execute) {
			lua_rawgeti(L, LUA_REGISTRYINDEX, s->cb_ref);
			lua_pushstring(L, s->cb_to_execute->anim);
			lua_pushstring(L, s->cb_to_execute->event);
			lua_pushstring(L, s->cb_to_execute->what);
			lua_pushnumber(L, s->cb_to_execute->n1);
			lua_pushnumber(L, s->cb_to_execute->n2);
			if (lua_pcall(L, 5, 0, 0)) { printf("Spine event callback error: %s\n", lua_tostring(L, -1)); lua_pop(L, 1); }

			s->cb_to_execute = s->cb_to_execute->next;
		}
	}
}

static int spine_toscreen(lua_State *L)
{
	spine_type *s = (spine_type*)auxiliar_checkclass(L, "display{spine}", 1);
	float bx = lua_tonumber(L, 2);
	float by = lua_tonumber(L, 3);
	float nb_keyframes = lua_tonumber(L, 4);

	spine_draw(L, s, bx, by, nb_keyframes);

	return 0;
}

static const struct luaL_Reg spinelib[] =
{
	{"data", spine_new_data},
	{NULL, NULL},
};

static const struct luaL_Reg spine_reg[] =
{
	{"__gc", spine_free},
	{"toScreen", spine_toscreen},
	{"onEvent", spine_cb},
	{"rotation", spine_rotation},
	{"setAnim", spine_setanim},
	{"addAnim", spine_addanim},
	{NULL, NULL},
};

static const struct luaL_Reg spine_data_reg[] =
{
	{"__gc", spine_data_free},
	{"spawn", spine_new},
	{"animMix", spine_animmix},
	{NULL, NULL},
};

int luaopen_spine(lua_State *L)
{
	auxiliar_newclass(L, "display{spine}", spine_reg);
	auxiliar_newclass(L, "display{spine-data}", spine_data_reg);
	luaL_openlib(L, "core.spine", spinelib, 0);
	lua_pop(L, 1);

	return 1;
}
