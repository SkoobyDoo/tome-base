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
#include "Box2D/Box2D.h"

// DGDGDGDG: worth considering https://github.com/skitzoid/Box2D-MT ?

/*************************************************************************
 ** DORPhysic
 *************************************************************************/
class DORPhysic : public IRealtime {
private:
	DisplayObject *me = NULL;
	b2Body *body = NULL;

public:
	DORPhysic(DisplayObject *d);
	virtual ~DORPhysic();

	void define(b2BodyType kind, const b2FixtureDef &fixtureDef);

	void setPos(float x, float y);
	void applyForce(float fx, float fy, float apply_x, float apply_y);
	void applyForce(float fx, float fy);
	void applyLinearImpulse(float fx, float fy, float apply_x, float apply_y);
	void applyLinearImpulse(float fx, float fy);
	void applyTorque(float t);
	void applyAngularImpulse(float t);

	virtual void onKeyframe(int nb_keyframes);
};

/*************************************************************************
 ** PhysicSimulator
 *************************************************************************/
class PhysicSimulator {
private:

public:
	b2World world;
	static float unit_scale;
	static PhysicSimulator *current;

	PhysicSimulator(float x=0, float y=0);
	void setGravity(float x, float y);
	void use();

	void step(int nb_keyframes);

	static void setUnitScale(float scale);
	static PhysicSimulator *getCurrent();
};

#endif
