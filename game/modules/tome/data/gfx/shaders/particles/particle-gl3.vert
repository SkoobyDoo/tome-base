uniform float tick;
uniform mat4 mvp;
uniform vec4 displayColor;

attribute vec4 te4_position;
attribute vec4 te4_texcoord;
attribute vec4 te4_color;
attribute vec2 te4_shape_vertex;

varying vec2 te4_uv;
varying vec4 te4_fragcolor;

mat2 rotate(float a) {
	float s = sin(a);
	float c = cos(a);
	return mat2(c, s, -s, c);
}

void main()
{
	mat2 rot = rotate(te4_position.w);
	gl_Position = mvp * vec4(te4_position.xy + rot * te4_shape_vertex * te4_position.z * 2.0, 0.0, 1.0);
	// te4_uv = te4_shape_vertex + vec2(0.5, 0.5);

	if (te4_shape_vertex.x == -0.5) te4_uv.x = te4_texcoord.s;
	else te4_uv.x = te4_texcoord.p;
	if (te4_shape_vertex.y == -0.5) te4_uv.y = te4_texcoord.t;
	else te4_uv.y = te4_texcoord.q;

	te4_fragcolor = te4_color * displayColor;
}
