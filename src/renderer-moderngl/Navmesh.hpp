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
#ifndef NAVMESH_H
#define NAVMESH_H

#include "renderer-moderngl/Renderer.hpp"
#include "renderer-moderngl/Physic.hpp"
#include <cmath>
#include "clipper/clipper.hpp"

struct mesh_triangle {
	vec2 p1, p2, p3;

	float minX() { return fmin(fmin(p1.x, p2.x), p3.x); };
	float maxX() { return fmax(fmax(p1.x, p2.x), p3.x); };
	float minY() { return fmin(fmin(p1.y, p2.y), p3.y); };
	float maxY() { return fmax(fmax(p1.y, p2.y), p3.y); };
};

struct mesh_polygon {
	ClipperLib::Path list;
	// vector<vec2> list;
	bool is_wall;
};

/*************************************************************************
 ** Navmesh building & pathing
 *************************************************************************/
class Navmesh {
protected:
	RendererGL *renderer = NULL;

	b2World *world;

	vec2 getCoords(b2Vec2 bv) { return vec2(bv.x * PhysicSimulator::unit_scale, -bv.y * PhysicSimulator::unit_scale); };
	void extractShapePolygon(b2Body *body, b2PolygonShape *shape);
	void extractShapeChain(b2Body *body, b2ChainShape *shape);
	bool makeNavmesh();

	vector<mesh_polygon> polymesh;
	vector<mesh_triangle> mesh;

	// class dtNavMesh* m_navMesh;
	// class dtNavMeshQuery* m_navQuery;

public:
	Navmesh(b2World *world);
	virtual ~Navmesh();

	bool build();

	void drawDebug(float x, float y);
};

#endif
