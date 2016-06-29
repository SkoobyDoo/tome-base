uniform sampler2D tex;
uniform float gamma;

void main(void)
{
	vec3 color = texture2D(tex, te4_uv).rgb;
	gl_FragColor.rgb = pow(color, vec3(1.0 / gamma));
	gl_FragColor.a = 1.0;
}
