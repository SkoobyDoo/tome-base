uniform float tick;
uniform mat4 mvp;
uniform vec4 displayColor;

attribute vec2 te4_position;
attribute vec2 te4_texcoord;
attribute vec4 te4_color;

varying vec2 te4_uv;
varying vec4 te4_fragcolor;

void main()
{
	gl_Position = mvp * vec4(te4_position, 0.0, 1.0);
	te4_uv = te4_texcoord;
	te4_fragcolor = te4_color * displayColor;
}
