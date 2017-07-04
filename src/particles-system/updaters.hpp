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

enum class UpdatersList : uint8_t { LinearColorUpdater, BasicTimeUpdater, EulerPosUpdater };

class Updater {
public:
	virtual void update(ParticlesData &p, float dt) = 0;
};

class LinearColorUpdater : public Updater {
public:
	virtual void update(ParticlesData &p, float dt);
};

class BasicTimeUpdater : public Updater {
public:
	virtual void update(ParticlesData &p, float dt);
};

class EulerPosUpdater : public Updater {
private:
	vec2 global_acc = vec2(0.0, 0.0);
public:
	EulerPosUpdater(vec2 global_acc = vec2(0, 0)) : global_acc(global_acc) {};
	virtual void update(ParticlesData &p, float dt);
};
