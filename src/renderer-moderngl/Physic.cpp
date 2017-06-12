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

#include "renderer-moderngl/Physic.hpp"

/*************************************************************************
 ** DORPhysic
 *************************************************************************/
static int physic_obj_count = 0;
DORPhysic::DORPhysic(DisplayObject *d) {
	physic_obj_count++;
	me = d;
}

void DORPhysic::define(b2BodyDef &bodyDef) {
	if (bodyDef.type != b2_staticBody) staticbodies = false;
	bodyDef.angle = me->rot_z;
	bodyDef.position.Set(me->x / PhysicSimulator::unit_scale, -me->y / PhysicSimulator::unit_scale);
	bodyDef.userData = me;
	body = PhysicSimulator::current->world.CreateBody(&bodyDef);
}

b2Fixture *DORPhysic::addFixture(b2FixtureDef &fixtureDef) {
	fixtureDef.userData = me;
	return body->CreateFixture(&fixtureDef);
}

DORPhysic::~DORPhysic() {
	if (body) {
		PhysicSimulator::current->world.DestroyBody(body);
	}
	physic_obj_count--;
}

void DORPhysic::setPos(float x, float y) {
	body->SetTransform(b2Vec2(x / PhysicSimulator::unit_scale, -y / PhysicSimulator::unit_scale), me->rot_z);
}

void DORPhysic::setAngle(float a) {
	body->SetTransform(b2Vec2(me->x / PhysicSimulator::unit_scale, -me->y / PhysicSimulator::unit_scale), a);
}

void DORPhysic::applyForce(float fx, float fy, float apply_x, float apply_y) {
	body->ApplyForce(b2Vec2(fx, -fy), b2Vec2(apply_x / PhysicSimulator::unit_scale, -apply_y / PhysicSimulator::unit_scale), true);
}
void DORPhysic::applyForce(float fx, float fy) {
	body->ApplyForceToCenter(b2Vec2(fx, -fy), true);
}
void DORPhysic::applyLinearImpulse(float fx, float fy, float apply_x, float apply_y) {
	body->ApplyLinearImpulse(b2Vec2(fx, -fy), b2Vec2(apply_x / PhysicSimulator::unit_scale, -apply_y / PhysicSimulator::unit_scale), true);
}
void DORPhysic::applyLinearImpulse(float fx, float fy) {
	body->ApplyLinearImpulseToCenter(b2Vec2(fx, -fy), true);
}
void DORPhysic::setLinearVelocity(float fx, float fy) {
	body->SetLinearVelocity(b2Vec2(fx, -fy));
}

void DORPhysic::applyTorque(float t) {
	body->ApplyTorque(t, true);
}

void DORPhysic::applyAngularImpulse(float t) {
	body->ApplyAngularImpulse(t, true);
}

void DORPhysic::sleep(bool v) {
	body->SetAwake(!v);
}

vec2 DORPhysic::getLinearVelocity() {
	b2Vec2 v = body->GetLinearVelocity();
	return {v.x * PhysicSimulator::unit_scale, -v.y * PhysicSimulator::unit_scale};
}

void DORPhysic::onKeyframe(float nb_keyframes) {
	if (staticbodies) return;
	b2Vec2 position = body->GetPosition();
	float32 angle = body->GetAngle();
	float unit_scale = PhysicSimulator::unit_scale;

	// printf("%4.2f %4.2f %4.2f\n", position.x * unit_scale, position.y * unit_scale, angle);
	me->translate(floor(position.x * unit_scale), -floor(position.y * unit_scale), me->z, true);
	me->rotate(me->rot_x, me->rot_y, angle, true);
}

/*************************************************************
 ** Raycasting
 *************************************************************/
struct Hit {
	DisplayObject *d;
	vec2 point, normal;
	float dist;
};
struct Subhit {
	b2Fixture *fixture;
	vec2 point, normal;
	float dist;
};

static bool sort_hits(const Hit &a, const Hit &b) {
	return a.dist < b.dist;
}
static bool sort_subhits(const Subhit &a, const Subhit &b) {
	return a.dist < b.dist;
}

class RayCastCallbackList : public b2RayCastCallback
{
protected:
	uint16 mask_bits;
	float sx, sy;
public:
	RayCastCallbackList(float sx, float sy, uint16 mask_bits) : sx(sx), sy(sy), mask_bits(mask_bits) {};
	vector<Subhit> hits;
	float32 ReportFixture(b2Fixture* fixture, const b2Vec2& point, const b2Vec2& normal, float32 fraction) {
		float x = (point.x * PhysicSimulator::unit_scale) - sx, y = (-point.y * PhysicSimulator::unit_scale) - sy;
		hits.push_back({
			fixture,
			{point.x, point.y},
			{normal.x, normal.y},
			sqrt(x*x + y*y)
		});
		return 1;
	};
};

void PhysicSimulator::rayCast(float x1, float y1, float x2, float y2, uint16 mask_bits) {
	b2Vec2 point1(x1 / unit_scale, -y1 / unit_scale);
	b2Vec2 point2(x2 / unit_scale, -y2 / unit_scale);

	// We are called with a table in the lua top stack to store the results
	RayCastCallbackList callback(x1, y1, mask_bits);
	world.RayCast(&callback, point1, point2);
	sort(callback.hits.begin(), callback.hits.end(), sort_subhits);
	
	int i = 1;
	lua_rawgeti(L, LUA_REGISTRYINDEX, DisplayObject::weak_registry_ref);
	for (auto &it : callback.hits) {
		lua_newtable(L);

		DisplayObject *d = static_cast<DisplayObject*>(it.fixture->GetUserData());
		lua_pushliteral(L, "d");
		lua_rawgeti(L, -3, d->getWeakSelfRef());
		lua_rawset(L, -3);

		lua_pushliteral(L, "x");
		lua_pushnumber(L, it.point.x * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "y");
		lua_pushnumber(L, -it.point.y * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "nx");
		lua_pushnumber(L, it.normal.x * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "ny");
		lua_pushnumber(L, -it.normal.y * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "dist");
		lua_pushnumber(L, it.dist);
		lua_rawset(L, -3);

		lua_rawseti(L, -3, i++);

		// Awww we hit a wall, too bad let's stop now
		if (it.fixture->GetFilterData().categoryBits & mask_bits) break;
	}
	lua_pop(L, 1); // Pop the weak registry table
}

/*************************************************************
 ** Circlecasting
 *************************************************************/
class CircleCastCallbackList : public b2QueryCallback, public b2RayCastCallback
{
protected:
	uint16 mask_bits;
	b2Vec2 src;
	float radius, radius2;
	vector<Subhit> subhits;
public:
	CircleCastCallbackList(float sx, float sy, float radius, uint16 mask_bits) : src(sx, sy), radius(radius), mask_bits(mask_bits) {};
	vector<Hit> hits;

	// Callback for QueryAABB
	// For each body found we make a raycast from the center to ensure that they both fit in the circle and are in LOS set by mask
	bool ReportFixture(b2Fixture* fixture) {
		radius2 = radius * radius;
		subhits.clear();
		b2Body *cur_body = fixture->GetBody();
		PhysicSimulator::current->world.RayCast(this, src, cur_body->GetPosition());
		sort(subhits.begin(), subhits.end(), sort_subhits);

		for (auto &it : subhits) {
			// Awww we hit a wall, too bad let's stop now
			if (it.fixture->GetFilterData().categoryBits & mask_bits) break;
			// We hit our body, yay
			if (it.fixture->GetBody() == cur_body) {
				DisplayObject *d = static_cast<DisplayObject*>(fixture->GetUserData());
				hits.push_back({
					d,
					it.point,
					it.normal,
					sqrt(it.dist)
				});
				break;
			}
		}
		return true;
	}
	// Callback for internal raycasting
	float32 ReportFixture(b2Fixture* fixture, const b2Vec2& point, const b2Vec2& normal, float32 fraction) {
		float x = point.x - src.x, y = point.y - src.y;
		float dist2 = x*x + y*y;
		if (dist2 <= radius2) {
			subhits.push_back({
				fixture,
				{point.x, point.y},
				{normal.x, normal.y},
				dist2 // Just for sorting, no need to square it
			});
		}
		return 1;
	};
};

void PhysicSimulator::circleCast(float x, float y, float radius, uint16 mask_bits) {
	// We are called with a table in the lua top stack to store the results
	x = x / unit_scale; y = -y / unit_scale; radius = radius / unit_scale;
	CircleCastCallbackList callback(x, y, radius, mask_bits);
	b2AABB aabb;
	aabb.lowerBound = b2Vec2(x - radius, y - radius);
	aabb.upperBound = b2Vec2(x + radius, y + radius);
	world.QueryAABB(&callback, aabb);
	// sort(callback.hits.begin(), callback.hits.end(), sort_hits);
	
	int i = 1;
	lua_rawgeti(L, LUA_REGISTRYINDEX, DisplayObject::weak_registry_ref);
	for (auto &it : callback.hits) {
		lua_newtable(L);

		lua_pushliteral(L, "d");
		lua_rawgeti(L, -3, it.d->getWeakSelfRef());
		lua_rawset(L, -3);

		lua_pushliteral(L, "x");
		lua_pushnumber(L, it.point.x * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "y");
		lua_pushnumber(L, -it.point.y * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "nx");
		lua_pushnumber(L, it.normal.x * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "ny");
		lua_pushnumber(L, -it.normal.y * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "dist");
		lua_pushnumber(L, it.dist * unit_scale);
		lua_rawset(L, -3);

		lua_rawseti(L, -3, i++);
	}
	lua_pop(L, 1); // Pop the weak regisry table
}

/*************************************************************
 ** Contacts
 *************************************************************/
struct contact_info {
	b2Body *a;
	b2Body *b;
	float velocity;
};
class TE4ContactListener : public b2ContactListener
{
public:
	vector<vector<contact_info>> events;
	TE4ContactListener(int nb_threads) {
		events.resize(nb_threads);
	};

	void BeginContact(b2Contact* contact) {};
	void EndContact(b2Contact* contact) {};
	void PreSolve(b2Contact* contact, const b2Manifold* oldManifold) {
		b2WorldManifold worldManifold;
		contact->GetWorldManifold(&worldManifold);
		b2PointState state1[2], state2[2];
		b2GetPointStates(state1, state2, oldManifold, contact->GetManifold());
		if (state2[0] == b2_addState)
		{
			b2Body* bodyA = contact->GetFixtureA()->GetBody();
			b2Body* bodyB = contact->GetFixtureB()->GetBody();
			b2Vec2 point = worldManifold.points[0];
			b2Vec2 vA = bodyA->GetLinearVelocityFromWorldPoint(point);
			b2Vec2 vB = bodyB->GetLinearVelocityFromWorldPoint(point);
			float32 approachVelocity = b2Dot(vB - vA, worldManifold.normal);
#ifdef BOX2D_MT
			events[b2GetThreadId()].push_back({bodyA, bodyB, approachVelocity});
#else
			events[0].push_back({bodyA, bodyB, approachVelocity});
#endif
		}
	};
	void PostSolve(b2Contact* contact, const b2ContactImpulse* impulse) {};
};

/*************************************************************************
 ** PhysicSimulator
 *************************************************************************/
#ifdef BOX2D_MT
PhysicSimulator::PhysicSimulator(float x, float y) : world(b2Vec2(x / unit_scale, -y / unit_scale), &tp) {
	printf("[PhysicSimulator] Initiated in multi-threaded mode\n");
	contact_listener = new TE4ContactListener(b2_maxThreads);
	world.SetContactListener(contact_listener);
}
#else
PhysicSimulator::PhysicSimulator(float x, float y) : world(b2Vec2(x / unit_scale, -y / unit_scale)) {
	printf("[PhysicSimulator] Initiated in single-threaded mode\n");
	contact_listener = new TE4ContactListener(1);
	world.SetContactListener(contact_listener);
}
#endif
PhysicSimulator::~PhysicSimulator() {
	if (contact_listener_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, contact_listener_ref);
	delete contact_listener;
}

void PhysicSimulator::use() {
	if (current && !physic_obj_count) {
		printf("[PhysicSimulator] ERROR TRYING TO DEFINE NEW CURRENT WITH %d OBJECTS LEFT\n", physic_obj_count);
		exit(1);
	}
	current = this;
}

void PhysicSimulator::setGravity(float x, float y) {
	world.SetGravity(b2Vec2(x / unit_scale, -y / unit_scale));
}

void PhysicSimulator::setUnitScale(float scale) {
	unit_scale = scale;
}

void PhysicSimulator::setContactListener(int ref) {
	if (contact_listener_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, contact_listener_ref);
	contact_listener_ref = ref;
}

void PhysicSimulator::sleepAll(bool v) {
	for (b2Body* b = world.GetBodyList(); b; b = b->GetNext()) {
		b->SetAwake(!v);
	}
}

void PhysicSimulator::step(float nb_keyframes) {
	// Grab weak DO registery
	lua_rawgeti(L, LUA_REGISTRYINDEX, DisplayObject::weak_registry_ref);

	// We do it this way because box2d doc says it realyl doesnt like changing the timestep
	for (int f = 0; f < nb_keyframes * 60.0 / (float)NORMALIZED_FPS; f++) {
		world.Step(1.0f / 60.0f, 6, 2);
		if ((contact_listener_ref != LUA_NOREF) && contact_listener->events.size()) {

			lua_rawgeti(L, LUA_REGISTRYINDEX, contact_listener_ref);
			lua_newtable(L);
			int i = 1;
			for (auto &events : contact_listener->events) {
				for (auto &it : events) {
					DisplayObject *a = static_cast<DisplayObject*>(it.a->GetUserData());
					DisplayObject *b = static_cast<DisplayObject*>(it.b->GetUserData());

					lua_newtable(L);
					
					lua_rawgeti(L, -4, a->getWeakSelfRef()); // The DO
					lua_rawseti(L, -2, 1);
					lua_rawgeti(L, -4, b->getWeakSelfRef()); // The DO
					lua_rawseti(L, -2, 2);
					lua_pushnumber(L, it.velocity);
					lua_rawseti(L, -2, 3);

					lua_rawseti(L, -2, i++); // Store the table in the list
				}
				events.clear();
			}

			if (lua_pcall(L, 1, 0, 0)) {
				printf("Contact Listener callback error: %s\n", lua_tostring(L, -1));
			}
		}
	}

	lua_pop(L, 1); // Pop the weak registry
}

PhysicSimulator *PhysicSimulator::current = NULL;
float PhysicSimulator::unit_scale = 1;

PhysicSimulator *PhysicSimulator::getCurrent() {
	printf("[PhysicSimulator] getCurrent: NO CURRENT ONE !\n");
	return current;
}

extern "C" void run_physic_simulation(float nb_keyframes);
void run_physic_simulation(float nb_keyframes) {
	if (!PhysicSimulator::current || PhysicSimulator::current->paused) return;
	PhysicSimulator::current->step(nb_keyframes);
}

extern "C" void reset_physic_simulation();
void reset_physic_simulation() {
	if (!PhysicSimulator::current) return;
	PhysicSimulator::current->setContactListener(LUA_NOREF);
}

