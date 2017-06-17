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
#include "Recast.h"
#include "RecastDebugDraw.h"
#include "RecastDump.h"
#include "DetourNavMesh.h"
#include "DetourNavMeshBuilder.h"
#include "DetourNavMeshQuery.h"
#include "renderer-moderngl/Navmesh.hpp"

Navmesh::Navmesh(b2World *world) : world(world) {
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
			printf("Loop detected, ignoring last poing\n");
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
		}
	} }

	// With the triangles compute the navmesh
	printf("Navmesh building...\n");
	makeNavmesh(46);
	printf("Navmesh done\n");
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

bool Navmesh::makeNavmesh(int radius) {
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

	// vector<p2t::Point*> steiners;
	// for (uint32_t x = min_x; x < max_x; x += 200) {
	// 	for (uint32_t y = min_y; y < max_y; y += 200) {
	// 		p2t::Point *p = new p2t::Point(x, y);
	// 		steiners.push_back(p);
	// 	}
	// }

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
		if (!clpr.Execute(ClipperLib::ctDifference, solution, ClipperLib::pftEvenOdd, ClipperLib::pftNonZero))continue;

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
		// for (auto point : steiners) cdt.AddPoint(point);

		cdt.Triangulate();
		vector<p2t::Triangle*> triangles = cdt.GetTriangles();

		// Store triangles and find edges
		for (auto &tri : triangles) {
			p2t::Point *p1 = tri->GetPoint(0);
			p2t::Point *p2 = tri->GetPoint(1);
			p2t::Point *p3 = tri->GetPoint(2);
			sp_mesh_triangle mtri = make_shared<mesh_triangle>((mesh_point){(uint32_t)p1->x, (uint32_t)p1->y}, (mesh_point){(uint32_t)p2->x, (uint32_t)p2->y}, (mesh_point){(uint32_t)p3->x, (uint32_t)p3->y}, mesh.size() + 1);
			mesh.push_back(mtri);

			mtri->print();

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
			tri1->links.push_back(edge->links[1]);
			tri2->links.push_back(edge->links[0]);
		} else if (edge->links.size() == 0) {
			printf("[NAVMESH] ERROR: triangle edge with 0 neighbours!\n");
		} else if (edge->links.size() > 2) {
			printf("[NAVMESH] ERROR: triangle edge with more than 2 neighbours (%ld)!\n", edge->links.size());
		}
	}

	// Now we have triangles, find neighbours
	for (auto tri : mesh) {
		printf("Triangle %d linked to\n", tri->id);
		for (auto it : tri->links) printf(" - %d\n", it);
	}
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

	glm::mat4 model = glm::mat4();
	model = glm::translate(model, glm::vec3(x, y, 0.f));
	renderer->toScreen(model, {1,1,1,1});
}

/////////////////////////////////////////////////////////////////////////
// Non working recast/detour version
/////////////////////////////////////////////////////////////////////////

// bool Navmesh::makeNavmesh() {
// 	rcHeightfield* m_solid;
// 	rcCompactHeightfield* m_chf;
// 	rcContourSet* m_cset;
// 	rcPolyMesh* m_pmesh;
// 	rcConfig m_cfg;	
// 	rcPolyMeshDetail* m_dmesh;
// 	rcContext m_ctx(false);

// 	// Find the minimums & maximums and export vertexes & triangles in a way recast understands
// 	float bmin[3] = {999999, 999999, -1}, bmax[3] = {-999999, -999999, 1};
// 	vector<float> rc_vertices; rc_vertices.reserve(mesh.size() * 3 * 3);
// 	vector<int> rc_tris; rc_tris.reserve(mesh.size() * 3);
// 	for (auto &tri : mesh) {
// 		bmin[0] = fmin(bmin[0], tri.minX());
// 		bmax[0] = fmin(bmax[0], tri.maxX());
// 		bmin[1] = fmin(bmin[1], tri.minY());
// 		bmax[1] = fmin(bmax[1], tri.maxY());

// 		rc_tris.push_back(rc_vertices.size() / 3);
// 		rc_vertices.push_back(tri.p1.x); rc_vertices.push_back(tri.p1.y); rc_vertices.push_back(0);
// 		rc_tris.push_back(rc_vertices.size() / 3);
// 		rc_vertices.push_back(tri.p2.x); rc_vertices.push_back(tri.p2.y); rc_vertices.push_back(0);
// 		rc_tris.push_back(rc_vertices.size() / 3);
// 		rc_vertices.push_back(tri.p3.x); rc_vertices.push_back(tri.p3.y); rc_vertices.push_back(0);
// 	}
// 	int ntris = rc_tris.size() / 3;
// 	int nverts = rc_vertices.size() / 3;
// 	float *verts = rc_vertices.data();
// 	int *tris = rc_tris.data();

// 	float m_cellSize = 9.0 ;//0.3;
// 	float m_cellHeight = 6.0 ;//0.2;
// 	float m_agentMaxSlope = 45;
// 	float m_agentHeight = 64.0;
// 	float m_agentMaxClimb = 16;
// 	float m_agentRadius = 16;
// 	float m_edgeMaxLen = 512;
// 	float m_edgeMaxError = 1.3;
// 	float m_regionMinSize = 50;
// 	float m_regionMergeSize = 20;
// 	float m_vertsPerPoly = 6;
// 	float m_detailSampleDist = 6;
// 	float m_detailSampleMaxError = 1;
// 	float m_keepInterResults = false;

// 	// Init build configuration from GUI
// 	memset(&m_cfg, 0, sizeof(m_cfg));
// 	m_cfg.cs = m_cellSize;
// 	m_cfg.ch = m_cellHeight;
// 	m_cfg.walkableSlopeAngle = m_agentMaxSlope;
// 	m_cfg.walkableHeight = (int)ceilf(m_agentHeight / m_cfg.ch);
// 	m_cfg.walkableClimb = (int)floorf(m_agentMaxClimb / m_cfg.ch);
// 	m_cfg.walkableRadius = (int)ceilf(m_agentRadius / m_cfg.cs);
// 	m_cfg.maxEdgeLen = (int)(m_edgeMaxLen / m_cellSize);
// 	m_cfg.maxSimplificationError = m_edgeMaxError;
// 	m_cfg.minRegionArea = (int)rcSqr(m_regionMinSize);		// Note: area = size*size
// 	m_cfg.mergeRegionArea = (int)rcSqr(m_regionMergeSize);	// Note: area = size*size
// 	m_cfg.maxVertsPerPoly = (int)m_vertsPerPoly;
// 	m_cfg.detailSampleDist = m_detailSampleDist < 0.9f ? 0 : m_cellSize * m_detailSampleDist;
// 	m_cfg.detailSampleMaxError = m_cellHeight * m_detailSampleMaxError;
	
// 	// Set the area where the navigation will be build.
// 	// Here the bounds of the input mesh are used, but the
// 	// area could be specified by an user defined box, etc.
// 	rcVcopy(m_cfg.bmin, bmin);
// 	rcVcopy(m_cfg.bmax, bmax);
// 	rcCalcGridSize(m_cfg.bmin, m_cfg.bmax, m_cfg.cs, &m_cfg.width, &m_cfg.height);

// 	// Allocate voxel heightfield where we rasterize our input data to.
// 	m_solid = rcAllocHeightfield();
// 	if (!rcCreateHeightfield(&m_ctx, *m_solid, m_cfg.width, m_cfg.height, m_cfg.bmin, m_cfg.bmax, m_cfg.cs, m_cfg.ch))
// 	{
// 		printf("buildNavigation: Could not create solid heightfield.\n");
// 		return false;
// 	}
	
// 	// Allocate array that can hold triangle area types.
// 	// If you have multiple meshes you need to process, allocate
// 	// and array which can hold the max number of triangles you need to process.
// 	unsigned char *m_triareas = new unsigned char[ntris];
	
// 	// Find triangles which are walkable based on their slope and rasterize them.
// 	// If your input data is multiple meshes, you can transform them here, calculate
// 	// the are type for each of the meshes and rasterize them.
// 	memset(m_triareas, 0, ntris*sizeof(unsigned char));
// 	rcMarkWalkableTriangles(&m_ctx, m_cfg.walkableSlopeAngle, verts, nverts, tris, ntris, m_triareas);
// 	if (!rcRasterizeTriangles(&m_ctx, verts, nverts, tris, m_triareas, ntris, *m_solid, m_cfg.walkableClimb))
// 	{
// 		printf("buildNavigation: Could not rasterize triangles.\n");
// 		return false;
// 	}

// 	if (!m_keepInterResults)
// 	{
// 		delete [] m_triareas;
// 		m_triareas = 0;
// 	}
	
// 	//
// 	// Step 3. Filter walkables surfaces.
// 	//
	
// 	// Once all geoemtry is rasterized, we do initial pass of filtering to
// 	// remove unwanted overhangs caused by the conservative rasterization
// 	// as well as filter spans where the character cannot possibly stand.
// 	// if (m_filterLowHangingObstacles)
// 	// 	rcFilterLowHangingWalkableObstacles(&m_ctx, m_cfg.walkableClimb, *m_solid);
// 	// if (m_filterLedgeSpans)
// 	// 	rcFilterLedgeSpans(&m_ctx, m_cfg.walkableHeight, m_cfg.walkableClimb, *m_solid);
// 	// if (m_filterWalkableLowHeightSpans)
// 	// 	rcFilterWalkableLowHeightSpans(&m_ctx, m_cfg.walkableHeight, *m_solid);


// 	//
// 	// Step 4. Partition walkable surface to simple regions.
// 	//

// 	// Compact the heightfield so that it is faster to handle from now on.
// 	// This will result more cache coherent data as well as the neighbours
// 	// between walkable cells will be calculated.
// 	m_chf = rcAllocCompactHeightfield();
// 	if (!rcBuildCompactHeightfield(&m_ctx, m_cfg.walkableHeight, m_cfg.walkableClimb, *m_solid, *m_chf))
// 	{
// 		printf("buildNavigation: Could not build compact data.\n");
// 		return false;
// 	}
	
// 	if (!m_keepInterResults)
// 	{
// 		rcFreeHeightField(m_solid);
// 		m_solid = 0;
// 	}
		
// 	// Erode the walkable area by agent radius.
// 	if (!rcErodeWalkableArea(&m_ctx, m_cfg.walkableRadius, *m_chf))
// 	{
// 		printf("buildNavigation: Could not erode.\n");
// 		return false;
// 	}

// 	// (Optional) Mark areas.
// 	// const ConvexVolume* vols = m_geom->getConvexVolumes();
// 	// for (int i  = 0; i < m_geom->getConvexVolumeCount(); ++i)
// 	// 	rcMarkConvexPolyArea(&m_ctx, vols[i].verts, vols[i].nverts, vols[i].hmin, vols[i].hmax, (unsigned char)vols[i].area, *m_chf);

	
// 	// Partition the heightfield so that we can use simple algorithm later to triangulate the walkable areas.
// 	// There are 3 martitioning methods, each with some pros and cons:
// 	// 1) Watershed partitioning
// 	//   - the classic Recast partitioning
// 	//   - creates the nicest tessellation
// 	//   - usually slowest
// 	//   - partitions the heightfield into nice regions without holes or overlaps
// 	//   - the are some corner cases where this method creates produces holes and overlaps
// 	//      - holes may appear when a small obstacles is close to large open area (triangulation can handle this)
// 	//      - overlaps may occur if you have narrow spiral corridors (i.e stairs), this make triangulation to fail
// 	//   * generally the best choice if you precompute the nacmesh, use this if you have large open areas
// 	// 2) Monotone partioning
// 	//   - fastest
// 	//   - partitions the heightfield into regions without holes and overlaps (guaranteed)
// 	//   - creates long thin polygons, which sometimes causes paths with detours
// 	//   * use this if you want fast navmesh generation
// 	// 3) Layer partitoining
// 	//   - quite fast
// 	//   - partitions the heighfield into non-overlapping regions
// 	//   - relies on the triangulation code to cope with holes (thus slower than monotone partitioning)
// 	//   - produces better triangles than monotone partitioning
// 	//   - does not have the corner cases of watershed partitioning
// 	//   - can be slow and create a bit ugly tessellation (still better than monotone)
// 	//     if you have large open areas with small obstacles (not a problem if you use tiles)
// 	//   * good choice to use for tiled navmesh with medium and small sized tiles
	
// 	// if (m_partitionType == SAMPLE_PARTITION_WATERSHED)
// 	// {
// 		// Prepare for region partitioning, by calculating distance field along the walkable surface.
// 		if (!rcBuildDistanceField(&m_ctx, *m_chf))
// 		{
// 			printf("buildNavigation: Could not build distance field.\n");
// 			return false;
// 		}
		
// 		// Partition the walkable surface into simple regions without holes.
// 		if (!rcBuildRegions(&m_ctx, *m_chf, 0, m_cfg.minRegionArea, m_cfg.mergeRegionArea))
// 		{
// 			printf("buildNavigation: Could not build watershed regions.\n");
// 			return false;
// 		}
// 	// }
// 	// else if (m_partitionType == SAMPLE_PARTITION_MONOTONE)
// 	// {
// 	// 	// Partition the walkable surface into simple regions without holes.
// 	// 	// Monotone partitioning does not need distancefield.
// 	// 	if (!rcBuildRegionsMonotone(&m_ctx, *m_chf, 0, m_cfg.minRegionArea, m_cfg.mergeRegionArea))
// 	// 	{
// 	// 		printf("buildNavigation: Could not build monotone regions.\n");
// 	// 		return false;
// 	// 	}
// 	// }
// 	// else // SAMPLE_PARTITION_LAYERS
// 	// {
// 	// 	// Partition the walkable surface into simple regions without holes.
// 	// 	if (!rcBuildLayerRegions(&m_ctx, *m_chf, 0, m_cfg.minRegionArea))
// 	// 	{
// 	// 		printf("buildNavigation: Could not build layer regions.\n");
// 	// 		return false;
// 	// 	}
// 	// }
	
// 	//
// 	// Step 5. Trace and simplify region contours.
// 	//
	
// 	// Create contours.
// 	m_cset = rcAllocContourSet();
// 	if (!m_cset)
// 	{
// 		printf("buildNavigation: Out of memory 'cset'.\n");
// 		return false;
// 	}
// 	if (!rcBuildContours(&m_ctx, *m_chf, m_cfg.maxSimplificationError, m_cfg.maxEdgeLen, *m_cset))
// 	{
// 		printf("buildNavigation: Could not create contours.\n");
// 		return false;
// 	}
	
// 	//
// 	// Step 6. Build polygons mesh from contours.
// 	//
	
// 	// Build polygon navmesh from the contours.
// 	m_pmesh = rcAllocPolyMesh();
// 	if (!m_pmesh)
// 	{
// 		printf("buildNavigation: Out of memory 'pmesh'.\n");
// 		return false;
// 	}
// 	if (!rcBuildPolyMesh(&m_ctx, *m_cset, m_cfg.maxVertsPerPoly, *m_pmesh))
// 	{
// 		printf("buildNavigation: Could not triangulate contours.\n");
// 		return false;
// 	}
	
// 	//
// 	// Step 7. Create detail mesh which allows to access approximate height on each polygon.
// 	//
	
// 	m_dmesh = rcAllocPolyMeshDetail();
// 	if (!m_dmesh)
// 	{
// 		printf("buildNavigation: Out of memory 'pmdtl'.\n");
// 		return false;
// 	}

// 	if (!rcBuildPolyMeshDetail(&m_ctx, *m_pmesh, *m_chf, m_cfg.detailSampleDist, m_cfg.detailSampleMaxError, *m_dmesh))
// 	{
// 		printf("buildNavigation: Could not build detail mesh.\n");
// 		return false;
// 	}

// 	if (!m_keepInterResults)
// 	{
// 		rcFreeCompactHeightfield(m_chf);
// 		m_chf = 0;
// 		rcFreeContourSet(m_cset);
// 		m_cset = 0;
// 	}

// 	// At this point the navigation mesh data is ready, you can access it from m_pmesh.
// 	// See duDebugDrawPolyMesh or dtCreateNavMeshData as examples how to access the data.
	
// 	//
// 	// (Optional) Step 8. Create Detour data from Recast poly mesh.
// 	//
	
// 	unsigned char* navData = 0;
// 	int navDataSize = 0;

// 	// // Update poly flags from areas.
// 	// for (int i = 0; i < m_pmesh->npolys; ++i)
// 	// {
// 	// 	if (m_pmesh->areas[i] == RC_WALKABLE_AREA)
// 	// 		m_pmesh->areas[i] = SAMPLE_POLYAREA_GROUND;
			
// 	// 	if (m_pmesh->areas[i] == SAMPLE_POLYAREA_GROUND ||
// 	// 		m_pmesh->areas[i] == SAMPLE_POLYAREA_GRASS ||
// 	// 		m_pmesh->areas[i] == SAMPLE_POLYAREA_ROAD)
// 	// 	{
// 	// 		m_pmesh->flags[i] = SAMPLE_POLYFLAGS_WALK;
// 	// 	}
// 	// 	else if (m_pmesh->areas[i] == SAMPLE_POLYAREA_WATER)
// 	// 	{
// 	// 		m_pmesh->flags[i] = SAMPLE_POLYFLAGS_SWIM;
// 	// 	}
// 	// 	else if (m_pmesh->areas[i] == SAMPLE_POLYAREA_DOOR)
// 	// 	{
// 	// 		m_pmesh->flags[i] = SAMPLE_POLYFLAGS_WALK | SAMPLE_POLYFLAGS_DOOR;
// 	// 	}
// 	// }


// 	dtNavMeshCreateParams params;
// 	memset(&params, 0, sizeof(params));
// 	params.verts = m_pmesh->verts;
// 	params.vertCount = m_pmesh->nverts;
// 	params.polys = m_pmesh->polys;
// 	params.polyAreas = m_pmesh->areas;
// 	params.polyFlags = m_pmesh->flags;
// 	params.polyCount = m_pmesh->npolys;
// 	params.nvp = m_pmesh->nvp;
// 	params.detailMeshes = m_dmesh->meshes;
// 	params.detailVerts = m_dmesh->verts;
// 	params.detailVertsCount = m_dmesh->nverts;
// 	params.detailTris = m_dmesh->tris;
// 	params.detailTriCount = m_dmesh->ntris;
// 	// params.offMeshConVerts = m_geom->getOffMeshConnectionVerts();
// 	// params.offMeshConRad = m_geom->getOffMeshConnectionRads();
// 	// params.offMeshConDir = m_geom->getOffMeshConnectionDirs();
// 	// params.offMeshConAreas = m_geom->getOffMeshConnectionAreas();
// 	// params.offMeshConFlags = m_geom->getOffMeshConnectionFlags();
// 	// params.offMeshConUserID = m_geom->getOffMeshConnectionId();
// 	// params.offMeshConCount = m_geom->getOffMeshConnectionCount();
// 	params.walkableHeight = m_agentHeight;
// 	params.walkableRadius = m_agentRadius;
// 	params.walkableClimb = m_agentMaxClimb;
// 	rcVcopy(params.bmin, m_pmesh->bmin);
// 	rcVcopy(params.bmax, m_pmesh->bmax);
// 	params.cs = m_cfg.cs;
// 	params.ch = m_cfg.ch;
// 	params.buildBvTree = true;
	
// 	if (!dtCreateNavMeshData(&params, &navData, &navDataSize))
// 	{
// 		printf("Could not build Detour navmesh.\n");
// 		return false;
// 	}
	
// 	m_navMesh = dtAllocNavMesh();
// 	if (!m_navMesh)
// 	{
// 		dtFree(navData);
// 		printf("Could not create Detour navmesh\n");
// 		return false;
// 	}
	
// 	dtStatus status;
	
// 	status = m_navMesh->init(navData, navDataSize, DT_TILE_FREE_DATA);
// 	if (dtStatusFailed(status))
// 	{
// 		dtFree(navData);
// 		printf("Could not init Detour navmesh\n");
// 		return false;
// 	}
	
// 	status = m_navQuery->init(m_navMesh, 2048);
// 	if (dtStatusFailed(status))
// 	{
// 		printf("Could not init Detour navmesh query\n");
// 		return false;
// 	}
// }
