uniform sampler2D tex;

void main()
{
	vec4 b = texture2D(tex, te4_uv) * te4_fragcolor;
	if (b.a > 0.5) {
		vec4 c = b;
		c.rgb *= 10.0;
		c.rgb *= c.a;
		gl_FragData[1] = c;
		// gl_FragData[1] = vec4(b.rgb, (b.a - 0.5) * 2.0) * 6.0;
	} else {
		gl_FragData[1] = vec4(0.0);
	}

	b.rgb *= b.a;
	gl_FragData[0] = b;
	b.rgb *= 10;
	gl_FragData[1] = b;
}