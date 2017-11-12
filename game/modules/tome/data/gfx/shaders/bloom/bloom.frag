uniform sampler2D tex;

vec4 getHDR(vec2 pos) {
	vec4 c = sqrt(texture2D(tex, pos)) * 8;
	// vec4 c = texture2D(tex, pos) * 10;
	vec4 bc = vec4(0.0, 0.0, 0.0, 0.0);

	// Check whether fragment output is higher than threshold, if so output as brightness color
	float brightness = dot(c.rgb, vec3(0.2126, 0.1152, 0.0722));
	// float brightness = dot(c.rgb, vec3(0.5, 0.5, 0.5));
	if (brightness > 0.1) bc = vec4(c.rgb, 1.0);
	// if (brightness > 0.1) bc = vec4(c.rgb, 1.0) * (1+brightness);
	return bc;
}

void main()
{
	gl_FragColor = getHDR(te4_uv) * te4_fragcolor;
	// gl_FragColor = texture2D(tex, te4_uv) * te4_fragcolor;
}
