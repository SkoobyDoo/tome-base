/*
	TE4 - T-Engine 4
	Copyright (C) 2009 - 2018 Nicolas Casalini

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
#ifndef _LUACOLORS_H_
#define _LUACOLORS_H_

extern "C" {
#include "auxiliar.h"
}

template<class T>shared_ptr<T>* lua_get_sobj_ptr(lua_State *L, const char *classname, int id) {
	return *(shared_ptr<T>**)auxiliar_checkclass(L, classname, id);
}
template<class T>shared_ptr<T> lua_get_sobj(lua_State *L, const char *classname, int id) {
	return **(shared_ptr<T>**)auxiliar_checkclass(L, classname, id);
}
template<class T>T* lua_get_sobj_get(lua_State *L, const char *classname, int id) {
	return (*(shared_ptr<T>**)auxiliar_checkclass(L, classname, id))->get();
}
template<class T>T* lua_make_sobj(lua_State *L, const char *classname, T* t) {
	shared_ptr<T> **pobj = (shared_ptr<T>**)lua_newuserdata(L, sizeof(shared_ptr<T>*));
	auxiliar_setclass(L, classname, -1);
	*pobj = new shared_ptr<T>(t);
	return t;
}

#endif
