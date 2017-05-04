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

#include "renderer-moderngl/Renderer.hpp"
#include "renderer-moderngl/FBO.hpp"
#include "renderer-moderngl/TextObject.hpp"
#include "renderer-moderngl/TileMap.hpp"
#include "renderer-moderngl/Particles.hpp"
#include "renderer-moderngl/Physic.hpp"
#include "spriter/Spriter.hpp"

extern "C" {
#include "auxiliar.h"
#include "renderer-moderngl/renderer-lua.h"
}

template<class T=DisplayObject>T* userdata_to_DO(const char *caller, lua_State *L, int index, const char *auxclass) {
	DisplayObject **ptr;
	if (auxclass) {
		ptr = reinterpret_cast<DisplayObject**>(auxiliar_checkclass(L, auxclass, index));
	} else {
		ptr = reinterpret_cast<DisplayObject**>(lua_touserdata(L, index));
		if (!ptr) {
			printf("invalid display object passed ! %s expected\n", typeid(T).name());
			traceback(L);
			luaL_error(L, "invalid display object passed");
		}
	}
	T* result = dynamic_cast<T*>(*ptr);
	if (!result) {
		printf("display object of wrong class! %s / %s (expected) !=! %s (actual) from %s\n", typeid(T).name(), auxclass ? auxclass : "", (*ptr)->getKind(), caller);
		traceback(L);
		luaL_error(L, "display object of wrong class");
	}
	return result;
}


/******************************************************************
 ** Generic
 ******************************************************************/
static void setWeakSelfRef(lua_State *L, int idx, DisplayObject *c) {
	// Get the weak self storage
	lua_rawgeti(L, LUA_REGISTRYINDEX, DisplayObject::weak_registry_ref);
	// Grab a ref and put it there
	lua_pushvalue(L, idx - 1); // ALWAYS use negative idx only, and -1 because we skip over the storage table
	int ref = luaL_ref(L, -2);
	c->setWeakSelfRef(ref);
	lua_pop(L, 1); // Remove the weak storage table
}
static int gl_generic_getkind(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	lua_pushstring(L, c->getKind());
	return 1;
}
static int gl_generic_clone(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	const char *luatype = auxiliar_getclassname(L, 1);

	DisplayObject **nc = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	auxiliar_setclass(L, luatype, -1);
	*nc = c->clone();
	return 1;
}
static int gl_generic_color_get(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	vec4 color = c->getColor();
	lua_pushnumber(L, color.r);
	lua_pushnumber(L, color.g);
	lua_pushnumber(L, color.b);
	lua_pushnumber(L, color.a);
	return 4;
}
static int gl_generic_translate_get(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	float x, y, z;

	if (lua_toboolean(L, 2)) {
		DisplayObject *stop_at = NULL;
		if (lua_isuserdata(L, 2)) {
			stop_at = userdata_to_DO(__FUNCTION__, L, 2);
		}

		// Absolute position mode
		glm::vec4 point = glm::vec4(0, 0, 0, 1);
		recomputematrix orim = c->computeParentCompositeMatrix(stop_at, {glm::mat4(), glm::vec4(1, 1, 1, 1), true});
		point = orim.model * point;
		x = point.x; y = point.y; z = point.z; 
	} else {
		// Normal (relative) position mode
		c->getTranslate(&x, &y, &z);
	}
	lua_pushnumber(L, x);
	lua_pushnumber(L, y);
	lua_pushnumber(L, z);
	return 3;
}
static int gl_generic_rotate_get(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	float x, y, z;
	c->getRotate(&x, &y, &z);
	lua_pushnumber(L, x);
	lua_pushnumber(L, y);
	lua_pushnumber(L, z);
	return 3;
}
static int gl_generic_scale_get(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	float x, y, z;
	c->getScale(&x, &y, &z);
	lua_pushnumber(L, x);
	lua_pushnumber(L, y);
	lua_pushnumber(L, z);
	return 3;
}
static int gl_generic_shown_get(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	lua_pushboolean(L, c->getShown());
	return 1;
}

static int gl_generic_color(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	c->setColor(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));
	lua_pushvalue(L, 1);
	return 1;
}

static bool float_get_lua_table(lua_State *L, int table_idx, const char *field, float *res) {
	bool ret = false;
	lua_pushstring(L, field);
	lua_gettable(L, table_idx);
	if (lua_isnumber(L, -1)) {
		*res = lua_tonumber(L, -1);
		ret = true;
	} else {
		ret = false;
	}
	lua_pop(L, 1);
	return ret;
}
static bool float_get_lua_table(lua_State *L, int table_idx, float field, float *res) {
	bool ret = false;
	lua_pushnumber(L, field);
	lua_gettable(L, table_idx);
	if (lua_isnumber(L, -1)) {
		*res = lua_tonumber(L, -1);
		ret = true;
	} else {
		ret = false;
	}
	lua_pop(L, 1);
	return ret;
}

static bool bool_get_lua_table(lua_State *L, int table_idx, const char *field) {
	bool ret = false;
	lua_pushstring(L, field);
	lua_gettable(L, table_idx);
	ret = lua_toboolean(L, -1);
	lua_pop(L, 1);
	return ret;
}
static bool bool_get_lua_table(lua_State *L, int table_idx, float field) {
	bool ret = false;
	lua_pushnumber(L, field);
	lua_gettable(L, table_idx);
	ret = lua_toboolean(L, -1);
	lua_pop(L, 1);
	return ret;
}

static bool string_get_lua_table(lua_State *L, int table_idx, const char *field, const char **res) {
	bool ret = false;
	lua_pushstring(L, field);
	lua_gettable(L, table_idx);
	if (lua_isstring(L, -1)) {
		*res = lua_tostring(L, -1);
		ret = true;
	} else {
		ret = false;
	}
	lua_pop(L, 1);
	return ret;
}
static bool string_get_lua_table(lua_State *L, int table_idx, float field, const char **res) {
	bool ret = false;
	lua_pushnumber(L, field);
	lua_gettable(L, table_idx);
	if (lua_isstring(L, -1)) {
		*res = lua_tostring(L, -1);
		ret = true;
	} else {
		ret = false;
	}
	lua_pop(L, 1);
	return ret;
}

static int gl_generic_physic_create(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	int pid = c->enablePhysic();
	DORPhysic *physic = c->getPhysic(pid);

	float tmp;
	b2BodyDef bodyDef;
	const char *kindstr = "";
	string_get_lua_table(L, 2, "kind", &kindstr);
	if (!strcmp(kindstr, "static")) bodyDef.type = b2_staticBody;
	else if (!strcmp(kindstr, "dynamic")) bodyDef.type = b2_dynamicBody;
	else if (!strcmp(kindstr, "kinematic")) bodyDef.type = b2_kinematicBody;
	else {
		lua_pushstring(L, "enablePhysic kind must be one of static/kinematic/dynamic");
		lua_error(L);
	}		

	// Define the body fixture.
	if (float_get_lua_table(L, 2, "gravityScale", &tmp)) bodyDef.gravityScale = tmp;
	if (float_get_lua_table(L, 2, "linearDamping", &tmp)) bodyDef.linearDamping = tmp;
	if (float_get_lua_table(L, 2, "angularDamping", &tmp)) bodyDef.angularDamping = tmp;
	bodyDef.fixedRotation = bool_get_lua_table(L, 2, "fixedRotation");
	bodyDef.bullet = bool_get_lua_table(L, 2, "bullet");

	physic->define(bodyDef);
	lua_pushnumber(L, pid);
	return 1;
}

static int gl_generic_physic_destroy(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	if (lua_toboolean(L, 2)) {
		c->destroyPhysic(-1);
	} else {
		c->destroyPhysic(lua_tonumber(L, 2));
	}
	return 0;
}

static int gl_generic_get_physic(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	DORPhysic *physic = c->getPhysic(lua_tonumber(L, 2));
	if (!physic) {
		lua_pushstring(L, "physic() called without previous call to enablePhysic");
		lua_error(L);
	}

	DORPhysic **r = (DORPhysic**)lua_newuserdata(L, sizeof(DORPhysic*));
	auxiliar_setclass(L, "physic{body}", -1);
	*r = physic;
	return 1;
}

#include "renderer-moderngl/easing.hpp" // This imports the code... yeah I know
static int gl_generic_tween(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	int easing_id = lua_tonumber(L, 3);
	easing_ptr easing = easings_table[easing_id];
	int on_end_ref = LUA_NOREF;
	int on_change_ref = LUA_NOREF;
	if (lua_isfunction(L, 7)) {
		lua_pushvalue(L, 7);
		on_end_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	}
	if (lua_isfunction(L, 8)) {
		lua_pushvalue(L, 8);
		on_change_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	}
	TweenSlot slot = (TweenSlot)lua_tonumber(L, 2);
	float from, to;
	if (lua_isnumber(L, 4)) from = lua_tonumber(L, 4);
	else from = c->getDefaultTweenSlotValue(slot);
	if (lua_isnumber(L, 5)) to = lua_tonumber(L, 5);
	else to = c->getDefaultTweenSlotValue(slot);
	c->tween(slot, easing, from, to, lua_tonumber(L, 6), on_end_ref, on_change_ref);

	lua_pushvalue(L, 1);
	return 1;
}
static int gl_generic_cancel_tween(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	if (lua_isboolean(L, 2) && lua_toboolean(L, 2)) {
		c->cancelTween(TweenSlot::MAX);
	} else {
		c->cancelTween((TweenSlot)lua_tonumber(L, 2));
	}
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_generic_translate(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	c->translate(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_generic_rotate(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	c->rotate(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_generic_scale(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	c->scale(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_generic_reset_matrix(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	c->resetModelMatrix();
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_generic_shown(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	c->shown(lua_toboolean(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_generic_remove_from_parent(lua_State *L)
{
	DisplayObject *c = userdata_to_DO(__FUNCTION__, L, 1);
	c->removeFromParent();
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** Renderer
 ******************************************************************/
static int gl_renderer_new(lua_State *L)
{
	DisplayObject **r = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	auxiliar_setclass(L, "gl{renderer}", -1);
	VBOMode mode = VBOMode::DYNAMIC;
	RenderKind kind = RenderKind::QUADS;
	if (lua_isstring(L, 1)) {
		const char *ms = lua_tostring(L, 1);
		if (!strcmp(ms, "static")) mode = VBOMode::STATIC;
		else if (!strcmp(ms, "dynamic")) mode = VBOMode::DYNAMIC;
		else if (!strcmp(ms, "stream")) mode = VBOMode::STREAM;
		else {
			lua_pushstring(L, "Parameter to renderer() must be either nil or static/dynamic/stream");
			lua_error(L);
		}		
	}
	if (lua_isstring(L, 2)) {
		const char *ms = lua_tostring(L, 2);
		if (!strcmp(ms, "quads")) kind = RenderKind::QUADS;
		else if (!strcmp(ms, "triangles")) kind = RenderKind::TRIANGLES;
		else {
			lua_pushstring(L, "Parameter to renderer() must be either nil or quads/triangles");
			lua_error(L);
		}
	}

	RendererGL *rgl = new RendererGL(mode);
	rgl->renderKind(kind);
	*r = rgl;
	setWeakSelfRef(L, -1, rgl);

	return 1;
}

static int gl_renderer_free(lua_State *L)
{
	RendererGL *r = userdata_to_DO<RendererGL>(__FUNCTION__, L, 1, "gl{renderer}");
	delete(r);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_renderer_zsort(lua_State *L)
{
	RendererGL *r = userdata_to_DO<RendererGL>(__FUNCTION__, L, 1, "gl{renderer}");
	if (lua_isstring(L, 2)) {
		SortMode mode = SortMode::NO_SORT;
		const char *ms = lua_tostring(L, 2);
		if (!strcmp(ms, "no")) mode = SortMode::NO_SORT;
		else if (!strcmp(ms, "fast")) mode = SortMode::FAST;
		else if (!strcmp(ms, "full")) mode = SortMode::FULL;
		else if (!strcmp(ms, "gl")) mode = SortMode::GL;
		else {
			lua_pushstring(L, "Parameter to zSort() must be either true/falase or no/fast/full/gl");
			lua_error(L);
		}		
		r->zSorting(mode);
	} else {
		r->zSorting(lua_toboolean(L, 2) ? SortMode::FAST : SortMode::NO_SORT);
	}
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_renderer_cutoff(lua_State *L)
{
	RendererGL *r = userdata_to_DO<RendererGL>(__FUNCTION__, L, 1, "gl{renderer}");
	r->cutoff(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_renderer_blend(lua_State *L)
{
	RendererGL *r = userdata_to_DO<RendererGL>(__FUNCTION__, L, 1, "gl{renderer}");
	r->enableBlending(lua_toboolean(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_renderer_premultiplied_alpha(lua_State *L)
{
	RendererGL *r = userdata_to_DO<RendererGL>(__FUNCTION__, L, 1, "gl{renderer}");
	r->premultipliedAlpha(lua_toboolean(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_renderer_shader(lua_State *L)
{
	RendererGL *r = userdata_to_DO<RendererGL>(__FUNCTION__, L, 1, "gl{renderer}");
	if (lua_isnil(L, 2)) {
		r->setShader(NULL, LUA_NOREF);
	} else {
		shader_type *shader = (shader_type*)lua_touserdata(L, 2);
		lua_pushvalue(L, 2);
		r->setShader(shader, luaL_ref(L, LUA_REGISTRYINDEX));
	}
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_renderer_set_name(lua_State *L)
{
	RendererGL *r = userdata_to_DO<RendererGL>(__FUNCTION__, L, 1, "gl{renderer}");
	r->setRendererName(luaL_checkstring(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_renderer_count_time(lua_State *L)
{
	RendererGL *r = userdata_to_DO<RendererGL>(__FUNCTION__, L, 1, "gl{renderer}");
	r->countTime(lua_toboolean(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_renderer_count_draws(lua_State *L)
{
	RendererGL *r = userdata_to_DO<RendererGL>(__FUNCTION__, L, 1, "gl{renderer}");
	r->countDraws(lua_toboolean(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_renderer_toscreen(lua_State *L)
{
	RendererGL *r = userdata_to_DO<RendererGL>(__FUNCTION__, L, 1, "gl{renderer}");
	if (lua_isnumber(L, 2)) {
		mat4 model = mat4();
		model = glm::translate(model, glm::vec3(lua_tonumber(L, 2), lua_tonumber(L, 3), 0));
		r->toScreen(model, {1, 1, 1, 1});
	} else {
		r->toScreenSimple();
	}
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** Container
 ******************************************************************/
static int gl_container_new(lua_State *L)
{
	DisplayObject **c = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	auxiliar_setclass(L, "gl{container}", -1);
	*c = new DORContainer();
	setWeakSelfRef(L, -1, *c);

	return 1;
}

static int gl_container_free(lua_State *L)
{
	DORContainer *c = userdata_to_DO<DORContainer>(__FUNCTION__, L, 1, "gl{container}");
	delete(c);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_container_add(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	DORContainer *c = userdata_to_DO<DORContainer>(__FUNCTION__, L, 1);
	DisplayObject *add = userdata_to_DO(__FUNCTION__, L, 2);
	c->add(add);
	add->setLuaRef(luaL_ref(L, LUA_REGISTRYINDEX));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_container_remove(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	DORContainer *c = userdata_to_DO<DORContainer>(__FUNCTION__, L, 1);
	DisplayObject *add = userdata_to_DO(__FUNCTION__, L, 2);
	c->remove(add);
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_container_clear(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	DORContainer *c = userdata_to_DO<DORContainer>(__FUNCTION__, L, 1);
	c->clear();
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** Target (FBO)
 ******************************************************************/
static int gl_target_new(lua_State *L)
{
	DisplayObject **c = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	auxiliar_setclass(L, "gl{target}", -1);
	int w = screen->w / screen_zoom;
	int h = screen->h / screen_zoom;
	int nbt = 1;

	if (lua_isnumber(L, 1)) w = lua_tonumber(L, 1);
	if (lua_isnumber(L, 2)) h = lua_tonumber(L, 2);
	if (lua_isnumber(L, 3)) nbt = lua_tonumber(L, 3);
	bool hdr = lua_toboolean(L, 4);
	bool depth = lua_toboolean(L, 5);

	*c = new DORTarget(w, h, nbt, hdr, depth);
	setWeakSelfRef(L, -1, *c);

	return 1;
}

static int gl_target_free(lua_State *L)
{
	DORTarget *c = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	delete(c);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_target_toscreen(lua_State *L)
{
	DORTarget *c = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	c->toScreen(lua_tonumber(L, 2), lua_tonumber(L, 3));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_compute(lua_State *L)
{
	DORTarget *c = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	c->tick();
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_use(lua_State *L)
{
	DORTarget *c = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	c->use(lua_toboolean(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_displaysize(lua_State *L)
{
	DORTarget *c = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	if (lua_isnumber(L, 2)) {
		c->displaySize(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_toboolean(L, 4));
		lua_pushvalue(L, 1);
		return 1;
	} else {
		int w, h;
		c->getDisplaySize(&w, &h);
		lua_pushnumber(L, w);
		lua_pushnumber(L, h);
		return 2;
	}
}

static int gl_target_clearcolor(lua_State *L)
{
	DORTarget *c = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	c->setClearColor(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_view(lua_State *L)
{
	DORTarget *v = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	View *t = *(View**)auxiliar_checkclass(L, "gl{view}", 2);
	lua_pushvalue(L, 2);
	v->setView(t, luaL_ref(L, LUA_REGISTRYINDEX));

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_texture(lua_State *L)
{
	DORTarget *v = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 2);
	int id = lua_tonumber(L, 3);
	if (!id) {
		lua_pushstring(L, "Can not set textute 0 of a target object");
		lua_error(L);
	}
	lua_pushvalue(L, 2);
	v->setTexture(t->tex, luaL_ref(L, LUA_REGISTRYINDEX), id);

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_target_texture(lua_State *L)
{
	DORTarget *v = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	DORTarget *t = userdata_to_DO<DORTarget>(__FUNCTION__, L, 2, "gl{target}");
	int id = lua_tonumber(L, 4);
	if (!id) {
		lua_pushstring(L, "Can not set textute 0 of a target object");
		lua_error(L);
	}
	lua_pushvalue(L, 2);
	v->setTexture(t->getTexture(lua_tonumber(L, 3)), luaL_ref(L, LUA_REGISTRYINDEX), id);

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_mode_bloom(lua_State *L)
{
	DORTarget *v = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");

	int blur_passes = lua_tonumber(L, 2);

	shader_type *bloom = (shader_type*)lua_touserdata(L, 3);
	lua_pushvalue(L, 3); int bloom_ref = luaL_ref(L, LUA_REGISTRYINDEX);

	shader_type *hblur = (shader_type*)lua_touserdata(L, 4);
	lua_pushvalue(L, 4); int hblur_ref = luaL_ref(L, LUA_REGISTRYINDEX);

	shader_type *vblur = (shader_type*)lua_touserdata(L, 5);
	lua_pushvalue(L, 5); int vblur_ref = luaL_ref(L, LUA_REGISTRYINDEX);

	shader_type *combine = (shader_type*)lua_touserdata(L, 6);
	lua_pushvalue(L, 6); int combine_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	
	TargetBloom *mode = new TargetBloom(
		v,
		blur_passes,
		bloom, bloom_ref,
		hblur, hblur_ref,
		vblur, vblur_ref,
		combine, combine_ref
	);
	v->setSpecialMode(mode);

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_mode_bloom2(lua_State *L)
{
	DORTarget *v = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");

	int blur_passes = lua_tonumber(L, 2);

	shader_type *bloom = (shader_type*)lua_touserdata(L, 3);
	lua_pushvalue(L, 3); int bloom_ref = luaL_ref(L, LUA_REGISTRYINDEX);

	shader_type *blur = (shader_type*)lua_touserdata(L, 4);
	lua_pushvalue(L, 4); int blur_ref = luaL_ref(L, LUA_REGISTRYINDEX);

	shader_type *combine = (shader_type*)lua_touserdata(L, 5);
	lua_pushvalue(L, 5); int combine_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	
	TargetBloom2 *mode = new TargetBloom2(
		v,
		blur_passes,
		bloom, bloom_ref,
		blur, blur_ref,
		combine, combine_ref
	);
	v->setSpecialMode(mode);

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_mode_blur(lua_State *L)
{
	DORTarget *v = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");

	int blur_passes = lua_tonumber(L, 2);

	shader_type *blur = (shader_type*)lua_touserdata(L, 3);
	lua_pushvalue(L, 3); int blur_ref = luaL_ref(L, LUA_REGISTRYINDEX);

	TargetBlur *mode = new TargetBlur(
		v,
		blur_passes,
		blur, blur_ref
	);
	v->setSpecialMode(mode);

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_mode_blur_downsampling(lua_State *L)
{
	DORTarget *v = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");

	int blur_passes = lua_tonumber(L, 2);

	shader_type *blur = (shader_type*)lua_touserdata(L, 3);
	lua_pushvalue(L, 3); int blur_ref = luaL_ref(L, LUA_REGISTRYINDEX);

	TargetBlurDownsampling *mode = new TargetBlurDownsampling(
		v,
		blur_passes,
		blur, blur_ref
	);
	v->setSpecialMode(mode);

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_post_effect_disableall(lua_State *L)
{
	TargetPostProcess *p = *(TargetPostProcess**)auxiliar_checkclass(L, "gl{target:posteffects}", 1);
	p->disableAll();
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_post_effect_enable(lua_State *L)
{
	TargetPostProcess *p = *(TargetPostProcess**)auxiliar_checkclass(L, "gl{target:posteffects}", 1);
	p->enable(lua_tostring(L, 2), lua_toboolean(L, 3));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_mode_posteffects(lua_State *L)
{
	DORTarget *v = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");

	TargetPostProcess *mode = new TargetPostProcess(v);
	v->setSpecialMode(mode);

	// Iterate shaders
	int idx = 2;
	while (lua_istable(L, idx)) {
		const char *name = "";
		if (string_get_lua_table(L, idx, 1, &name)) {
			lua_pushnumber(L, 2);
			lua_gettable(L, idx);
			shader_type *shad = (shader_type*)lua_touserdata(L, -1);
			lua_pushvalue(L, -1); int ref = luaL_ref(L, LUA_REGISTRYINDEX);
			lua_pop(L, 1);
			mode->add(name, shad, ref);
		}
		idx++;
	}

	TargetPostProcess **r = (TargetPostProcess**)lua_newuserdata(L, sizeof(TargetPostProcess*));
	auxiliar_setclass(L, "gl{target:posteffects}", -1);
	*r = mode;
	return 1;
}

static int gl_target_shader(lua_State *L)
{
	DORTarget *v = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	if (lua_isnil(L, 2)) {
		v->setShader(NULL);
	} else {
		shader_type *shader = (shader_type*)lua_touserdata(L, 2);
		v->setShader(shader);
	}
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_target_set_auto_render(lua_State *L)
{
	DORTarget *c = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	if (lua_isnil(L, 2)) {
		c->setAutoRender(NULL, LUA_NOREF);
	} else {
		ISubRenderer *o = userdata_to_DO<ISubRenderer>(__FUNCTION__, L, 2);
		if (o) {
			lua_pushvalue(L, 2);
			c->setAutoRender(o, luaL_ref(L, LUA_REGISTRYINDEX));
		}
	}
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** Vertexes
 ******************************************************************/
static int gl_vertexes_new(lua_State *L)
{
	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	auxiliar_setclass(L, "gl{vertexes}", -1);
	*v = new DORVertexes();
	setWeakSelfRef(L, -1, *v);

	return 1;
}

static int gl_vertexes_free(lua_State *L)
{
	DORVertexes *v = userdata_to_DO<DORVertexes>(__FUNCTION__, L, 1, "gl{vertexes}");
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_vertexes_clear(lua_State *L)
{
	DORVertexes *v = userdata_to_DO<DORVertexes>(__FUNCTION__, L, 1, "gl{vertexes}");
	v->clear();
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_vertexes_reserve(lua_State *L)
{
	DORVertexes *v = userdata_to_DO<DORVertexes>(__FUNCTION__, L, 1, "gl{vertexes}");
	v->reserveFaces(lua_tonumber(L, 2));
	return 0;
}

static int gl_vertexes_quad(lua_State *L)
{
	DORVertexes *v = userdata_to_DO<DORVertexes>(__FUNCTION__, L, 1, "gl{vertexes}");
	if (lua_isnumber(L, 2)) {
		float x1 = lua_tonumber(L, 2);  float y1 = lua_tonumber(L, 3);  float u1 = lua_tonumber(L, 4);  float v1 = lua_tonumber(L, 5); 
		float x2 = lua_tonumber(L, 6);  float y2 = lua_tonumber(L, 7);  float u2 = lua_tonumber(L, 8);  float v2 = lua_tonumber(L, 9); 
		float x3 = lua_tonumber(L, 10); float y3 = lua_tonumber(L, 11); float u3 = lua_tonumber(L, 12); float v3 = lua_tonumber(L, 13); 
		float x4 = lua_tonumber(L, 14); float y4 = lua_tonumber(L, 15); float u4 = lua_tonumber(L, 16); float v4 = lua_tonumber(L, 17); 
		float r = lua_tonumber(L, 18); float g = lua_tonumber(L, 19); float b = lua_tonumber(L, 20); float a = lua_tonumber(L, 21);
		v->addQuad(
			x1, y1, u1, v1, 
			x2, y2, u2, v2, 
			x3, y3, u3, v3, 
			x4, y4, u4, v4, 
			0,
			r, g, b, a
		);
	} else {
		vertex vs[4];
		for (int i = 0; i < 4; i++) {
			vs[i].pos.w = 1;
			lua_pushliteral(L, "x"); lua_rawget(L, i + 2); vs[i].pos.x = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_pushliteral(L, "y"); lua_rawget(L, i + 2); vs[i].pos.y = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_pushliteral(L, "z"); lua_rawget(L, i + 2); vs[i].pos.z = lua_tonumber(L, -1); lua_pop(L, 1);
			
			lua_pushliteral(L, "r"); lua_rawget(L, i + 2); vs[i].color.r = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_pushliteral(L, "g"); lua_rawget(L, i + 2); vs[i].color.g = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_pushliteral(L, "b"); lua_rawget(L, i + 2); vs[i].color.b = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_pushliteral(L, "a"); lua_rawget(L, i + 2); vs[i].color.a = lua_tonumber(L, -1); lua_pop(L, 1);

			lua_pushliteral(L, "u"); lua_rawget(L, i + 2); vs[i].tex.x = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_pushliteral(L, "v"); lua_rawget(L, i + 2); vs[i].tex.y = lua_tonumber(L, -1); lua_pop(L, 1);

			lua_pushliteral(L, "kind"); lua_rawget(L, i + 2); vs[i].kind = lua_tonumber(L, -1); lua_pop(L, 1);

			lua_pushliteral(L, "mx"); lua_rawget(L, i + 2); vs[i].mapcoords.x = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_pushliteral(L, "my"); lua_rawget(L, i + 2); vs[i].mapcoords.y = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_pushliteral(L, "mw"); lua_rawget(L, i + 2); vs[i].mapcoords.z = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_pushliteral(L, "mh"); lua_rawget(L, i + 2); vs[i].mapcoords.w = lua_tonumber(L, -1); lua_pop(L, 1);

			lua_pushliteral(L, "tx"); lua_rawget(L, i + 2); vs[i].texcoords.x = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_pushliteral(L, "ty"); lua_rawget(L, i + 2); vs[i].texcoords.y = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_pushliteral(L, "tw"); lua_rawget(L, i + 2); vs[i].texcoords.z = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_pushliteral(L, "th"); lua_rawget(L, i + 2); vs[i].texcoords.w = lua_tonumber(L, -1); lua_pop(L, 1);
		}
		v->addQuad(vs[0], vs[1], vs[2], vs[3]);
	}
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_vertexes_quad_pie(lua_State *L)
{
	DORVertexes *v = userdata_to_DO<DORVertexes>(__FUNCTION__, L, 1, "gl{vertexes}");
	float x1 = lua_tonumber(L, 2);  float y1 = lua_tonumber(L, 3);  float x2 = lua_tonumber(L, 4);  float y2 = lua_tonumber(L, 5); 
	float u1 = lua_tonumber(L, 6);  float v1 = lua_tonumber(L, 7);  float u2 = lua_tonumber(L, 8);  float v2 = lua_tonumber(L, 9); 
	float angle = lua_tonumber(L, 10);
	float r = lua_tonumber(L, 11); float g = lua_tonumber(L, 12); float b = lua_tonumber(L, 13); float a = lua_tonumber(L, 14);
	v->addQuadPie(
		x1, y1, x2, y2,
		u1, v1, u2, v2,
		angle,
		r, g, b, a
	);
	lua_pushvalue(L, 1);
	return 1;
}

// static int gl_vertexes_load_obj(lua_State *L)
// {
// 	DORVertexes *v = userdata_to_DO<DORVertexes>(__FUNCTION__, L, 1, "gl{vertexes}");
// 	string filename(luaL_checkstring(L, 2));
// 	v->loadObj(filename);
// 	lua_pushvalue(L, 1);
// 	return 1;
// }

static int gl_vertexes_texture(lua_State *L)
{
	DORVertexes *v = userdata_to_DO<DORVertexes>(__FUNCTION__, L, 1, "gl{vertexes}");
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 2);
	int id = lua_tonumber(L, 3);
	lua_pushvalue(L, 2);
	v->setTexture(t->tex, luaL_ref(L, LUA_REGISTRYINDEX), id);

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_vertexes_target_texture(lua_State *L)
{
	DORVertexes *v = userdata_to_DO<DORVertexes>(__FUNCTION__, L, 1, "gl{vertexes}");
	DORTarget *t = userdata_to_DO<DORTarget>(__FUNCTION__, L, 2, "gl{target}");
	int id = lua_tonumber(L, 4);
	lua_pushvalue(L, 2);
	v->setTexture(t->getTexture(lua_tonumber(L, 3)), luaL_ref(L, LUA_REGISTRYINDEX), id);

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_vertexes_font_atlas_texture(lua_State *L)
{
	DORVertexes *v = userdata_to_DO<DORVertexes>(__FUNCTION__, L, 1, "gl{vertexes}");
	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 2);
	lua_pushvalue(L, 2);
	v->setTexture(f->atlas->id, luaL_ref(L, LUA_REGISTRYINDEX));

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_vertexes_shader(lua_State *L)
{
	DORVertexes *v = userdata_to_DO<DORVertexes>(__FUNCTION__, L, 1, "gl{vertexes}");
	if (lua_isnil(L, 2)) {
		v->setShader(NULL);
	} else {
		shader_type *shader = (shader_type*)lua_touserdata(L, 2);
		v->setShader(shader);
	}
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** Text
 ******************************************************************/
static int gl_text_new(lua_State *L)
{
	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	DORText *t;
	auxiliar_setclass(L, "gl{text}", -1);

	*v = t = new DORText();
	setWeakSelfRef(L, -1, t);

	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
	if (lua_isnumber(L, 2)) t->setMaxWidth(lua_tonumber(L, 2));
	t->setNoLinefeed(lua_toboolean(L, 3));

	lua_pushvalue(L, 1);
	t->setFont(f, luaL_ref(L, LUA_REGISTRYINDEX));

	return 1;
}

static int gl_text_free(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_text_linefeed(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	v->setNoLinefeed(!lua_toboolean(L, 2));

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_text_get_letter_position(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	vec2 pos = v->getLetterPosition(lua_tonumber(L, 2));
	lua_pushnumber(L, pos.x);
	lua_pushnumber(L, pos.y);
	return 2;
}

static int gl_text_max_width(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	v->setMaxWidth(lua_tonumber(L, 2));

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_text_max_lines(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	v->setMaxLines(lua_tonumber(L, 2));

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_text_shadow(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	vec4 color = {0, 0, 0, 0.7};
	if (lua_isnumber(L, 4)) {
		color.r = lua_tonumber(L, 4);
		color.g = lua_tonumber(L, 5);
		color.b = lua_tonumber(L, 6);
		color.a = lua_tonumber(L, 7);
	}
	v->setShadow(lua_tonumber(L, 2), lua_tonumber(L, 3), color);

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_text_outline(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	vec4 color = {0, 0, 0, 0.7};
	if (lua_isnumber(L, 3)) {
		color.r = lua_tonumber(L, 3);
		color.g = lua_tonumber(L, 4);
		color.b = lua_tonumber(L, 5);
		color.a = lua_tonumber(L, 6);
	}
	v->setOutline(lua_tonumber(L, 2), color);

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_text_style(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	const char *style = luaL_checkstring(L, 2);

	if (!strcmp(style, "normal")) v->setTextStyle(FONT_STYLE_NORMAL);
	else if (!strcmp(style, "bold")) v->setTextStyle(FONT_STYLE_BOLD);
	else if (!strcmp(style, "italic")) v->setTextStyle(FONT_STYLE_ITALIC);
	else if (!strcmp(style, "underline")) v->setTextStyle(FONT_STYLE_UNDERLINED);
	else {
		lua_pushstring(L, "text:style called without normal/bold/italic/underline");
		lua_error(L);
	}
	return 0;
}

static int gl_text_text_color(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	v->setTextColor(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_text_center(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	v->center();
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_text_set(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	v->setText(luaL_checkstring(L, 2), lua_toboolean(L, 3));

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_text_stats(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");

	lua_pushnumber(L, v->w);
	lua_pushnumber(L, v->h);
	lua_pushnumber(L, v->nb_lines);
	return 3;
}

static int gl_text_shader(lua_State *L)
{
	DORText *v = userdata_to_DO<DORText>(__FUNCTION__, L, 1, "gl{text}");
	if (lua_isnil(L, 2)) {
		v->setShader(NULL);
	} else {
		shader_type *shader = (shader_type*)lua_touserdata(L, 2);
		v->setShader(shader);
	}
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** DORCallback 
 ******************************************************************/
static int gl_callback_new(lua_State *L)
{
	if (!lua_isfunction(L, 1)) {
		lua_pushstring(L, "callback arg is not a function");
		lua_error(L);
		return 0;
	}

	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	DORCallback *t;
	auxiliar_setclass(L, "gl{callback}", -1);

	*v = t = new DORCallback();
	setWeakSelfRef(L, -1, t);

	lua_pushvalue(L, 1);
	t->setCallback(luaL_ref(L, LUA_REGISTRYINDEX));

	return 1;
}

static int gl_callback_free(lua_State *L)
{
	DORCallback *v = userdata_to_DO<DORCallback>(__FUNCTION__, L, 1, "gl{callback}");
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_callback_set(lua_State *L)
{
	DORCallback *v = userdata_to_DO<DORCallback>(__FUNCTION__, L, 1, "gl{callback}");
	if (!lua_isfunction(L, 2)) {
		lua_pushstring(L, "callback arg is not a function");
		lua_error(L);
		return 0;
	}
	lua_pushvalue(L, 2);
	v->setCallback(luaL_ref(L, LUA_REGISTRYINDEX));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_callback_enable(lua_State *L)
{
	DORCallback *v = userdata_to_DO<DORCallback>(__FUNCTION__, L, 1, "gl{callback}");
	v->enable(lua_toboolean(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** TileObject -- no constructor, this is in map.cpp
 ******************************************************************/
static int gl_tileobject_free(lua_State *L)
{
	DORTileObject *v = userdata_to_DO<DORTileObject>(__FUNCTION__, L, 1, "gl{tileobject}");
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

/******************************************************************
 ** Particles -- no constructor, this is in particles.cpp
 ******************************************************************/
static int gl_particles_free(lua_State *L)
{
	DORParticles *v = userdata_to_DO<DORParticles>(__FUNCTION__, L, 1, "gl{particles}");
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

/******************************************************************
 ** TileMap -- no constructor, this is in map.cpp
 ******************************************************************/
static int gl_tilemap_free(lua_State *L)
{
	DORTileMap *v = userdata_to_DO<DORTileMap>(__FUNCTION__, L, 1, "gl{tilemap}");
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_tilemap_setmap(lua_State *L)
{
	DORTileMap *v = userdata_to_DO<DORTileMap>(__FUNCTION__, L, 1, "gl{tilemap}");
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 2);

	v->setMap(map);	
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_tilemap_setminimap_info(lua_State *L)
{
	DORTileMap *v = userdata_to_DO<DORTileMap>(__FUNCTION__, L, 1, "gl{tilemap}");

	v->setMinimapInfo(luaL_checknumber(L, 2), luaL_checknumber(L, 3), luaL_checknumber(L, 4), luaL_checknumber(L, 5), luaL_checknumber(L, 6), luaL_checknumber(L, 7));
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** DORSpriter
 ******************************************************************/
static int gl_spriter_new(lua_State *L)
{
	const char *file = luaL_checkstring(L, 1);
	const char *name = luaL_checkstring(L, 2);

	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	DORSpriter *t;
	auxiliar_setclass(L, "gl{spriter}", -1);

	*v = t = new DORSpriter();
	setWeakSelfRef(L, -1, t);
	t->load(file, name);
	return 1;
}

static int gl_spriter_free(lua_State *L)
{
	DORSpriter *v = userdata_to_DO<DORSpriter>(__FUNCTION__, L, 1, "gl{spriter}");
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_spriter_shader(lua_State *L)
{
	DORSpriter *v = userdata_to_DO<DORSpriter>(__FUNCTION__, L, 1, "gl{spriter}");
	if (lua_isnil(L, 2)) {
		v->setShader(NULL);
	} else {
		shader_type *shader = (shader_type*)lua_touserdata(L, 2);
		v->setShader(shader);
	}
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_spriter_get_object_position(lua_State *L)
{
	DORSpriter *v = userdata_to_DO<DORSpriter>(__FUNCTION__, L, 1, "gl{spriter}");
	vec2 pos = v->getObjectPosition(lua_tostring(L, 2));
	lua_pushnumber(L, pos.x);
	lua_pushnumber(L, pos.y);
	return 2;
}

static int gl_spriter_character_map(lua_State *L)
{
	DORSpriter *v = userdata_to_DO<DORSpriter>(__FUNCTION__, L, 1, "gl{spriter}");
	if (lua_toboolean(L, 3)) v->applyCharacterMap(lua_tostring(L, 2));
	else v->removeCharacterMap(lua_tostring(L, 2));
	return 0;
}

static int gl_spriter_set_anim(lua_State *L)
{
	DORSpriter *v = userdata_to_DO<DORSpriter>(__FUNCTION__, L, 1, "gl{spriter}");
	v->startAnim(luaL_checkstring(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_spriter_trigger_callback(lua_State *L)
{
	DORSpriter *v = userdata_to_DO<DORSpriter>(__FUNCTION__, L, 1, "gl{spriter}");
	if (!lua_isfunction(L, 2)) {
		lua_pushstring(L, "callback arg is not a function");
		lua_error(L);
		return 0;
	}
	lua_pushvalue(L, 2);
	v->setTriggerCallback(luaL_ref(L, LUA_REGISTRYINDEX));
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** VBO
 ******************************************************************/
static int gl_vbo_new(lua_State *L)
{
	VBO **v = (VBO**)lua_newuserdata(L, sizeof(VBO*));
	auxiliar_setclass(L, "gl{vbo}", -1);

	VBOMode mode = VBOMode::DYNAMIC;
	if (lua_isstring(L, 1)) {
		const char *ms = lua_tostring(L, 1);
		if (!strcmp(ms, "static")) mode = VBOMode::STATIC;
		else if (!strcmp(ms, "dynamic")) mode = VBOMode::DYNAMIC;
		else if (!strcmp(ms, "stream")) mode = VBOMode::STREAM;
		else {
			lua_pushstring(L, "Parameter to vbo() must be either nil or static/dynamic/stream");
			lua_error(L);
		}		
	}

	*v = new VBO(mode);
	return 1;
}

static int gl_vbo_free(lua_State *L)
{
	VBO *v = *(VBO**)auxiliar_checkclass(L, "gl{vbo}", 1);
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_vbo_shader(lua_State *L)
{
	VBO *v = *(VBO**)auxiliar_checkclass(L, "gl{vbo}", 1);
	if (lua_isnil(L, 2)) {
		v->setShader(NULL);
	} else {
		shader_type *shader = (shader_type*)lua_touserdata(L, 2);
		v->setShader(shader);
	}
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_vbo_texture(lua_State *L)
{
	VBO *v = *(VBO**)auxiliar_checkclass(L, "gl{vbo}", 1);
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 2);
	int id = lua_tonumber(L, 3);
	v->setTexture(t->tex, id);

	lua_pushvalue(L, 1);
	return 1;
}

static int gl_vbo_color(lua_State *L)
{
	VBO *v = *(VBO**)auxiliar_checkclass(L, "gl{vbo}", 1);
	v->setColor(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_vbo_clear(lua_State *L)
{
	VBO *v = *(VBO**)auxiliar_checkclass(L, "gl{vbo}", 1);
	v->clear();
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_vbo_quad(lua_State *L)
{
	VBO *v = *(VBO**)auxiliar_checkclass(L, "gl{vbo}", 1);
	float x1 = lua_tonumber(L, 2);  float y1 = lua_tonumber(L, 3);  float u1 = lua_tonumber(L, 4);  float v1 = lua_tonumber(L, 5); 
	float x2 = lua_tonumber(L, 6);  float y2 = lua_tonumber(L, 7);  float u2 = lua_tonumber(L, 8);  float v2 = lua_tonumber(L, 9); 
	float x3 = lua_tonumber(L, 10); float y3 = lua_tonumber(L, 11); float u3 = lua_tonumber(L, 12); float v3 = lua_tonumber(L, 13); 
	float x4 = lua_tonumber(L, 14); float y4 = lua_tonumber(L, 15); float u4 = lua_tonumber(L, 16); float v4 = lua_tonumber(L, 17); 
	float r = lua_tonumber(L, 18); float g = lua_tonumber(L, 19); float b = lua_tonumber(L, 20); float a = lua_tonumber(L, 21);
	v->addQuad(
		x1, y1, u1, v1, 
		x2, y2, u2, v2, 
		x3, y3, u3, v3, 
		x4, y4, u4, v4, 
		r, g, b, a
	);
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_vbo_toscreen(lua_State *L)
{
	VBO *v = *(VBO**)auxiliar_checkclass(L, "gl{vbo}", 1);
	float scale_x = 1, scale_y = 1;
	if (lua_isnumber(L, 5)) scale_x = lua_tonumber(L, 5);
	if (lua_isnumber(L, 6)) scale_y = lua_tonumber(L, 6);
	v->toScreen(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), scale_x, scale_y);
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** View
 ******************************************************************/
static int gl_view_new(lua_State *L)
{
	View **v = (View**)lua_newuserdata(L, sizeof(View*));
	auxiliar_setclass(L, "gl{view}", -1);

	*v = new View();
	return 1;
}

static int gl_view_free(lua_State *L)
{
	View *v = *(View**)auxiliar_checkclass(L, "gl{view}", 1);
	delete(v);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_view_ortho(lua_State *L)
{
	View *v = *(View**)auxiliar_checkclass(L, "gl{view}", 1);
	v->setOrthoView(luaL_checknumber(L, 2), luaL_checknumber(L, 3));
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_view_project(lua_State *L)
{
	View *v = *(View**)auxiliar_checkclass(L, "gl{view}", 1);
	DisplayObject *camera = userdata_to_DO(__FUNCTION__, L, 5);
	DisplayObject *origin = userdata_to_DO(__FUNCTION__, L, 6);
	lua_pushvalue(L, 5);
	int camera_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	lua_pushvalue(L, 6);
	int origin_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	float nearp = 0.001, farp = 1000;

	if (lua_isnumber(L, 7)) nearp = lua_tonumber(L, 7);
	if (lua_isnumber(L, 8)) farp = lua_tonumber(L, 8);

	v->setProjectView(luaL_checknumber(L, 2), luaL_checknumber(L, 3), luaL_checknumber(L, 4), nearp, farp, camera, camera_ref, origin, origin_ref);
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_view_use(lua_State *L)
{
	View *v = *(View**)auxiliar_checkclass(L, "gl{view}", 1);
	v->use(lua_toboolean(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}

/******************************************************************
 ** Physic bodies
 ******************************************************************/
static int body_add_fixture(lua_State *L)
{
	DORPhysic *physic = *(DORPhysic**)auxiliar_checkclass(L, "physic{body}", 1);

	float tmp;

	// Define the body fixture.
	b2FixtureDef fixtureDef;
	if (float_get_lua_table(L, 2, "density", &tmp)) fixtureDef.density = tmp;
	if (float_get_lua_table(L, 2, "friction", &tmp)) fixtureDef.friction = tmp;
	if (float_get_lua_table(L, 2, "restitution", &tmp)) fixtureDef.restitution = tmp;
	fixtureDef.isSensor = bool_get_lua_table(L, 2, "sensor");

	// Define the filter
	lua_pushstring(L, "filter");
	lua_gettable(L, 2);
	if (lua_istable(L, -1)) {
		int filter_table_idx = lua_gettop(L);
		if (float_get_lua_table(L, filter_table_idx, "group", &tmp)) fixtureDef.filter.groupIndex = tmp;
		if (float_get_lua_table(L, filter_table_idx, "category", &tmp)) fixtureDef.filter.categoryBits = static_cast<uint16>(tmp);
		if (float_get_lua_table(L, filter_table_idx, "mask", &tmp)) fixtureDef.filter.maskBits = static_cast<uint16>(tmp);
	}
	lua_pop(L, 1);

	// Define the shape
	lua_pushstring(L, "shape");
	lua_gettable(L, 2);
	if (!lua_istable(L, -1)) {
		lua_pushstring(L, "enablePhysic needs a shape definition");
		lua_error(L);
	}		
	int shape_table_idx = lua_gettop(L);

	b2Fixture *fixture = NULL;

	const char *shapestr = "";
	string_get_lua_table(L, shape_table_idx, 1, &shapestr);
	if (!strcmp(shapestr, "box")) {
		b2PolygonShape shape;
		float w = 1, h = 1;
		if (float_get_lua_table(L, shape_table_idx, 2, &tmp)) w = tmp;	
		if (float_get_lua_table(L, shape_table_idx, 3, &tmp)) h = tmp;	
		shape.SetAsBox(w / 2 / PhysicSimulator::unit_scale, h / 2 / PhysicSimulator::unit_scale);
		fixtureDef.shape = &shape;
		fixture = physic->addFixture(fixtureDef);
	} else if (!strcmp(shapestr, "circle")) {
		b2CircleShape shape;
		if (float_get_lua_table(L, shape_table_idx, 2, &tmp)) shape.m_radius = tmp / 2 / PhysicSimulator::unit_scale;
		fixtureDef.shape = &shape;
		fixture = physic->addFixture(fixtureDef);
	} else if (!strcmp(shapestr, "line")) {
		b2ChainShape shape;
		lua_rawgeti(L, shape_table_idx, 2);
		int nb = lua_objlen(L, -1);
		vector<b2Vec2> vs(nb);
		for (int i = 1; i <= nb; i++) {
			float x, y;
			lua_rawgeti(L, -1, i);
			int top = lua_gettop(L);
			if (float_get_lua_table(L, top, 1, &x) && float_get_lua_table(L, top, 2, &y)) {
				vs[i-1] = {x / PhysicSimulator::unit_scale, -y / PhysicSimulator::unit_scale};
			}
			lua_pop(L, 1);
		}
		lua_rawgeti(L, shape_table_idx, 3);
		if (lua_toboolean(L, -1)) shape.CreateLoop(vs.data(), nb);
		else shape.CreateChain(vs.data(), nb);
		lua_pop(L, 2);
		fixtureDef.shape = &shape;
		fixture = physic->addFixture(fixtureDef);
	} else {
		lua_pushstring(L, "addFixture shape must be one of box/circle/line");
		lua_error(L);
	}
	lua_pop(L, 1);

	lua_pushvalue(L, 1);
	return 1;
}

static int body_apply_force(lua_State *L)
{
	DORPhysic *p = *(DORPhysic**)auxiliar_checkclass(L, "physic{body}", 1);
	if (lua_isnumber(L, 4)) p->applyForce(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));
	else p->applyForce(lua_tonumber(L, 2), lua_tonumber(L, 3));
	lua_pushvalue(L, 1);
	return 1;
}
static int body_apply_linear_impulse(lua_State *L)
{
	DORPhysic *p = *(DORPhysic**)auxiliar_checkclass(L, "physic{body}", 1);
	if (lua_isnumber(L, 4)) p->applyLinearImpulse(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));
	else p->applyLinearImpulse(lua_tonumber(L, 2), lua_tonumber(L, 3));
	lua_pushvalue(L, 1);
	return 1;
}
static int body_apply_set_linear_velocity(lua_State *L)
{
	DORPhysic *p = *(DORPhysic**)auxiliar_checkclass(L, "physic{body}", 1);
	p->setLinearVelocity(lua_tonumber(L, 2), lua_tonumber(L, 3));
	lua_pushvalue(L, 1);
	return 1;
}
static int body_apply_torque(lua_State *L)
{
	DORPhysic *p = *(DORPhysic**)auxiliar_checkclass(L, "physic{body}", 1);
	p->applyTorque(lua_tonumber(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}
static int body_apply_angular_impulse(lua_State *L)
{
	DORPhysic *p = *(DORPhysic**)auxiliar_checkclass(L, "physic{body}", 1);
	p->applyAngularImpulse(lua_tonumber(L, 2));
	lua_pushvalue(L, 1);
	return 1;
}
static int body_get_linear_velocity(lua_State *L)
{
	DORPhysic *p = *(DORPhysic**)auxiliar_checkclass(L, "physic{body}", 1);
	vec2 v = p->getLinearVelocity();
	lua_pushnumber(L, v.x);
	lua_pushnumber(L, v.y);
	return 2;
}
static int body_sleep(lua_State *L)
{
	DORPhysic *p = *(DORPhysic**)auxiliar_checkclass(L, "physic{body}", 1);
	p->sleep(lua_toboolean(L, 2));
	return 0;
}

/******************************************************************
 ** Generic non object functions
 ******************************************************************/
static int gl_dos_count(lua_State *L) {
	lua_pushnumber(L, donb);
	return 1;
}

static int gl_set_pixel_perfect(lua_State *L) {
	DisplayObject::pixel_perfect = lua_toboolean(L, 1);
	return 0;
}

static int gl_set_default_text_shader(lua_State *L) {
	shader_type *shader = (shader_type*)lua_touserdata(L, 1);
	DORText::defaultShader(shader);
	return 0;
}

static int physic_world_gravity(lua_State *L) {
	if (PhysicSimulator::current) {
		PhysicSimulator::current->setGravity(lua_tonumber(L, 1), lua_tonumber(L, 2));
	} else {
		PhysicSimulator *ps = new PhysicSimulator(lua_tonumber(L, 1), lua_tonumber(L, 2));
		ps->use();
	}
	return 0;
}

static int physic_world_raycast(lua_State *L) {
	lua_newtable(L);
	PhysicSimulator::current->rayCast(lua_tonumber(L, 1), lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), (uint16)lua_tonumber(L, 5));
	return 1;
}

static int physic_world_circlecast(lua_State *L) {
	lua_newtable(L);
	PhysicSimulator::current->circleCast(lua_tonumber(L, 1), lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4));
	return 1;
}

static int physic_world_unit_to_pixel(lua_State *L) {
	PhysicSimulator::setUnitScale(lua_tonumber(L, 1));
	return 0;
}

static int physic_world_pause(lua_State *L) {
	PhysicSimulator::current->pause(lua_toboolean(L, 1));
	return 0;
}

static int physic_world_sleep_all(lua_State *L) {
	PhysicSimulator::current->sleepAll(lua_toboolean(L, 1));
	return 0;
}

static int physic_world_set_contact_listener(lua_State *L) {
	if (lua_isfunction(L, 1)) {
		lua_pushvalue(L, 1);
		PhysicSimulator::current->setContactListener(luaL_ref(L, LUA_REGISTRYINDEX));
	} else {
		PhysicSimulator::current->setContactListener(LUA_NOREF);
	}
	return 0;
}

/******************************************************************
 ** Lua declarations
 ******************************************************************/

static const struct luaL_Reg gl_renderer_reg[] =
{
	{"__gc", gl_renderer_free},
	{"zSort", gl_renderer_zsort},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"physicCreate", gl_generic_physic_create},
	{"physicDestroy", gl_generic_physic_destroy},
	{"physic", gl_generic_get_physic},
	{"rawtween", gl_generic_tween},
	{"rawcancelTween", gl_generic_cancel_tween},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"clone", gl_generic_clone},
	{"removeFromParent", gl_generic_remove_from_parent},
	{"add", gl_container_add},
	{"remove", gl_container_remove},
	{"clear", gl_container_clear},
	{"cutoff", gl_renderer_cutoff},
	{"shader", gl_renderer_shader},
	{"enableBlending", gl_renderer_blend},
	{"premultipliedAlpha", gl_renderer_premultiplied_alpha},
	{"setRendererName", gl_renderer_set_name},
	{"countTime", gl_renderer_count_time},
	{"countDraws", gl_renderer_count_draws},
	{"toScreen", gl_renderer_toscreen},
	{NULL, NULL},
};


// Note the is no __gc because we dont actaully manage the object
static const struct luaL_Reg gl_target_posteffects_reg[] =
{
	{"disableAll", gl_target_post_effect_disableall},
	{"enable", gl_target_post_effect_enable},
	{NULL, NULL},
};

static const struct luaL_Reg gl_target_reg[] =
{
	{"__gc", gl_target_free},
	{"toScreen", gl_target_toscreen},
	{"compute", gl_target_compute},
	{"use", gl_target_use},
	{"displaySize", gl_target_displaysize},
	{"clearColor", gl_target_clearcolor},
	{"view", gl_target_view},
	{"texture", gl_target_texture},
	{"textureTarget", gl_target_target_texture},
	{"bloomMode", gl_target_mode_bloom},
	{"bloomMode2", gl_target_mode_bloom2},
	{"blurMode", gl_target_mode_blur},
	{"blurModeDownsampling", gl_target_mode_blur_downsampling},
	{"postEffectsMode", gl_target_mode_posteffects},
	{"shader", gl_target_shader},
	{"setAutoRender", gl_target_set_auto_render},
	{"clear", gl_vertexes_clear},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"physicCreate", gl_generic_physic_create},
	{"physicDestroy", gl_generic_physic_destroy},
	{"physic", gl_generic_get_physic},
	{"rawtween", gl_generic_tween},
	{"rawcancelTween", gl_generic_cancel_tween},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"clone", gl_generic_clone},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_container_reg[] =
{
	{"__gc", gl_container_free},
	{"add", gl_container_add},
	{"remove", gl_container_remove},
	{"clear", gl_container_clear},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"physicCreate", gl_generic_physic_create},
	{"physicDestroy", gl_generic_physic_destroy},
	{"physic", gl_generic_get_physic},
	{"rawtween", gl_generic_tween},
	{"rawcancelTween", gl_generic_cancel_tween},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"clone", gl_generic_clone},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_vertexes_reg[] =
{
	{"__gc", gl_vertexes_free},
	{"reserve", gl_vertexes_reserve},
	{"quad", gl_vertexes_quad},
	{"quadPie", gl_vertexes_quad_pie},
	// {"loadObj", gl_vertexes_load_obj},
	{"texture", gl_vertexes_texture},
	{"textureTarget", gl_vertexes_target_texture},
	{"textureFontAtlas", gl_vertexes_font_atlas_texture},
	{"shader", gl_vertexes_shader},
	{"clear", gl_vertexes_clear},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"physicCreate", gl_generic_physic_create},
	{"physicDestroy", gl_generic_physic_destroy},
	{"physic", gl_generic_get_physic},
	{"rawtween", gl_generic_tween},
	{"rawcancelTween", gl_generic_cancel_tween},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"clone", gl_generic_clone},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_text_reg[] =
{
	{"__gc", gl_text_free},
	{"text", gl_text_set},
	{"shadow", gl_text_shadow},
	{"outline", gl_text_outline},
	{"textColor", gl_text_text_color},
	{"getStats", gl_text_stats},
	{"maxWidth", gl_text_max_width},
	{"maxLines", gl_text_max_lines},
	{"linefeed", gl_text_linefeed},
	{"getLetterPosition", gl_text_get_letter_position},
	{"center", gl_text_center},
	{"shader", gl_text_shader},
	{"clear", gl_vertexes_clear},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"physicCreate", gl_generic_physic_create},
	{"physicDestroy", gl_generic_physic_destroy},
	{"physic", gl_generic_get_physic},
	{"rawtween", gl_generic_tween},
	{"rawcancelTween", gl_generic_cancel_tween},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"clone", gl_generic_clone},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_callback_reg[] =
{
	{"__gc", gl_callback_free},
	{"set", gl_callback_set},
	{"enable", gl_callback_enable},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"physicCreate", gl_generic_physic_create},
	{"physicDestroy", gl_generic_physic_destroy},
	{"physic", gl_generic_get_physic},
	{"rawtween", gl_generic_tween},
	{"rawcancelTween", gl_generic_cancel_tween},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"clone", gl_generic_clone},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_tileobject_reg[] =
{
	{"__gc", gl_tileobject_free},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"physicCreate", gl_generic_physic_create},
	{"physicDestroy", gl_generic_physic_destroy},
	{"physic", gl_generic_get_physic},
	{"rawtween", gl_generic_tween},
	{"rawcancelTween", gl_generic_cancel_tween},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"clone", gl_generic_clone},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_tilemap_reg[] =
{
	{"__gc", gl_tilemap_free},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"physicCreate", gl_generic_physic_create},
	{"physicDestroy", gl_generic_physic_destroy},
	{"physic", gl_generic_get_physic},
	{"rawtween", gl_generic_tween},
	{"rawcancelTween", gl_generic_cancel_tween},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"clone", gl_generic_clone},
	{"removeFromParent", gl_generic_remove_from_parent},
	{"setMap", gl_tilemap_setmap},
	{"setMinimapInfo", gl_tilemap_setminimap_info},
	{NULL, NULL},
};

static const struct luaL_Reg gl_particles_reg[] =
{
	{"__gc", gl_particles_free},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"physicCreate", gl_generic_physic_create},
	{"physicDestroy", gl_generic_physic_destroy},
	{"physic", gl_generic_get_physic},
	{"rawtween", gl_generic_tween},
	{"rawcancelTween", gl_generic_cancel_tween},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"clone", gl_generic_clone},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_staticsub_reg[] =
{
	// No _GC method, this object is fulyl handled C++ side
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"physicCreate", gl_generic_physic_create},
	{"physicDestroy", gl_generic_physic_destroy},
	{"physic", gl_generic_get_physic},
	{"rawtween", gl_generic_tween},
	{"rawcancelTween", gl_generic_cancel_tween},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"clone", gl_generic_clone},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_spriter_reg[] =
{
	{"__gc", gl_spriter_free},
	{"triggerCallback", gl_spriter_trigger_callback},
	{"characterMap", gl_spriter_character_map},
	{"setAnim", gl_spriter_set_anim},
	{"getObjectPosition", gl_spriter_get_object_position},
	{"getKind", gl_generic_getkind},
	{"getColor", gl_generic_color_get},
	{"getTranslate", gl_generic_translate_get},
	{"getRotate", gl_generic_rotate_get},
	{"getScale", gl_generic_scale_get},
	{"getShown", gl_generic_shown_get},
	{"shown", gl_generic_shown},
	{"shader", gl_spriter_shader},
	{"color", gl_generic_color},
	{"resetMatrix", gl_generic_reset_matrix},
	{"physicCreate", gl_generic_physic_create},
	{"physicDestroy", gl_generic_physic_destroy},
	{"physic", gl_generic_get_physic},
	{"rawtween", gl_generic_tween},
	{"rawcancelTween", gl_generic_cancel_tween},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"clone", gl_generic_clone},
	{"removeFromParent", gl_generic_remove_from_parent},
	{NULL, NULL},
};

static const struct luaL_Reg gl_vbo_reg[] =
{
	{"__gc", gl_vbo_free},
	{"shader", gl_vbo_shader},
	{"texture", gl_vbo_texture},
	{"color", gl_vbo_color},
	{"quad", gl_vbo_quad},
	{"clear", gl_vbo_clear},
	{"toScreen", gl_vbo_toscreen},
	{NULL, NULL},
};

static const struct luaL_Reg gl_view_reg[] =
{
	{"__gc", gl_view_free},
	{"ortho", gl_view_ortho},
	{"project", gl_view_project},
	{"use", gl_view_use},
	{NULL, NULL},
};

// Note the is no __gc because we dont actaully manage the object
static const struct luaL_Reg physic_body_reg[] =
{
	{"addFixture", body_add_fixture},
	{"applyForce", body_apply_force},
	{"applyLinearImpulse", body_apply_linear_impulse},
	{"setLinearVelocity", body_apply_set_linear_velocity},
	{"applyTorque", body_apply_torque},
	{"applyAngularImpulse", body_apply_angular_impulse},
	{"getLinearVelocity", body_get_linear_velocity},
	{"sleep", body_sleep},
	{NULL, NULL},
};

const luaL_Reg rendererlib[] = {
	{"renderer", gl_renderer_new},
	{"vertexes", gl_vertexes_new},
	{"text", gl_text_new},
	{"container", gl_container_new},
	{"target", gl_target_new},
	{"callback", gl_callback_new},
	{"spriter", gl_spriter_new},
	{"view", gl_view_new},
	{"vbo", gl_vbo_new},
	{"countDOs", gl_dos_count},
	{"defaultTextShader", gl_set_default_text_shader},
	{"pixelPerfect", gl_set_pixel_perfect},
	{NULL, NULL}
};

const luaL_Reg physicslib[] = {
	{"pause", physic_world_pause},
	{"sleepAll", physic_world_sleep_all},
	{"setContactListener", physic_world_set_contact_listener},
	{"rayCast", physic_world_raycast},
	{"circleCast", physic_world_circlecast},
	{"worldGravity", physic_world_gravity},
	{"worldScale", physic_world_unit_to_pixel},
	{NULL, NULL}
};

int luaopen_renderer(lua_State *L)
{
	auxiliar_newclass(L, "physic{body}", physic_body_reg);
	auxiliar_newclass(L, "gl{renderer}", gl_renderer_reg);
	auxiliar_newclass(L, "gl{vertexes}", gl_vertexes_reg);
	auxiliar_newclass(L, "gl{text}", gl_text_reg);
	auxiliar_newclass(L, "gl{container}", gl_container_reg);
	auxiliar_newclass(L, "gl{target:posteffects}", gl_target_posteffects_reg);
	auxiliar_newclass(L, "gl{target}", gl_target_reg);
	auxiliar_newclass(L, "gl{callback}", gl_callback_reg);
	auxiliar_newclass(L, "gl{tileobject}", gl_tileobject_reg);
	auxiliar_newclass(L, "gl{tilemap}", gl_tilemap_reg);
	auxiliar_newclass(L, "gl{particles}", gl_particles_reg);
	auxiliar_newclass(L, "gl{staticsub}", gl_staticsub_reg);
	auxiliar_newclass(L, "gl{spriter}", gl_spriter_reg);
	auxiliar_newclass(L, "gl{view}", gl_view_reg);
	auxiliar_newclass(L, "gl{vbo}", gl_vbo_reg);
	luaL_openlib(L, "core.renderer", rendererlib, 0);
	luaL_openlib(L, "core.physics", physicslib, 0);

	// Build the weak self store registry
	lua_newtable(L); // new_table={}
	lua_newtable(L); // metatable={}       
	lua_pushliteral(L, "__mode");
	lua_pushliteral(L, "v");
	lua_rawset(L, -3); // metatable._mode='v'
	lua_setmetatable(L, -2); // setmetatable(new_table,metatable)
	DisplayObject::weak_registry_ref = luaL_ref(L, LUA_REGISTRYINDEX);

	init_spriter();

	return 1;
}
