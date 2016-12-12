uniform sampler2D tex;
varying float bold;
varying float outline;

const float glyph_center = 0.50;

void main(void)
{
	vec4  color = texture2D(tex, te4_uv);
	float dist  = color.a;

	if (outline) {
		// Outline -- it's actually a simple pregenerated outline, but without signed distance map
		gl_FragColor = vec4(te4_fragcolor.rgb, dist);
	} else {	
		if (bold) { // Bold
			dist = sqrt(dist);
		}

		// Normal
		float width = 0.3;
		// float width = fwidth(dist);
		float alpha = smoothstep(glyph_center-width, glyph_center+width, dist);
		gl_FragColor = vec4(te4_fragcolor.rgb, alpha);
	}	

	// Compute in the requested color alpha
	gl_FragColor.a *= te4_fragcolor.a;
}
