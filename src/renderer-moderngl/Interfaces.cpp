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
}
#include "renderer-moderngl/Renderer.hpp"

#include <set>

static set<IResizable*> to_resize_list;
static set<IRealtime*> realtime_list;
static bool realtime_executing = false;

IResizable::IResizable() {
	to_resize_list.insert(this);
}

IResizable::~IResizable() {
	to_resize_list.erase(this);
}

void interface_resize(int w, int h) {
	for (auto& it : to_resize_list) {
		it->onScreenResize(w, h);
	}
}

IRealtime::IRealtime() {
	realtime_list.insert(this);
}

IRealtime::~IRealtime() {
	realtime_list.erase(this);
}

void IRealtime::killMe() {
	// If we are in the loop, we take some extra care
	if (realtime_executing) {
		dying = true;
	} else {
		delete this;
	}
}

void interface_realtime(int nb_keyframes) {
	realtime_executing = true;
	for (auto it = realtime_list.begin(); it != realtime_list.end();) {
		(*it)->onKeyframe(nb_keyframes);
		if ((*it)->dying) {
			IRealtime *old = *it;
			it = realtime_list.erase(it);
			delete old;
		} else {
			++it;
		}
	}
	realtime_executing = false;
}
