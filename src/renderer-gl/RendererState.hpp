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

using namespace std;

class RendererState;

class RendererState {
	stack<mat4> saved_worlds;
	stack<mat4> saved_pipe_worlds;
	stack<mat4> saved_views;
	stack<vec4> saved_viewports;
	stack<vec4> cutoffs;
	
public:
	mat4 view;
	mat4 world;
	vec4 viewport;
	mat4 mvp;

	bool quad_pipe_enabled;
	mat4 pipe_world;

	RendererState(int w, int h);
	
	void pushOrthoState(int w, int h);
	void popOrthoState();

	void setViewport(int x, int y, int w, int h);
	void pushViewport();
	void popViewport();

	void pushCutoff(float x, float y, float w, float h);
	void popCutoff();

	void updateMVP(bool include_pipe_world);
	void translate(float x, float y, float z);
	void rotate(float a, float x, float y, float z);
	void scale(float x, float y, float z);
	void pushState(bool isworld);
	void popState(bool isworld);
	void identity(bool isworld);

	void enableQuadPipe(bool v);
};

#endif
