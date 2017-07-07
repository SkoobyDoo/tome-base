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
using namespace std;
using namespace glm;

enum class UpdatersList : uint8_t {
	LinearColorUpdater, EasingColorUpdater,
	BasicTimeUpdater,
	AnimatedTextureUpdater,
	EulerPosUpdater, EasingPosUpdater,
	LinearSizeUpdater, EasingSizeUpdater,
};

typedef float (*easing_ptr)(float,float,float);

class Updater {
public:
	virtual void useSlots(ParticlesData &p) {};
	virtual void update(ParticlesData &p, float dt) = 0;
};

class LinearColorUpdater : public Updater {
public:
	virtual void useSlots(ParticlesData &p) { p.initSlot4(LIFE); p.initSlot4(COLOR); p.initSlot4(COLOR_START); p.initSlot4(COLOR_STOP); };
	virtual void update(ParticlesData &p, float dt);
};

class EasingColorUpdater : public Updater {
private:
	easing_ptr easing;
public:
	EasingColorUpdater(easing_ptr easing) : easing(easing) {};
	virtual void useSlots(ParticlesData &p) { p.initSlot4(COLOR); p.initSlot4(COLOR_START); p.initSlot4(COLOR_STOP); p.initSlot4(LIFE); };
	virtual void update(ParticlesData &p, float dt);
};

class BasicTimeUpdater : public Updater {
public:
	virtual void useSlots(ParticlesData &p) { p.initSlot4(LIFE); };
	virtual void update(ParticlesData &p, float dt);
};

class AnimatedTextureUpdater : public Updater {
private:
	float repeat_over_life;
	uint16_t max;
	vector<vec4> frames;
public:
	AnimatedTextureUpdater(uint8_t splitx, uint8_t splity, uint8_t firstframe, uint8_t lastframe, float repeat_over_life);
	virtual void useSlots(ParticlesData &p) { p.initSlot4(LIFE); p.initSlot4(TEXTURE); };
	virtual void update(ParticlesData &p, float dt);
};

class LinearSizeUpdater : public Updater {
public:
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot4(LIFE); p.initSlot2(SIZE); };
	virtual void update(ParticlesData &p, float dt);
};

class EasingSizeUpdater : public Updater {
private:
	easing_ptr easing;
public:
	EasingSizeUpdater(easing_ptr easing) : easing(easing) {};
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot4(LIFE); p.initSlot2(SIZE); };
	virtual void update(ParticlesData &p, float dt);
};

class EulerPosUpdater : public Updater {
private:
	vec2 global_vel = vec2(0.0, 0.0);
	vec2 global_acc = vec2(0.0, 0.0);
public:
	EulerPosUpdater(vec2 global_vel = vec2(0, 0), vec2 global_acc = vec2(0, 0)) : global_vel(global_vel), global_acc(global_acc) {};
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot2(VEL); p.initSlot2(ACC); };
	virtual void update(ParticlesData &p, float dt);
};

class EasingPosUpdater : public Updater {
private:
	easing_ptr easing;
public:
	EasingPosUpdater(easing_ptr easing) : easing(easing) {};
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot4(LIFE); p.initSlot2(VEL); p.initSlot2(ORIGIN_POS); };
	virtual void update(ParticlesData &p, float dt);
};
