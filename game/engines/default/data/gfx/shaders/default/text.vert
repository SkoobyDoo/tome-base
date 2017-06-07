uniform float tick;
uniform vec4 displayColor;
uniform mat4 mvp;
attribute float te4_kind;
varying float bold;
varying float outline;

void main()
{
	gl_Position = mvp * te4_position;
	te4_uv = te4_texcoord;
	te4_fragcolor = te4_color * displayColor;
	bold = (te4_kind == 1.0) ? 1.0 : ((te4_kind == 3.0) ? 1.0 : 0.0);
	outline = (te4_kind == 2.0) ? 1.0 : ((te4_kind == 3.0) ? 1.0 : 0.0);
}
