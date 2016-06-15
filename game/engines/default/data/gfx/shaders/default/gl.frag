uniform sampler2D tex;

void main()
{
	gl_FragColor = texture2D(tex, te4_uv) * te4_fragcolor;
	// Strangely (or not) this looks rather neat on text
	// gl_FragColor.a = sqrt(gl_FragColor.a);
}
