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

enum class EmittersList : uint8_t { LinearEmitter };

class System;
class Emitter {
protected:
	bool active = true;
	vector<unique_ptr<Generator>> generators;
	void generate(ParticlesData &p, uint32_t nb);
public:
	inline bool isActive() { return active; };
	void shift(float x, float y, bool absolute);
	void addGenerator(System *sys, Generator *gen);
	virtual void emit(ParticlesData &p, float dt) = 0;
};

class LinearEmitter : public Emitter {
private:
	uint32_t nb;
	float rate;
	float duration;
	float accumulator = 0;
public:
	LinearEmitter(float duration, float rate, uint32_t nb) : duration(duration), rate(rate), nb(nb) { if (!rate) rate = 1.0 / 60.0; };
	virtual void emit(ParticlesData &p, float dt);
};
