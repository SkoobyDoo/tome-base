varying vec2 te4_uv;
uniform sampler2D tex;

void main()
{
	gl_FragColor = texture2D(tex, te4_uv);
}
