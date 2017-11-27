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
#ifndef _MINIMAP2D_HPP_
#define _MINIMAP2D_HPP_

#include "map/2d/Map2D.hpp"

class Minimap2D : public DORVertexes{
private:
	Map2D *map = nullptr;
	struct {
		int mdx = -9999, mdy = -9999;
		int mdw = 500000, mdh = 500000;
		float transp = 1000;
	} info;
	bool redraw_mm = true;
	bool ready = false;
	bool next_update_full = false;

	GLubyte *mm_data = nullptr;

	virtual void cloneInto(DisplayObject *into);

public:
	Minimap2D();
	virtual ~Minimap2D();
	DO_STANDARD_CLONE_METHOD(Minimap2D);
	virtual const char* getKind() { return "Minimap2D"; };

	virtual void setTexture(GLuint tex, int lua_ref, int id);

	void mapDeath(Map2D *map);
	void setMap(Map2D *map);
	void redrawMiniMap();
	void setMinimapInfo(int mdx, int mdy, int mdw, int mdh, float transp);
};


#endif
