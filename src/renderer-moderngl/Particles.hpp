/*
	TE4 - T-Engine 4
	Copyright (C) 2009 - 2015 Nicolas Casalini

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

#ifndef PARTICLES_GL_H
#define PARTICLES_GL_H

#include "renderer-moderngl/Renderer.hpp"

#define PARTICLE_ETERNAL 999999

enum engine_kinds {
	ENGINE_POINTS = 0,
	ENGINE_LINES = 1,
};

enum blend_modes {
	BLEND_NORMAL = 0,
	BLEND_SHINY = 1,
	BLEND_ADDITIVE = 2,
	BLEND_MIXED = 3,
};

typedef struct {
	float size, sizev, sizea;
	float ox, oy;
	float x, y, xv, yv, xa, ya;
	float dir, dirv, dira, vel, velv, vela;
	float r, g, b, a, rv, gv, bv, av, ra, ga, ba, aa;
	int life;
	int trail;
} particle_type;

class Particles;

class Particles : public DORVertexes {
private:
	SDL_mutex *lock;

	// W by main, R by thread
	const char *name_def;
	const char *args;
	float zoom;

	// R/W only by thread
	vector<particle_type> particles;
	int nb;
	int density;
	bool no_stop;

	// W only by thread, R only by main
	bool alive;
	bool i_want_to_die;
	bool init;
	bool recompile;

	// R/W only by thread
	int base;

	int angle_min, anglev_min, anglea_min;
	int angle_max, anglev_max, anglea_max;

	int size_min, sizev_min, sizea_min;
	int x_min, y_min, xv_min, yv_min, xa_min, ya_min;
	int r_min, g_min, b_min, a_min, rv_min, gv_min, bv_min, av_min, ra_min, ga_min, ba_min, aa_min;

	int size_max, sizev_max, sizea_max;
	int x_max, y_max, xv_max, yv_max, xa_max, ya_max;
	int r_max, g_max, b_max, a_max, rv_max, gv_max, bv_max, av_max, ra_max, ga_max, ba_max, aa_max;

	int life_min, life_max;

	engine_kinds engine;
	blend_modes blend_mode;

	float rotate, rotate_v;

	bool fboalter;

	Particles *sub;
public:
	Particles(const char *name_def, const char *args, int density, bool fboalter);
	virtual ~Particles();
	virtual DisplayObject* clone();
	virtual const char* getKind() { return "Particles"; };

	bool isAlive() { return alive; };
	void die() { i_want_to_die = true; };
	void tick(bool last, bool no_update);
};

#endif
