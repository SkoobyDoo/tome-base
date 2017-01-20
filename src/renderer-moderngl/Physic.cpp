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

	b2BodyDef bodyDef;
	bodyDef.type = b2_dynamicBody;
	bodyDef.position.Set(0.0f, 4.0f);
	body = PhysicSimulator::current->world.CreateBody(&bodyDef);

	// Define another box shape for our dynamic body.
	b2PolygonShape dynamicBox;
	dynamicBox.SetAsBox(1.0f, 1.0f);

	// Define the dynamic body fixture.
	b2FixtureDef fixtureDef;
	fixtureDef.shape = &dynamicBox;

	// Set the box density to be non-zero, so it will be dynamic.
	fixtureDef.density = 1.0f;

	// Override the default friction.
	fixtureDef.friction = 0.3f;

	// Add the shape to the body.
	body->CreateFixture(&fixtureDef);
}

DORPhysic::~DORPhysic() {
	physic_obj_count--;

}

void DORPhysic::onKeyframe(int nb_keyframes) {
	b2Vec2 position = body->GetPosition();
	float32 angle = body->GetAngle();
	float unit_scale = PhysicSimulator::current->unit_scale;

	printf("%4.2f %4.2f %4.2f\n", position.x * unit_scale, position.y * unit_scale, angle);
	me->translate(position.x * unit_scale, -position.y * unit_scale, me->z, false);
	me->rotate(me->rot_x, me->rot_y, angle, false);
}

/*************************************************************************
 ** PhysicSimulator
 *************************************************************************/
PhysicSimulator::PhysicSimulator(float x, float y) : world(b2Vec2(x, y)) {
}

void PhysicSimulator::use() {
	if (current && !physic_obj_count) {
		printf("[PhysicSimulator] ERROR TRYING TO DEFINE NEW CURRENT WITH %d OBJECTS LEFT\n", physic_obj_count);
		exit(1);
	}
	current = this;
}

void PhysicSimulator::setUnitScale(float scale) {
	unit_scale = scale;
}

void PhysicSimulator::step(int nb_keyframes) {
	// We do it this way because box2d doc says it realyl doesnt like changing the timestep
	// printf("doing %f steps\n", nb_keyframes * 60.0 / (float)NORMALIZED_FPS);
	for (int f = 0; f < nb_keyframes * 60.0 / (float)NORMALIZED_FPS; f++) {
		world.Step(1.0f / 60.0f, 6, 2);
	}
}

PhysicSimulator *PhysicSimulator::current = NULL;
PhysicSimulator *PhysicSimulator::getCurrent() {
	printf("[PhysicSimulator] getCurrent: NO CURRENT ONE !\n");
	return current;
}

extern "C" void run_physic_simulation(int nb_keyframes);
void run_physic_simulation(int nb_keyframes) {
	if (!PhysicSimulator::current) return;
	PhysicSimulator::current->step(nb_keyframes);
}
