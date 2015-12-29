uniform float tick;
uniform vec4 displayColor;
uniform mat4 mvp;

void main()
{
	gl_Position = mvp * te4_position;
	te4_uv = te4_texcoord;
	te4_fragcolor = te4_color * displayColor;
}
