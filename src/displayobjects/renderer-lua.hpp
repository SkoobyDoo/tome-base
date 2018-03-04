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

#ifndef RENDERER_LUA_HPP
#define RENDERER_LUA_HPP

extern int gl_generic_getkind(lua_State *L);
extern int gl_generic_clone(lua_State *L);
extern int gl_generic_color_get(lua_State *L);
extern int gl_generic_color(lua_State *L);
extern int gl_generic_translate_get(lua_State *L);
extern int gl_generic_rotate_get(lua_State *L);
extern int gl_generic_scale_get(lua_State *L);
extern int gl_generic_shown_get(lua_State *L);
extern int gl_generic_physic_create(lua_State *L);
extern int gl_generic_physic_destroy(lua_State *L);
extern int gl_generic_get_physic(lua_State *L);
extern int gl_generic_tween(lua_State *L);
extern int gl_generic_cancel_tween(lua_State *L);
extern int gl_generic_has_tween(lua_State *L);
extern int gl_generic_translate(lua_State *L);
extern int gl_generic_rotate(lua_State *L);
extern int gl_generic_scale(lua_State *L);
extern int gl_generic_reset_matrix(lua_State *L);
extern int gl_generic_shown(lua_State *L);
extern int gl_generic_remove_from_parent(lua_State *L);

#define INJECT_GENERIC_DO_METHODS \
	{"getKind", gl_generic_getkind}, \
	{"getColor", gl_generic_color_get}, \
	{"getTranslate", gl_generic_translate_get}, \
	{"getRotate", gl_generic_rotate_get}, \
	{"getScale", gl_generic_scale_get}, \
	{"getShown", gl_generic_shown_get}, \
	{"shown", gl_generic_shown}, \
	{"color", gl_generic_color}, \
	{"resetMatrix", gl_generic_reset_matrix}, \
	{"physicCreate", gl_generic_physic_create}, \
	{"physicDestroy", gl_generic_physic_destroy}, \
	{"physic", gl_generic_get_physic}, \
	{"rawtween", gl_generic_tween}, \
	{"rawcancelTween", gl_generic_cancel_tween}, \
	{"rawhasTween", gl_generic_has_tween}, \
	{"translate", gl_generic_translate}, \
	{"rotate", gl_generic_rotate}, \
	{"scale", gl_generic_scale}, \
	{"clone", gl_generic_clone}, \
	{"removeFromParent", gl_generic_remove_from_parent}, \


#endif
