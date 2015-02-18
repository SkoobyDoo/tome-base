varying vec2 te4_uv;
varying vec4 te4_fragcolor;
uniform sampler2D tex;

void main()
{
	gl_FragColor = texture2D(tex, te4_uv) * te4_fragcolor;
}
