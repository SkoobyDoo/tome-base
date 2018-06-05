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

#include "navmesh/Navmesh.hpp"
#include "readerwriterqueue.hpp"

using namespace moodycamel; // I love this name lol

extern "C" {
#include "auxiliar.h"
}

/******************************************************************
 ** Async functions
 ******************************************************************/
class AsyncPathfind {
	Navmesh *p;
	mesh_point start, end;
public:
	int uid;
	int tri_start_id, tri_end_id;
	vector<mesh_point> path;
	bool result = false;

	AsyncPathfind(Navmesh *p, int uid, uint32_t fx, uint32_t fy, uint32_t tx, uint32_t ty) : p(p), uid(uid), start(fx, fy), end(tx, ty) {
	}
	~AsyncPathfind() {
	}
	void process() {
		// printf("working on pathfind %d\n", uid);
		result = p->pathFindByTriangle(start, end, tri_start_id, tri_end_id, path);
	}
};

SDL_Thread *pathfind_thread = NULL;
BlockingReaderWriterQueue<AsyncPathfind*> path_queue_in(100);
ReaderWriterQueue<AsyncPathfind*> path_queue_out(100);
unordered_set<int> running_paths;
unordered_map<int, AsyncPathfind*> done_paths;

static int thread_pathfind(void *data) {
	AsyncPathfind *work;
	while (true) {
		path_queue_in.wait_dequeue(work);
		work->process();
		path_queue_out.enqueue(work);
	}	
}

// Runs on main thread
static inline void create_thread_pathfind() {
	if (pathfind_thread) return;

	pathfind_thread = SDL_CreateThread(thread_pathfind, "pathfind", NULL);
	if (pathfind_thread == NULL) {
		printf("Unable to create pathfind thread: %s\n", SDL_GetError());
		return;
	}

	printf("Created pathfind thread\n");
	return;
}


/******************************************************************
 ** Navmesh functions
 ******************************************************************/
static int navmesh_free(lua_State *L)
{
	Navmesh *p = *(Navmesh**)auxiliar_checkclass(L, "navmesh{map}", 1);
	delete p;
	lua_pushnumber(L, 1);
	return 1;
}

static int navmesh_get_triangles(lua_State *L) {
	Navmesh *p = *(Navmesh**)auxiliar_checkclass(L, "navmesh{map}", 1);
	auto mesh = p->getTrianglesList();
	lua_newtable(L);
	int i = 1;
	for (auto &tri : mesh) {
		lua_newtable(L);

		lua_newtable(L);
		lua_pushliteral(L, "x"); lua_pushnumber(L, tri->p1.x); lua_rawset(L, -3);
		lua_pushliteral(L, "y"); lua_pushnumber(L, tri->p1.y); lua_rawset(L, -3);
		lua_rawseti(L, -2, 1);
		
		lua_newtable(L);
		lua_pushliteral(L, "x"); lua_pushnumber(L, tri->p2.x); lua_rawset(L, -3);
		lua_pushliteral(L, "y"); lua_pushnumber(L, tri->p2.y); lua_rawset(L, -3);
		lua_rawseti(L, -2, 2);
		
		lua_newtable(L);
		lua_pushliteral(L, "x"); lua_pushnumber(L, tri->p3.x); lua_rawset(L, -3);
		lua_pushliteral(L, "y"); lua_pushnumber(L, tri->p3.y); lua_rawset(L, -3);
		lua_rawseti(L, -2, 3);
		
		lua_rawseti(L, -2, i++);
	}
	return 1;
}

static int navmesh_is_in_triangle(lua_State *L)
{
	Navmesh *p = *(Navmesh**)auxiliar_checkclass(L, "navmesh{map}", 1);
	lua_pushboolean(L, p->isInTriangle(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4)));
	return 1;
}

static int navmesh_find_triangle(lua_State *L)
{
	Navmesh *p = *(Navmesh**)auxiliar_checkclass(L, "navmesh{map}", 1);
	lua_pushnumber(L, p->findTriangle(lua_tonumber(L, 2), lua_tonumber(L, 3)));
	return 1;
}

static int navmesh_find_path_async_ret(lua_State *L, AsyncPathfind *ret) {
	if (!ret->result) return 0;
	lua_newtable(L);
	int i = 1;
	for (auto &point : ret->path) {
		lua_pushnumber(L, point.x);
		lua_rawseti(L, -2, i++);
		lua_pushnumber(L, point.y);
		lua_rawseti(L, -2, i++);
	}
	lua_pushnumber(L, ret->tri_start_id);
	lua_pushnumber(L, ret->tri_end_id);
	return 3;
}

static int navmesh_find_path_async(lua_State *L)
{
	Navmesh *p = *(Navmesh**)auxiliar_checkclass(L, "navmesh{map}", 1);
	int uid = lua_tonumber(L, 2);

	// Manage the queue
	AsyncPathfind *ret;
	while (path_queue_out.try_dequeue(ret)) {
		running_paths.erase(ret->uid);
		// Oh goody foudn ourselves quick, lets skip the rest
		if (ret->uid == uid) {
			// printf("Pathfind for %d is done early\n", uid);
			return navmesh_find_path_async_ret(L, ret);
		} else {
			done_paths.emplace(ret->uid, ret);
		}
	}

	if (running_paths.find(uid) != running_paths.end()) {
		// printf("Pathfind for %d still running\n", uid);
		lua_pushboolean(L, false);
		return 1;
	} else {
		auto it = done_paths.find(uid);
		if (it != done_paths.end()) {
			// printf("Pathfind for %d is done!\n", uid);
			ret = it->second;
			done_paths.erase(it);
			return navmesh_find_path_async_ret(L, ret);
		}
	}
	// printf("Pathfind for %d registererd!\n", uid);

	AsyncPathfind *apf = new AsyncPathfind(p, uid, lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5), lua_tonumber(L, 6));
	running_paths.insert(uid);
	path_queue_in.enqueue(apf);
	return 0;
}

static int navmesh_find_path(lua_State *L)
{
	Navmesh *p = *(Navmesh**)auxiliar_checkclass(L, "navmesh{map}", 1);
	mesh_point start = {(uint32_t)lua_tonumber(L, 2), (uint32_t)lua_tonumber(L, 3)};
	mesh_point end = {(uint32_t)lua_tonumber(L, 4), (uint32_t)lua_tonumber(L, 5)};
	vector<mesh_point> path(100);
	int tri_start_id, tri_end_id;
	if (p->pathFindByTriangle(start, end, tri_start_id, tri_end_id, path)) {
		lua_newtable(L);
		int i = 1;
		for (auto &point : path) {
			lua_pushnumber(L, point.x);
			lua_rawseti(L, -2, i++);
			lua_pushnumber(L, point.y);
			lua_rawseti(L, -2, i++);
		}
		lua_pushnumber(L, tri_start_id);
		lua_pushnumber(L, tri_end_id);
		return 3;
	} else {
		lua_pushnil(L);
		return 1;
	}
}

static int navmesh_debug_draw(lua_State *L)
{
	Navmesh *p = *(Navmesh**)auxiliar_checkclass(L, "navmesh{map}", 1);
	p->drawDebug(lua_tonumber(L, 2), lua_tonumber(L, 3));
	return 0;
}

static int lua_navmesh_physics(lua_State *L) {
	Navmesh *mesh = new Navmesh(&PhysicSimulator::current->world, lua_tonumber(L, 1));
	mesh->build();

	Navmesh **r = (Navmesh**)lua_newuserdata(L, sizeof(Navmesh*));
	auxiliar_setclass(L, "navmesh{map}", -1);
	*r = mesh;

	create_thread_pathfind();
	return 1;
}

/******************************************************************
 ** Lua declarations
 ******************************************************************/

static const struct luaL_Reg navmesh_reg[] =
{
	{"__gc", navmesh_free},
	{"isInTriangle", navmesh_is_in_triangle},
	{"findTriangle", navmesh_find_triangle},
	{"pathFind", navmesh_find_path},
	{"pathFindAsync", navmesh_find_path_async},
	{"getTriangles", navmesh_get_triangles},
	{"drawDebug", navmesh_debug_draw},
	{NULL, NULL},
};

const luaL_Reg navmeshlib[] = {
	{"fromPhysics", lua_navmesh_physics},
	{NULL, NULL}
};

extern "C" int luaopen_navmesh(lua_State *L)
{
	auxiliar_newclass(L, "navmesh{map}", navmesh_reg);
	luaL_openlib(L, "core.navmesh", navmeshlib, 0);
	return 1;
}
