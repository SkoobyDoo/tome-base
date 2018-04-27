uniform sampler2D tex;

void main()
{
	vec4 b = texture2D(tex, te4_uv) * te4_fragcolor;
	b.rgb *= b.a;
	gl_FragData[0] = b;
	gl_FragData[1] = b * 0.5;
}