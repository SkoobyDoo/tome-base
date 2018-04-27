uniform sampler2D tex;

void main()
{
	vec4 b = texture2D(tex, te4_uv) * te4_fragcolor;
	gl_FragData[0] = vec4(0.0, 0.0, 0.0, 0.0);
	gl_FragData[1] = b;
}