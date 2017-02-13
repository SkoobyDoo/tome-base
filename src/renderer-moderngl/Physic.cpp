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
	bodyDef.angle = me->rot_z;
	bodyDef.position.Set(me->x / PhysicSimulator::unit_scale, -me->y / PhysicSimulator::unit_scale);
	bodyDef.userData = me;
	body = PhysicSimulator::current->world.CreateBody(&bodyDef);
}

void DORPhysic::addFixture(b2FixtureDef &fixtureDef) {
	fixtureDef.userData = me;
	body->CreateFixture(&fixtureDef);
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

vec2 DORPhysic::getLinearVelocity() {
	b2Vec2 v = body->GetLinearVelocity();
	return {v.x * PhysicSimulator::unit_scale, -v.y * PhysicSimulator::unit_scale};
}

void DORPhysic::onKeyframe(float nb_keyframes) {
	b2Vec2 position = body->GetPosition();
	float32 angle = body->GetAngle();
	float unit_scale = PhysicSimulator::unit_scale;

	// printf("%4.2f %4.2f %4.2f\n", position.x * unit_scale, position.y * unit_scale, angle);
	me->translate(floor(position.x * unit_scale), -floor(position.y * unit_scale), me->z, true);
	me->rotate(me->rot_x, me->rot_y, angle, true);
}

/*************************************************************************
 ** PhysicSimulator
 *************************************************************************/
PhysicSimulator::PhysicSimulator(float x, float y) : world(b2Vec2(x / unit_scale, -y / unit_scale)) {
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

void PhysicSimulator::step(float nb_keyframes) {
	// We do it this way because box2d doc says it realyl doesnt like changing the timestep
	for (int f = 0; f < nb_keyframes * 60.0 / (float)NORMALIZED_FPS; f++) {
		world.Step(1.0f / 60.0f, 6, 2);
	}
}

PhysicSimulator *PhysicSimulator::current = NULL;
float PhysicSimulator::unit_scale = 1;

PhysicSimulator *PhysicSimulator::getCurrent() {
	printf("[PhysicSimulator] getCurrent: NO CURRENT ONE !\n");
	return current;
}

// DGDGDGDG: this could totaly run in a thread provided we make it it locks on DORPhysic::onKeyframe and on world alteration
extern "C" void run_physic_simulation(float nb_keyframes);
void run_physic_simulation(float nb_keyframes) {
	if (!PhysicSimulator::current) return;
	PhysicSimulator::current->step(nb_keyframes);
}


/*************************************************************
 ** Raycasting
 *************************************************************/
struct Hit {
	DisplayObject *d;
	vec2 point, normal;
};
class RayCastCallbackList : public b2RayCastCallback
{
protected:
public:
	vector<Hit> hits;
	float32 ReportFixture(b2Fixture* fixture, const b2Vec2& point, const b2Vec2& normal, float32 fraction) {
		hits.push_back({
			static_cast<DisplayObject*>(fixture->GetUserData()),
			{point.x, point.y},
			{normal.x, normal.y},
		});
		return 1;
	};
};
class RayCastCallbackCB : public b2RayCastCallback
{
protected:
public:
	RayCastCallbackCB(int cb_id) : cb_id(cb_id) {};
	int cb_id;
	vector<Hit> hits;
	float32 ReportFixture(b2Fixture* fixture, const b2Vec2& point, const b2Vec2& normal, float32 fraction) {
		float32 ret;
		DisplayObject *d = static_cast<DisplayObject*>(fixture->GetUserData());

		// Grab weak DO registery
		lua_rawgeti(L, LUA_REGISTRYINDEX, DisplayObject::weak_registry_ref);

		lua_pushvalue(L, cb_id);
		lua_rawgeti(L, -2, d->getWeakSelfRef()); // The DO
		lua_pushnumber(L, point.x * PhysicSimulator::unit_scale);
		lua_pushnumber(L, -point.y * PhysicSimulator::unit_scale);
		lua_pushnumber(L, normal.x * PhysicSimulator::unit_scale);
		lua_pushnumber(L, -normal.y * PhysicSimulator::unit_scale);
		if (lua_pcall(L, 5, 1, 0)) {
			printf("RayCast callback error: %s\n", lua_tostring(L, -1));
		} else {
			if (lua_isnil(L, -1)) ret = 0;
			else ret = lua_toboolean(L, -1) ? 1 : fraction;
		}
		lua_pop(L, 1);
		return ret;
	};
};

void PhysicSimulator::rayCast(float x1, float y1, float x2, float y2, int cb_id) {
	b2Vec2 point1(x1 / unit_scale, -y1 / unit_scale);
	b2Vec2 point2(x2 / unit_scale, -y2 / unit_scale);
	if (cb_id) {
		// We are called with a callback fct, no returns are sent
		RayCastCallbackCB callback(cb_id);
		world.RayCast(&callback, point1, point2);
	} else {
		// We are called with a table in the lua top stack to store the results
		RayCastCallbackList callback;
		world.RayCast(&callback, point1, point2);
		
		int i = 1;
		lua_rawgeti(L, LUA_REGISTRYINDEX, DisplayObject::weak_registry_ref);
		for (auto &it : callback.hits) {
			lua_newtable(L);

			lua_pushstring(L, "d");
			lua_rawgeti(L, -3, it.d->getWeakSelfRef());
			lua_rawset(L, -3);

			lua_pushstring(L, "x");
			lua_pushnumber(L, it.point.x * unit_scale);
			lua_rawset(L, -3);

			lua_pushstring(L, "y");
			lua_pushnumber(L, -it.point.y * unit_scale);
			lua_rawset(L, -3);

			lua_pushstring(L, "nx");
			lua_pushnumber(L, it.normal.x * unit_scale);
			lua_rawset(L, -3);

			lua_pushstring(L, "ny");
			lua_pushnumber(L, -it.normal.y * unit_scale);
			lua_rawset(L, -3);

			lua_rawseti(L, -3, i++);
		}
		lua_pop(L, 1); // Pop the weak regisry table
	}
}
