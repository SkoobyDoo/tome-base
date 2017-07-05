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

struct renderer_vertex {
	vec2 pos;
	vec2 tex;
	vec4 color;
};

enum class RendererBlend : uint8_t { DefaultBlend, AdditiveBlend, MixedBlend, ShinyBlend };

class Renderer {
protected:
	static GLuint vbo_shape;
	GLuint vbo_pos, vbo_color;
	GLuint vbos[2];
	shader_type *shader = nullptr;
	texture_type *tex = nullptr;
	vector<renderer_vertex> vertexes;
	RendererBlend blend = RendererBlend::DefaultBlend;
	
public:
	static void init();

	void setBlend(RendererBlend blend);
	void setShader(shader_type *shader);
	void setTexture(texture_type *tex);
	void setup(ParticlesData &p);
	void update(ParticlesData &p);
	void draw(ParticlesData &p, float x, float y);
};
