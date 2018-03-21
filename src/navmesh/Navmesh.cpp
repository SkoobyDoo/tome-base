/*
	TE4 - T-Engine 4
	Copyright (C) 2009 - 2018 Nicolas Casalini

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

#include "poly2tri/poly2tri.h"
#include "navmesh/Navmesh.hpp"

Navmesh::Navmesh(b2World *world, int radius) : world(world), radius(radius) {
}

Navmesh::~Navmesh() {
}

void Navmesh::extractShapePolygon(b2Body *body, b2PolygonShape *shape) {
	vec2 center = getCoords(body->GetWorldCenter());
	int nb = shape->GetVertexCount();
	mesh_polygon poly; poly.list.reserve(nb);
	for (int i = 0; i < nb; i++) {
		vec2 v = getCoords(shape->GetVertex(i)) + center;
		poly.list.push_back({(ClipperLib::cInt)v.x, (ClipperLib::cInt)v.y});
	}
	DORPhysic *physic = ((DisplayObject*)body->GetUserData())->getPhysic(0);
	poly.is_wall = physic->getUserKind() == PhysicUserKind::WALL;
	polymesh.push_back(poly);
}

template <class C> void FreeClear( C & cntr ) {
	for ( typename C::iterator it = cntr.begin(); it != cntr.end(); ++it ) {
		delete * it;
	}
	cntr.clear();
}

void Navmesh::extractShapeChain(b2Body *body, b2ChainShape *shape) {
	vec2 center = getCoords(body->GetWorldCenter());
	int nb = shape->m_count;
	mesh_polygon poly; poly.list.reserve(nb);
	for (int i = 0; i < nb; i++) {
		if ((i == nb - 1) && (shape->m_vertices[0].x == shape->m_vertices[i].x) && (shape->m_vertices[0].y == shape->m_vertices[i].y)) {
			printf("Loop detected, ignoring last point\n");
			continue;
		}
		vec2 v = getCoords(shape->m_vertices[i]) + center;
		poly.list.push_back({(ClipperLib::cInt)v.x, (ClipperLib::cInt)v.y});
	}
	DORPhysic *physic = ((DisplayObject*)body->GetUserData())->getPhysic(0);
	poly.is_wall = physic->getUserKind() == PhysicUserKind::WALL;
	polymesh.push_back(poly);
}

bool Navmesh::build() {
	int nb_bodies = 0;
	// Parse the static (only) bodies, extract shapes and extrapolate trinagles from them
	for (b2Body* b = world->GetBodyList(); b; b = b->GetNext()) { if (b->GetType() == b2_staticBody) {
		for (b2Fixture* f = b->GetFixtureList(); f; f = f->GetNext()) {
			b2Shape *shape = f->GetShape();
			switch (shape->GetType()) {
				case b2Shape::Type::e_polygon: {
					extractShapePolygon(b, dynamic_cast<b2PolygonShape*>(shape));
					break;
				}
				case b2Shape::Type::e_chain: {
					extractShapeChain(b, dynamic_cast<b2ChainShape*>(shape));
					break;
				}
			}
			nb_bodies++;
		}
	} }

	// With the triangles compute the navmesh
	printf("Navmesh building with agent size %d from %d static bodies...\n", radius, nb_bodies);
	makeNavmesh();
	printf("Navmesh done\n");
	// exit(1);
	return true;
}

static inline int32_t sign(const mesh_point &p1, const mesh_point &p2, const mesh_point &p3) {
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
}

static inline bool point_in_triangle(const mesh_point &pt, const mesh_point &v1, const mesh_point &v2, const mesh_point &v3) {
	bool b1, b2, b3;
	b1 = sign(pt, v1, v2) < 0;
	b2 = sign(pt, v2, v3) < 0;
	b3 = sign(pt, v3, v1) < 0;
	return ((b1 == b2) && (b2 == b3));
}

static inline int32_t get_triangle_area2(const mesh_point &p1, const mesh_point &p2, const mesh_point &p3) {
	const int32_t ax = p2.x - p1.x;
	const int32_t ay = p2.y - p1.y;
	const int32_t bx = p3.x - p1.x;
	const int32_t by = p3.y - p1.y;
	return bx*ay - ax*by;
}


bool Navmesh::makeNavmesh() {
	ClipperLib::Clipper clpr;

	// Expand the polymesh based on actor size
	vector<mesh_polygon> polymesh_expanded;
	min_x = 999999; max_x = 0; min_y = 999999; max_y = 0;
	for (auto &poly : polymesh) {
		if (ClipperLib::Orientation(poly.list)) ClipperLib::ReversePath(poly.list);
		ClipperLib::Paths solutions;
		ClipperLib::ClipperOffset co;
		co.AddPath(poly.list, ClipperLib::jtMiter, ClipperLib::etClosedPolygon);
		co.Execute(solutions, poly.is_wall ? radius : -radius);
		for (auto &path : solutions) {
			polymesh_expanded.push_back({path, poly.is_wall});
			for (auto &it : path) {
				if (it.X > max_x) max_x = it.X;
				else if (it.X < min_x) min_x = it.X;
				if (it.Y > max_y) max_y = it.Y;
				else if (it.Y < min_y) min_y = it.Y;
			}
		}
	}
	printf("Navmesh bounds: %dx%d to %dx%d\n", min_x, min_y, max_x, max_y);

	vector<p2t::Point*> steiners;
	for (uint32_t x = min_x; x < max_x; x += 150) {
		for (uint32_t y = min_y; y < max_y; y += 150) {
			p2t::Point *p = new p2t::Point(x, y);
			steiners.push_back(p);
		}
	}

	unordered_set<sp_mesh_edge> edges;

	// For each area (!wall), extrude the walls from it and make triangles
	// Add those triangles to the global list of triangles and find their common edges
	for (auto &poly : polymesh_expanded) { if (!poly.is_wall) {
		ClipperLib::Clipper clpr;
		clpr.AddPath(poly.list, ClipperLib::ptSubject, true);
		for (auto &poly : polymesh_expanded) { if (poly.is_wall) {
			clpr.AddPath(poly.list, ClipperLib::ptClip , true);
		} }
		ClipperLib::Paths solution;
		if (!clpr.Execute(ClipperLib::ctDifference, solution, ClipperLib::pftEvenOdd, ClipperLib::pftEvenOdd)) continue;
		printf("[NAVMESH] clipper solutions: %ld\n", solution.size());
		if (!solution.size()) continue;

		// Convert clipper data format to poly2tri data format
		vector<vector<p2t::Point*>> polylines;
		for (auto &path : solution) {
			vector<p2t::Point*> vertices;
			vertices.reserve(path.size());
			for (auto &point : path) vertices.push_back(new p2t::Point({(double)point.X, (double)point.Y}));
			polylines.push_back(vertices);
		}

		// Triangulate the polygon
		p2t::CDT cdt(polylines[0]);
		// Add the holes
		for (int i = 1; i < polylines.size(); i++) cdt.AddHole(polylines[i]);
		// Add steiner points to split up more equaly
		// for (auto point : steiners) {
		// 	// mesh_point pt(point.x, point.y);

		// 	cdt.AddPoint(point);
		// }

		cdt.Triangulate();
		vector<p2t::Triangle*> triangles = cdt.GetTriangles();

		// Store triangles and find edges
		for (auto &tri : triangles) {
			p2t::Point *p1 = tri->GetPoint(0);
			p2t::Point *p2 = tri->GetPoint(1);
			p2t::Point *p3 = tri->GetPoint(2);
			sp_mesh_triangle mtri = make_shared<mesh_triangle>((mesh_point){(uint32_t)p1->x, (uint32_t)p1->y}, (mesh_point){(uint32_t)p2->x, (uint32_t)p2->y}, (mesh_point){(uint32_t)p3->x, (uint32_t)p3->y}, mesh.size() + 1);
			mesh.push_back(mtri);

			for (auto edge : mtri->edges) {
				auto it = edges.find(edge);
				if (it != edges.end()) {
					// printf("  - Edge %dx%d :: %dx%d already existing, adding tri %d\n", edge->p1.x, edge->p1.y, edge->p2.x, edge->p2.y, mtri->id);
					(*it)->links.push_back(mtri->id);
				} else {
					// printf("  - Edge %dx%d :: %dx%d is new, setting tri %d\n", edge->p1.x, edge->p1.y, edge->p2.x, edge->p2.y, mtri->id);
					edges.insert(edge);
					edge->links.push_back(mtri->id);
				}
			}
		}
		for (auto &vertices : polylines) FreeClear(vertices);
		// FreeClear(triangles);
	} }

	for (auto edge : edges) {
		// printf("Edge (%dx%d)x(%dx%d) has:\n", edge->p1.x, edge->p1.y, edge->p2.x, edge->p2.y);
		// for (auto tid : edge->links) {
		// 	printf("  - %d\n", tid);
		// }
		if (edge->links.size() == 2) {
			sp_mesh_triangle tri1 = mesh[edge->links[0]-1];
			sp_mesh_triangle tri2 = mesh[edge->links[1]-1];
			float distance = sqrt(pow((float)tri1->center.x - (float)tri2->center.x, 2) + pow((float)tri1->center.y - (float)tri2->center.y, 2));
			tri1->links.insert(make_pair<int, tuple<uint32_t, sp_mesh_edge>>((int)edge->links[1], make_tuple((float)distance, edge)));
			tri2->links.insert(make_pair<int, tuple<uint32_t, sp_mesh_edge>>((int)edge->links[0], make_tuple((float)distance, edge)));
			// printf("Linking tri %d to %d with distance %f\n", tri1->id, tri2->id, distance);
		} else if (edge->links.size() == 0) {
			printf("[NAVMESH] ERROR: triangle edge with 0 neighbours!\n");
		} else if (edge->links.size() > 2) {
			printf("[NAVMESH] ERROR: triangle edge with more than 2 neighbours (%ld)!\n", edge->links.size());
		}
	}

	// Now we have triangles, find neighbours
	for (auto tri : mesh) {
		// printf("Triangle %d linked to\n", tri->id);
		// for (auto it : tri->links) printf(" - %d (%d) by edge (%dx%d) (%dx%d)\n", it.first, get<0>(it.second), get<1>(it.second)->p1.x, get<1>(it.second)->p1.y, get<1>(it.second)->p2.x, get<1>(it.second)->p2.y);

		// Make unique points
		array<mesh_point, 3> points = {tri->p1, tri->p2, tri->p3};
		int id = 0;
		for (auto point : points) {
			bool found = false;
			for (auto ap : all_points) if (ap->x == point.x && ap->y == point.y) {
				found = true;
				tri->points[id] = ap;
				ap->tri_ids.insert(tri->id);
				break;
			}
			if (!found) {
				sp_mesh_point_unique p = make_shared<mesh_point_unique>(point.x, point.y, all_points.size() +1);
				p->tri_ids.insert(tri->id);
				tri->points[id] = p;
				all_points.push_back(p);
			}
			id++;
		}

		// Now that we have unicity, find neighbours
		// for (auto point : tri->points) {
		// 	auto it = points_neighbours.find(point);
		// 	if (it == points_neighbours.end()) {
		// 		points_neighbours.emplace(point, new unordered_map<sp_mesh_point_unique, uint32_t>);
		// 		it = points_neighbours.find(point);
		// 	}
		// 	for (auto op : tri->points) {
		// 		if (op != point) {
		// 			float distance = sqrt(pow((float)point->x - (float)op->x, 2) + pow((float)point->y - (float)op->y, 2));
		// 			it->second->insert({(sp_mesh_point_unique)op, (uint32_t)distance});
		// 		}
		// 	}
		// }
	}

	// for (auto up : all_points) {
	// 	printf("! point %d, (%dx%d)\n", up->id, up->x, up->y);
	// 	auto it = points_neighbours.find(up);
	// 	if (it != points_neighbours.end()) {
	// 		for (auto cp : *it->second) {
	// 			printf("  - connect to point %d, (%dx%d)\n", cp.first->id, cp.first->x, cp.first->y);
	// 		}
	// 	}
	// }

	return true;
}

bool Navmesh::isInTriangle(uint32_t x, uint32_t y, int triid) {
	if (triid > mesh.size() || triid < 1) return false;
	sp_mesh_triangle tri = mesh[triid-1];
	return point_in_triangle({x, y}, tri->p1, tri->p2, tri->p3);
}

int Navmesh::findTriangle(uint32_t x, uint32_t y) {
	mesh_point p = {x, y};
	// printf("TEST %dx%d\n", x, y);
	for (auto tri : mesh) {
		// point_in_triangle(p, tri->p1, tri->p2, tri->p3);
		if (point_in_triangle(p, tri->p1, tri->p2, tri->p3)) return tri->id;
	}
	return 0;
}

static inline uint32_t heuristic(mesh_point &from, mesh_point &to) {
	// // Chebyshev distance
	// int32_t h = fmax(fabs(from.x - end.x), fabs(from.y - end.y));

	// // tie-breaker rule for straighter paths
	// int32_t dx1 = end.x - from.x;
	// int32_t dy1 = end.y - from.y;
	// int32_t dx2 = start.x - from.x;
	// int32_t dy2 = start.y - from.y;
	// return h + 0.01 * fabs(dx1*dy2 - dx2*dy1);

	float distance = sqrt(pow((float)from.x - (float)to.x, 2) + pow((float)from.y - (float)to.y, 2));
	return distance;
}

// Mostly useless
// bool Navmesh::pathFindByEdge(vector<mesh_point> &path, mesh_point &start, mesh_point &end) {
// 	int tri_start_id = findTriangle(start.x, start.y);
// 	int tri_end_id = findTriangle(end.x, end.y);
// 	if (!tri_start_id || !tri_end_id) { printf("[NAVMESH] pathFind start or stop triangle is unfound: %d, %d\n", tri_start_id, tri_end_id); return false; }
// 	printf("Starting pathfind from %dx%d (triangle %d) to %dx%d (triangle %d)\n", start.x, start.y, tri_start_id, end.x, end.y, tri_end_id);

// 	sp_mesh_triangle tri_start = mesh[tri_start_id-1];
// 	sp_mesh_triangle tri_end = mesh[tri_end_id-1];

// 	// Woot, easy we are already in the same triangle
// 	if (tri_start == tri_end) { path.push_back(end); return true; }

// 	sp_mesh_point_unique pstart = make_shared<mesh_point_unique>(start, -1);
// 	sp_mesh_point_unique pend = make_shared<mesh_point_unique>(end, -2);

// 	unordered_set<sp_mesh_point_unique> closed;
// 	unordered_map<sp_mesh_point_unique, mesh_path_data> open;
// 	unordered_map<sp_mesh_point_unique, sp_mesh_point_unique> came_from;

// 	for (auto p : tri_start->points) {
// 		float distance = sqrt(pow((float)p->x - (float)pstart->x, 2) + pow((float)p->y - (float)pstart->y, 2));
// 		open.insert({p, {(uint32_t)distance}});
// 		came_from[p] = pstart;
// 	}

// 	while (true) {
// 		uint32_t lowest = 999999;
// 		sp_mesh_point_unique node;
// 		for (auto &it : open) {
// 			if (it.second.g_cost < lowest) {
// 				node = it.first;
// 				lowest = it.second.g_cost;
// 			}
// 		}
// 		printf("Using open : %d with cost %d\n", node->id, lowest);

// 		if (node->tri_ids.find(tri_end_id) != node->tri_ids.end()) {
// 			last_path.clear();
// 			printf("Found route!\n");
// 			last_path.push_back(end);
// 			while (node != pstart) {
// 				last_path.push_back({node->x, node->y});
// 				node = came_from[node];
// 			}
// 			last_path.push_back(start);
// 			std::reverse(last_path.begin(), last_path.end());
// 			return true;
// 		}

// 		closed.insert(node);
// 		open.erase(node);

// 		auto it  = points_neighbours.find(node);
// 		if (it != points_neighbours.end()) {
// 			for (auto ntest : *it->second) {
// 				if (closed.find(ntest.first) == closed.end()) {
// 					mesh_point np = node->get();
// 					mesh_point p = ntest.first->get();
// 					open.insert({ntest.first, {(uint32_t)lowest + heuristic(np, p)}});
// 					came_from[ntest.first] = node;
// 				}
// 			}
// 		}

// 		// break;
// 	}
// 	return false;
// }

static inline int32_t get_winding(mesh_point &p1, mesh_point &p2, mesh_point &test) {
	return (p2.x - p1.x) * (test.y - p1.y) - (p2.y - p1.y) * (test.x - p1.x);
}

bool Navmesh::pathFindByTriangle(mesh_point &start, mesh_point &end, int &tri_start_id, int &tri_end_id, vector<mesh_point> &path) {
	tri_start_id = findTriangle(start.x, start.y);
	tri_end_id = findTriangle(end.x, end.y);
	if (!tri_start_id || !tri_end_id) { printf("[NAVMESH] pathFind start or stop triangle is unfound: %d, %d\n", tri_start_id, tri_end_id); return false; }
	// printf("Starting pathfind from %dx%d (triangle %d) to %dx%d (triangle %d)\n", start.x, start.y, tri_start_id, end.x, end.y, tri_end_id);

	sp_mesh_triangle tri_start = mesh[tri_start_id-1];
	sp_mesh_triangle tri_end = mesh[tri_end_id-1];

	// Woot, easy we are already in the same triangle
	if (tri_start == tri_end) { path.push_back(end); return true; }

	unordered_set<sp_mesh_triangle> closed;
	unordered_map<sp_mesh_triangle, mesh_path_data> open;
	unordered_map<sp_mesh_triangle, tuple<sp_mesh_triangle, sp_mesh_edge>> came_from;

	open.insert({tri_start, {0}});
	came_from[tri_start] = make_tuple(tri_start, nullptr);

	vector<sp_mesh_edge> portals;

	while (true) {
		uint32_t lowest = 999999;
		sp_mesh_triangle node;
		for (auto &it : open) {
			if (it.second.g_cost < lowest) {
				node = it.first;
				lowest = it.second.g_cost;
			}
		}
		// printf("Using open : %d with cost %d\n", node->id, lowest);

		if (node == tri_end) {
			sp_mesh_triangle rnode = node;
			// printf("Found route!\n");
			portals.push_back(make_shared<mesh_edge>(end, end));
			// portals.push_back(make_shared<mesh_edge>(tri_end->center, tri_end->center));
			sp_mesh_triangle next = nullptr;
			if (debug) test_color.clear();
			while (node != tri_start) {
				next = get<0>(came_from[node]);
				// if (node != tri_end) {
					sp_mesh_edge edge = get<1>(came_from[node]);
					if (get_winding(next->center, node->center, edge->p1) < 0) edge = make_shared<mesh_edge>(edge->p2, edge->p1);
					portals.push_back(edge);

					if (debug) {
						test_color.push_back(make_tuple<uint32_t, uint32_t, uint32_t, uint32_t, vec4>((uint32_t)next->center.x, (uint32_t)next->center.y, (uint32_t)edge->p1.x, (uint32_t)edge->p1.y, vec4(0.5, 0.5, 1, 1)));
						test_color.push_back(make_tuple<uint32_t, uint32_t, uint32_t, uint32_t, vec4>((uint32_t)next->center.x, (uint32_t)next->center.y, (uint32_t)edge->p2.x, (uint32_t)edge->p2.y, vec4(0.5, 1, 0.5, 1)));
					}
				// }
				node = next;
			}
			// portals.push_back(make_shared<mesh_edge>(tri_start->center, tri_start->center));
			portals.push_back(make_shared<mesh_edge>(start, start));
			std::reverse(portals.begin(), portals.end());

			// DEBUG
			if (debug) {
				node = rnode;		
				last_apath.clear();
				last_apath.push_back(end);
				while (node != tri_start) {
					if (node != tri_end) last_apath.push_back(node->center);
					node = get<0>(came_from[node]);
				}
				last_apath.push_back(start);
				std::reverse(last_apath.begin(), last_apath.end());
			}

			// Smooth the path
			simpleStupidFunnel(portals, path);
			return true;
		}

		closed.insert(node);
		open.erase(node);

		for (auto &link : node->links) {
			sp_mesh_triangle ntest = mesh[link.first-1];
			if (closed.find(ntest) == closed.end()) {
				// open.insert({ntest, {lowest + get<0>(link.second)}});
				open.insert({ntest, {lowest + heuristic(node->center, ntest->center)}});
				came_from[ntest] = make_tuple(node, get<1>(link.second));
			}
		}
	}
	return false;
}

// Based on http://digestingduck.blogspot.fr/2010/03/simple-stupid-funnel-algorithm.html
void Navmesh::simpleStupidFunnel(vector<sp_mesh_edge> &portals, vector<mesh_point> &path) {
	// Init scan state
	path.clear();
	mesh_point portalApex, portalLeft, portalRight;
	int apexIndex = 0, leftIndex = 0, rightIndex = 0;
	portalApex = portals[0]->p1;
	portalLeft = portals[0]->p1;
	portalRight = portals[0]->p2;

	// Add start point.
	// path.push_back(portalApex);

	for (int i = 1; i < portals.size(); ++i) {
		mesh_point &left = portals[i]->p1;
		mesh_point &right = portals[i]->p2;

		// Update right vertex.
		if (get_triangle_area2(portalApex, portalRight, right) <= 0.0f) {
			if ((portalApex == portalRight) || get_triangle_area2(portalApex, portalLeft, right) > 0.0f) {
				// Tighten the funnel.
				portalRight = right;
				rightIndex = i;
			} else {
				// Right over left, insert left to path and restart scan from portal left point.
				path.push_back(portalLeft);
				// Make current left the new apex.
				portalApex = portalLeft;
				apexIndex = leftIndex;
				// Reset portal
				portalLeft = portalApex;
				portalRight = portalApex;
				leftIndex = apexIndex;
				rightIndex = apexIndex;
				// Restart scan
				i = apexIndex;
				continue;
			}
		}

		// Update left vertex.
		if (get_triangle_area2(portalApex, portalLeft, left) >= 0.0f) {
			if ((portalApex == portalLeft) || get_triangle_area2(portalApex, portalRight, left) < 0.0f) {
				// Tighten the funnel.
				portalLeft = left;
				leftIndex = i;
			} else {
				// Left over right, insert right to path and restart scan from portal right point.
				path.push_back(portalRight);
				// Make current right the new apex.
				portalApex = portalRight;
				apexIndex = rightIndex;
				// Reset portal
				portalLeft = portalApex;
				portalRight = portalApex;
				leftIndex = apexIndex;
				rightIndex = apexIndex;
				// Restart scan
				i = apexIndex;
				continue;
			}
		}
	}
	
	// Append last point to path.
	path.push_back(portals[portals.size()-1]->p1);

	// Debug draw
	if (debug) {
		last_path.clear();
		last_path.push_back(portals[0]->p1);
		last_path.insert(last_path.end(), path.begin(), path.end());
	}
}

extern int gl_tex_white;
void Navmesh::drawDebug(float x, float y) {
	if (!renderer) { 
		renderer = new RendererGL(VBOMode::STREAM);
		char *name = strdup("navmesh debug renderer");
		renderer->setRendererName(name, false);
		renderer->setManualManagement(true);
	}

	renderer->resetDisplayLists();
	renderer->setChanged(true);

	auto dl = getDisplayList(renderer, {(GLuint)gl_tex_white, 0, 0}, NULL, VERTEX_MAP_INFO, RenderKind::TRIANGLES);
	for (auto tri : mesh) {
		vertex v1{{tri->p1.x, tri->p1.y, 0, 1}, {0, 0}, {0, 1, 0.5, 0.5}};
		vertex v2{{tri->p2.x, tri->p2.y, 0, 1}, {0, 0}, {0, 1, 0.5, 0.5}};
		vertex v3{{tri->p3.x, tri->p3.y, 0, 1}, {0, 0}, {0, 1, 0.5, 0.5}};
		dl->list.push_back(v1);
		dl->list.push_back(v2);
		dl->list.push_back(v3);
	}

	dl = getDisplayList(renderer, {(GLuint)gl_tex_white, 0, 0}, NULL, VERTEX_MAP_INFO, RenderKind::LINES);
	for (auto tri : mesh) {
		vertex v1{{tri->p1.x, tri->p1.y, 0, 1}, {0, 0}, {0, 1, 1, 1}};
		vertex v2{{tri->p2.x, tri->p2.y, 0, 1}, {0, 0}, {0, 1, 1, 1}};
		vertex v3{{tri->p3.x, tri->p3.y, 0, 1}, {0, 0}, {0, 1, 1, 1}};
		dl->list.push_back(v1); dl->list.push_back(v2);
		dl->list.push_back(v2); dl->list.push_back(v3);
		dl->list.push_back(v3); dl->list.push_back(v1);
	}

	// Path
	for (int i = 1; i < last_apath.size(); i++) {
		mesh_point p1 = last_apath[i-1];
		mesh_point p2 = last_apath[i];

		vertex v1{{p1.x, p1.y, 0, 1}, {0, 0}, {1, 1, 0, 1}};
		vertex v2{{p2.x, p2.y, 0, 1}, {0, 0}, {1, 1, 0, 1}};
		dl->list.push_back(v1); dl->list.push_back(v2);
	}
	// Path
	for (int i = 1; i < last_path.size(); i++) {
		mesh_point p1 = last_path[i-1];
		mesh_point p2 = last_path[i];

		vertex v1{{p1.x, p1.y, 0, 1}, {0, 0}, {1, 0, 0, 1}};
		vertex v2{{p2.x, p2.y, 0, 1}, {0, 0}, {1, 0, 0, 1}};
		dl->list.push_back(v1); dl->list.push_back(v2);
	}

	// Path
	for (auto it : test_color) {
		mesh_point p1 = {get<0>(it), get<1>(it)};
		mesh_point p2 = {get<2>(it), get<3>(it)};
		vec4 color = get<4>(it);

		vertex v1{{p1.x, p1.y, 0, 1}, {0, 0}, color};
		vertex v2{{p2.x, p2.y, 0, 1}, {0, 0}, color};
		dl->list.push_back(v1); dl->list.push_back(v2);
	}

	glm::mat4 model = glm::mat4();
	model = glm::translate(model, glm::vec3(x, y, 0.f));
	renderer->toScreen(model, {1,1,1,1});
}
