uniform float tick;
uniform vec4 displayColor;
uniform mat4 mvp;

void main()
{
	gl_Position = mvp * vec4(te4_position.x, te4_position.y, 0.0, 1.0);
	te4_uv = te4_texcoord;
	te4_fragcolor = te4_color * displayColor;
}
