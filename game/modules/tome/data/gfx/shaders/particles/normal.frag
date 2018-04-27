uniform sampler2D tex;

void main()
{
	vec4 c = texture2D(tex, te4_uv) * te4_fragcolor;
	c.rgb *= c.a;
	gl_FragData[0] = c;
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, 0.0);
}