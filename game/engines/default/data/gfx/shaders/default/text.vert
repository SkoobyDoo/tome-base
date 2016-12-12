uniform float tick;
uniform vec4 displayColor;
uniform mat4 mvp;
attribute vec4 te4_texinfo;
varying float bold;
varying float outline;

void main()
{
	gl_Position = mvp * te4_position;
	te4_uv = te4_texcoord;
	te4_fragcolor = te4_color * displayColor;
	bold = te4_texinfo.r;
	outline = te4_texinfo.g;
}
