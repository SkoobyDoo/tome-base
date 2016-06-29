uniform float hp_warning;
uniform float motionblur;
uniform float blur;
uniform float tick;
uniform vec2 texSize;
uniform sampler2D tex;
uniform vec4 colorize;

void main(void)
{
	vec4 use_color = texture2D(tex, gl_TexCoord[0].xy);

	if (blur > 0.0)
	{
		int blursize = int(blur);
		vec2 offset = 1.0/texSize;

		// Center Pixel
		vec4 sample = vec4(0.0,0.0,0.0,0.0);
		float factor = ((float(blursize)*2.0)+1.0);
		factor = factor*factor;

		for(int i = -blursize; i <= blursize; i++)
		{
			for(int j = -blursize; j <= blursize; j++)
			{
				sample += texture2D(tex, vec2(gl_TexCoord[0].xy+vec2(float(i)*offset.x, float(j)*offset.y)));
			}
		}
		sample /= float((blur*2.0) * (blur*2.0));
		use_color = sample;
	}

	if (colorize.r > 0.0 || colorize.g > 0.0 || colorize.b > 0.0)
	{
		float grey = (use_color.r*0.3+use_color.g*0.59+use_color.b*0.11);
		use_color = use_color * (1.0 - colorize.a) + (vec4(colorize.r, colorize.g, colorize.b, 1.0) * grey);
	}

	if (hp_warning > 0.0)
	{
		vec4 hp_warning_color = vec4(hp_warning / 1.9, 0.0, 0.0, hp_warning / 1.5);
		float dist = length(gl_TexCoord[0].xy - vec2(0.5)) / 2.0;
		use_color = mix(use_color, hp_warning_color, dist);
	}

	gl_FragColor = use_color;
}
