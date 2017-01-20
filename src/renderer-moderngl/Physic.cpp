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

void DORPhysic::define(b2BodyType kind, const b2FixtureDef &fixtureDef) {
	b2BodyDef bodyDef;
	bodyDef.type = kind;
	bodyDef.position.Set(0.0f, 0.0f);
	body = PhysicSimulator::current->world.CreateBody(&bodyDef);

	body->CreateFixture(&fixtureDef);
}

DORPhysic::~DORPhysic() {
	physic_obj_count--;

}

void DORPhysic::setPos(float x, float y) {
	body->SetTransform(b2Vec2(x / PhysicSimulator::unit_scale, -y / PhysicSimulator::unit_scale), me->rot_z);
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

void DORPhysic::applyTorque(float t) {
	body->ApplyTorque(t, true);
}

void DORPhysic::applyAngularImpulse(float t) {
	body->ApplyAngularImpulse(t, true);
}

void DORPhysic::onKeyframe(int nb_keyframes) {
	b2Vec2 position = body->GetPosition();
	float32 angle = body->GetAngle();
	float unit_scale = PhysicSimulator::unit_scale;

	printf("%4.2f %4.2f %4.2f\n", position.x * unit_scale, position.y * unit_scale, angle);
	me->translate(position.x * unit_scale, -position.y * unit_scale, me->z, true);
	me->rotate(me->rot_x, me->rot_y, angle, false);
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

void PhysicSimulator::step(int nb_keyframes) {
	// We do it this way because box2d doc says it realyl doesnt like changing the timestep
	// printf("doing %f steps\n", nb_keyframes * 60.0 / (float)NORMALIZED_FPS);
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

extern "C" void run_physic_simulation(int nb_keyframes);
void run_physic_simulation(int nb_keyframes) {
	if (!PhysicSimulator::current) return;
	PhysicSimulator::current->step(nb_keyframes);
}
