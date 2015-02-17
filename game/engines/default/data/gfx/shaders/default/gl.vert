attribute vec2 te4_position;
attribute vec2 te4_texcoord;
attribute vec4 te4_color;
varying vec2 te4_uv;
uniform float tick;

void main()
{
	gl_Position = gl_ModelViewProjectionMatrix * vec4(te4_position.x, te4_position.y, 0.0, 1.0);

	te4_uv = te4_texcoord;
}
