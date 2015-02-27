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

#ifndef RENDERER_STATE_H
#define RENDERER_STATE_H

#include <stack>

class RendererState {
	glm::mat4 view;
	glm::mat4 world;
	std::stack<glm::mat4> saved_worlds;
	std::stack<glm::mat4> saved_views;
	
public:
	glm::mat4 mvp;

	RendererState(int w, int h);
	void updateMVP();
	void translate(float x, float y, float z);
	void rotate(float a, float x, float y, float z);
	void scale(float x, float y, float z);
	void pushState(bool isworld);
	void popState(bool isworld);
	void identity(bool isworld);
};

#endif
