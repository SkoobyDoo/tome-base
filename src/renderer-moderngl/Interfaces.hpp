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
#ifndef DO_INTERFACES_H
#define DO_INTERFACES_H

extern "C" {
#include "tgl.h"
#include "useshader.h"
#include "font.h"
}

#include <vector>

#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"
#include "glm/ext.hpp"

using namespace glm;
using namespace std;

class IResizable {
public:
	IResizable();
	virtual ~IResizable();
	virtual void onScreenResize(int w, int h) = 0;
};

extern "C" void interface_resize(int w, int h);

class IRealtime {
public:
	IRealtime();
	virtual ~IRealtime();
	virtual void onKeyframe(int nb_keyframes) = 0;
};

extern "C" void interface_realtime(int nb_keyframes);

#endif
