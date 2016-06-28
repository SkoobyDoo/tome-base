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

#ifndef VIEW_HPP
#define VIEW_HPP

#include "renderer-moderngl/Renderer.hpp"

enum class ViewMode { ORTHO };

class View : public IResizable {
private:
	bool in_use = false;
	bool from_screen_size = false;
	ViewMode mode = ViewMode::ORTHO;

public:
	mat4 view;

	View();
	View(int w, int h);
	virtual ~View();

	void setOrthoView(int w, int h);

	void use(bool v);

	virtual void onScreenResize(int w, int h);

	static void initFirst();
	static View* getCurrent();
};

#endif
