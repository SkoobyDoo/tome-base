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
#ifndef PHYSICS_H
#define PHYSICS_H

#include "renderer-moderngl/Renderer.hpp"
#ifdef BOX2D_MT
#include "Box2D-MT/Box2D.h"
#else
#include "Box2D/Box2D.h"
#endif

/*************************************************************************
 ** DORPhysic
 *************************************************************************/
class DORPhysic : public IRealtime {
private:
	DisplayObject *me = NULL;
	b2Body *body = NULL;
	bool staticbodies = true;

public:
	DORPhysic(DisplayObject *d);
	virtual ~DORPhysic();

	void define(b2BodyDef &bodyDef);
	b2Fixture *addFixture(b2FixtureDef &fixtureDef);

	void setPos(float x, float y);
	void setAngle(float a);

	void applyForce(float fx, float fy, float apply_x, float apply_y);
	void applyForce(float fx, float fy);
	void applyLinearImpulse(float fx, float fy, float apply_x, float apply_y);
	void applyLinearImpulse(float fx, float fy);
	void setLinearVelocity(float fx, float fy);
	void applyTorque(float t);
	void applyAngularImpulse(float t);
	vec2 getLinearVelocity();

	virtual void onKeyframe(float nb_keyframes);
};

/*************************************************************************
 ** PhysicSimulator
 *************************************************************************/
class TE4ContactListener;
class PhysicSimulator {
private:
#ifdef BOX2D_MT
	b2ThreadPool tp;
#endif
	TE4ContactListener *contact_listener;
	int contact_listener_ref = LUA_NOREF;
public:
	bool paused = true;
	b2World world;
	static float unit_scale;
	static PhysicSimulator *current;

	PhysicSimulator(float x=0, float y=0);
	~PhysicSimulator();
	void setGravity(float x, float y);
	void setContactListener(int ref);
	void use();
	void pause(bool v) { paused = v; };

	void step(float nb_keyframes);

	void rayCast(float x1, float y1, float x2, float y2, uint16 mask_bits);
	void circleCast(float x, float y, float radius, uint16 mask_bits);

	static void setUnitScale(float scale);
	static PhysicSimulator *getCurrent();
};

#endif
