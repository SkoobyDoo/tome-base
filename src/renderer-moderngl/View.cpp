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

#include "renderer-moderngl/View.hpp"
#include <stack>

extern "C"{
#include "main.h"
}

static stack<View*> views_stack;

View::View() {
	from_screen_size = true;
	setOrthoView(screen->w / screen_zoom, screen->h / screen_zoom);
}

View::View(int w, int h) {
	setOrthoView(w, h);
}

View::~View() {
	if (in_use) use(false);
}

void View::setOrthoView(int w, int h) {
	mode = ViewMode::ORTHO;
	view = glm::ortho(0.f, (float)w, (float)h, 0.f, -1001.f, 1001.f);
}

void View::onScreenResize(int w, int h) {
	if (!from_screen_size) return;
	printf("View resizing to screen size\n");

	switch (mode) {
		case ViewMode::ORTHO:
			setOrthoView(w, h);
			break;
		default:
			break;
	}
}

void View::use(bool v) {
	in_use = v;
	if (v) {
		views_stack.push(this);
	} else {
		if (views_stack.top() != this) {
			printf("[GL STATE] ERROR VIEW POPED IS NOT THIS\n");
		}
		views_stack.pop();
	}
}

// Make a default screensize orthogonal view, use it and stack it, never removing it so we have a default
void View::initFirst() {
	View *v = new View();
	v->use(true);
}

View* View::getCurrent() {
	if (views_stack.empty()) View::initFirst();
	return views_stack.top();
}
