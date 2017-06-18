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
#include <unordered_map>
#include <unordered_set>
#include "clipper/clipper.hpp"

struct mesh_point {
	uint32_t x, y;
	inline bool operator==(const mesh_point &p2) const { return x == p2.x && y == p2.y; };
};

// Overload hash for points
namespace std {
	template <> struct hash<mesh_point> {
		std::size_t operator()(const mesh_point& p) const {
			size_t res = 17;
			res = res * 31 + hash<int>()( p.x );
			res = res * 31 + hash<int>()( p.y );
			return res;
		}
	};
};

struct mesh_edge {
	mesh_point p1, p2;
	vector<int> links;
	mesh_edge(mesh_point p1, mesh_point p2) : p1(p1), p2(p2) {};
	inline bool operator==(const mesh_edge &e2) const { return (p1 == e2.p1 && p2 == e2.p2) || (p1 == e2.p2 && p2 == e2.p1); };
};
typedef shared_ptr<mesh_edge> sp_mesh_edge;

// Overload hash & equal_to to make them work on the actual edge and not just smart pointer
namespace std {
	template <> struct hash<sp_mesh_edge> {
		std::size_t operator()(const sp_mesh_edge& e) const {
			size_t res = 17;
			uint32_t c1 = e->p1.y * 65536 + e->p1.x;
			uint32_t c2 = e->p2.y * 65536 + e->p2.x;
			if (c2 < c1) std:swap(c1, c2);
			res = res * 31 + hash<int>()( c1 );
			res = res * 31 + hash<int>()( c2 );
			return res;
		}
	};
	template <> struct equal_to<sp_mesh_edge> {
		bool operator()(const sp_mesh_edge& e1, const sp_mesh_edge& e2) const {
			return (*e1) == (*e2);
		}
	};
};

struct mesh_triangle {
	int id;
	mesh_point p1, p2, p3;
	array<sp_mesh_edge, 3> edges;
	unordered_map<int, uint32_t> links;
	mesh_point center;

	mesh_triangle(mesh_point p1, mesh_point p2, mesh_point p3, int id) : p1(p1), p2(p2), p3(p3), id(id) {
		edges[0] = make_shared<mesh_edge>(p1, p2);
		edges[1] = make_shared<mesh_edge>(p2, p3);
		edges[2] = make_shared<mesh_edge>(p3, p1);
		center.x = (p1.x + p2.x + p3.x) / 3;
		center.y = (p1.y + p2.y + p3.y) / 3;
	};
	uint32_t minX() { return fmin(fmin(p1.x, p2.x), p3.x); };
	uint32_t maxX() { return fmax(fmax(p1.x, p2.x), p3.x); };
	uint32_t minY() { return fmin(fmin(p1.y, p2.y), p3.y); };
	uint32_t maxY() { return fmax(fmax(p1.y, p2.y), p3.y); };
	void print() { printf("_triangle_ %d : %dx%d, %dx%d, %dx%d; center (%dx%d)\n", id, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, center.x, center.y); };
};
typedef shared_ptr<mesh_triangle> sp_mesh_triangle;

struct mesh_polygon {
	ClipperLib::Path list;
	// vector<vec2> list;
	bool is_wall;
};

struct mesh_path_data {
	sp_mesh_triangle parent;
	uint32_t g_cost;
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
	bool makeNavmesh(int radius);
	bool makeNavmeshRecast(int radius);

	vector<mesh_polygon> polymesh;
	vector<sp_mesh_triangle> mesh;
	unordered_map<mesh_point, vector<mesh_point>> mesh_points_graph;
	uint32_t min_x, max_x, min_y, max_y;

	vector<sp_mesh_triangle> last_path;

	class dtNavMesh* m_navMesh;
	class dtNavMeshQuery* m_navQuery;

public:
	Navmesh(b2World *world);
	virtual ~Navmesh();

	bool build();
	bool isInTriangle(uint32_t x, uint32_t y, int triid);
	int findTriangle(uint32_t x, uint32_t y);
	bool pathFind(vector<mesh_point> &path, mesh_point &start, mesh_point &end);

	void drawDebug(float x, float y);
};

#endif
