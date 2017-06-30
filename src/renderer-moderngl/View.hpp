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

#ifndef VIEW_HPP
#define VIEW_HPP

#include "renderer-moderngl/Renderer.hpp"

enum class ViewMode { ORTHO, PROJECT };

class DisplayObject;

class View : public IResizable {
private:
	bool in_use = false;
	bool from_screen_size = false;
	ViewMode mode = ViewMode::ORTHO;
	mat4 view;

	mat4 cam;
	int camera_lua_ref = LUA_NOREF;
	DisplayObject *camera_do = NULL;
	int origin_lua_ref = LUA_NOREF;
	DisplayObject *origin_do = NULL;

public:

	View();
	View(int w, int h);
	virtual ~View();

	void setOrthoView(int w, int h, bool reverse_height=true);
	void setProjectView(
		float fov_angle, int w, int h, float near_clip, float far_clip,
		DisplayObject *camera, int camera_ref, DisplayObject *origin, int origin_ref
	);

	void use(bool v);

	mat4 get();

	virtual void onScreenResize(int w, int h);

	static void initFirst();
	static View* getCurrent();
};

#endif
