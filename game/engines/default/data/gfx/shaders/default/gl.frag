uniform sampler2D tex;

void main()
{
	gl_FragColor = texture2D(tex, te4_uv) * te4_fragcolor;
}
