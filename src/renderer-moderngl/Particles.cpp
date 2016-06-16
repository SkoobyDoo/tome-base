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

#include "renderer-moderngl/Particles.hpp"

Particles::Particles(const char *name_def, const char *args, int density, bool fboalter) {
	lock = SDL_CreateMutex();
	name_def = strdup(name_def);
	args = strdup(args);
	density = density;
	alive = TRUE;
	i_want_to_die = FALSE;
	init = FALSE;
	fboalter = fboalter;
	sub = NULL;
	recompile = FALSE;
	nb = 0;

	// thread_add(this);
}

Particles::~Particles() {
	free((void*)name_def);
	free((void*)args);
	alive = FALSE;
	SDL_DestroyMutex(lock);
}

// We cant clone a Particles, for now
DisplayObject* Particles::clone() {
	return new DORContainer();
}

void Particles::tick(bool last, bool no_update) {
	if (!init) return;

	bool alive = FALSE;
	float zoom = 1;
	float i, j;
	float a;
	float lx, ly, lsize;

	if (last) {
		SDL_mutexP(lock);
		clear();
	}

	recompile = FALSE;

	if (!no_update) rotate += rotate_v;

	particle_type *particles_data = particles.data();

	for (int w = 0; w < nb; w++)
	{
		particle_type *p = &particles_data[w];

		if (p->life > 0)
		{
			if (!no_update) {
				alive = TRUE;

				if (p->life != PARTICLE_ETERNAL) p->life--;

				p->ox = p->x;
				p->oy = p->y;

				p->x += p->xv;
				p->y += p->yv;

				if (p->vel)
				{
					p->x += cos(p->dir) * p->vel;
					p->y += sin(p->dir) * p->vel;
				}

				p->dir += p->dirv;
				p->vel += p->velv;
				p->r += p->rv;
				p->g += p->gv;
				p->b += p->bv;
				p->a += p->av;
				p->size += p->sizev;

				p->xv += p->xa;
				p->yv += p->ya;
				p->dirv += p->dira;
				p->velv += p->vela;
				p->rv += p->ra;
				p->gv += p->ga;
				p->bv += p->ba;
				p->av += p->aa;
				p->sizev += p->sizea;
			}

			if (last)
			{
				if (engine == ENGINE_LINES) {
					if (p->trail >= 0 && p->trail < nb) {
						lx = particles[p->trail].x;
						ly = particles[p->trail].y;
						lsize = particles[p->trail].size;
						a = atan2(p->y - ly, p->x - lx) + M_PI_2;

						addQuad(
							lx + cos(a) * lsize / 2, ly + sin(a) * lsize / 2, 0, 0,
							lx - cos(a) * lsize / 2, ly - sin(a) * lsize / 2, 0, 0,
							p->x - cos(a) * lsize / 2, p->y - sin(a) * lsize / 2, 0, 0,
							p->x + cos(a) * lsize / 2, p->y + sin(a) * lsize / 2, 0, 0,
							p->r, p->g, p->b, p->a
						);
					}
				} else {
					if (!p->trail)
					{
						i = p->x * zoom - p->size / 2;
						j = p->y * zoom - p->size / 2;

						addQuad(
							i, j, 0, 0,
							p->size + i, j, 1, 0,
							p->size + i, p->size + j, 1, 1,
							i, p->size + j, 0, 1,
							p->r, p->g, p->b, p->a
						);
					}
					else
					{
						if ((p->ox <= p->x) && (p->oy <= p->y))
						{
							addQuad(
								0 +  p->ox * zoom, 0 +  p->oy * zoom, 0, 0,
								p->size +  p->x * zoom, 0 +  p->y * zoom, 1, 0,
								p->size +  p->x * zoom, p->size +  p->y * zoom, 1, 1,
								0 +  p->x * zoom, p->size +  p->y * zoom, 0, 1,
								p->r, p->g, p->b, p->a
							);
						}
						else if ((p->ox <= p->x) && (p->oy > p->y))
						{
							addQuad(
								0 +  p->x * zoom, 0 +  p->y * zoom, 0, 0,
								p->size +  p->x * zoom, 0 +  p->y * zoom, 1, 0,
								p->size +  p->x * zoom, p->size +  p->y * zoom, 1, 1,
								0 +  p->ox * zoom, p->size +  p->oy * zoom, 0, 1,
								p->r, p->g, p->b, p->a
							);
						}
						else if ((p->ox > p->x) && (p->oy <= p->y))
						{
							addQuad(
								0 +  p->x * zoom, 0 +  p->y * zoom, 0, 0,
								p->size +  p->ox * zoom, 0 +  p->oy * zoom, 1, 0,
								p->size +  p->x * zoom, p->size +  p->y * zoom, 1, 1,
								0 +  p->x * zoom, p->size +  p->y * zoom, 0, 1,
								p->r, p->g, p->b, p->a
							);
						}
						else if ((p->ox > p->x) && (p->oy > p->y))
						{
							addQuad(
								0 +  p->x * zoom, 0 +  p->y * zoom, 0, 0,
								p->size +  p->x * zoom, 0 +  p->y * zoom, 1, 0,
								p->size +  p->ox * zoom, p->size +  p->oy * zoom, 1, 1,
								0 +  p->x * zoom, p->size +  p->y * zoom, 0, 1,
								p->r, p->g, p->b, p->a
							);
						}
					}
				}
			}
		}
	}

	if (last)
	{
		if (!no_update) this->alive = alive || no_stop;

		SDL_mutexV(lock);
	}
}
