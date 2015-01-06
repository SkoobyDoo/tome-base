uniform sampler2D tex;
uniform float tick;

void main(void)
{
	vec4 p = texture2D(tex, gl_TexCoord[0].xy);
	gl_FragColor = p;
}
