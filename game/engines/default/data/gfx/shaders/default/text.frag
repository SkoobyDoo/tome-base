uniform sampler2D tex;

const float glyph_center   = 0.50;
const vec3 outline_color  = vec3(0.0,0.0,0.0);
const float outline_center = 0.35;

void main(void)
{
	vec4  color = texture2D(tex, te4_uv);
	float dist  = color.r;

	if (0) { // Bold
		dist = sqrt(dist);
	}

	// float width = 0.3;
	float width = fwidth(dist);
	float alpha = smoothstep(glyph_center-width, glyph_center+width, dist);

	if (0) {
		// Outline
		float mu = smoothstep(outline_center-width, outline_center+width, dist);
		// vec3 rgb = sqrt(mix(outline_color, te4_fragcolor.rgb, mu));
		vec3 rgb = mix(outline_color, te4_fragcolor.rgb, mu);
		gl_FragColor = vec4(rgb, max(alpha,mu));
	} else {
		// Normal
		gl_FragColor = vec4(te4_fragcolor.rgb, alpha);
	}

	// Compute in the requested color alpha
	gl_FragColor.a *= te4_fragcolor.a;
}


// const float glyph_center   = 0.50;
// vec3 outline_color  = vec3(0.0,0.0,0.0);
// const float outline_center = 0.45;
// vec3 glow_color     = vec3(0.0,0.0,0.0);
// const float glow_center    = 2.5;

// void main(void)
// {
// 	vec4  color = texture2D(tex, te4_uv);
// 	float dist  = sqrt(color.r);
// 	// float dist  = color.r;
// 	// float width = 0.3;
// 	float width = fwidth(dist);
// 	float alpha = smoothstep(glyph_center-width, glyph_center+width, dist);

// 	// Smooth
// 	gl_FragColor = vec4(te4_fragcolor.rgb, alpha);
	
// 	// Bare
// 	// float a = smoothstep(u_buffer - u_gamma, u_buffer + u_gamma, dist);;
// 	// gl_FragColor = vec4(te4_fragcolor.rgb, a);

// 	// Outline
// 	float mu = smoothstep(outline_center-width, outline_center+width, dist);
// 	vec3 rgb = sqrt(mix(outline_color, te4_fragcolor.rgb, mu));
// 	// vec3 rgb = mix(outline_color, te4_fragcolor.rgb, mu);
// 	gl_FragColor = vec4(rgb, max(alpha,mu));

// 	// Glow
// 	// vec3 rgb = mix(glow_color, te4_fragcolor.rgb, alpha);
// 	// float mu = smoothstep(glyph_center, glow_center, sqrt(dist));
// 	// gl_FragColor = vec4(rgb, max(alpha,mu));

// 	// Glow + outline
// 	// vec3 rgb = mix(glow_color, te4_fragcolor.rgb, alpha);
// 	// float mu = smoothstep(glyph_center, glow_center, sqrt(dist));
// 	// color = vec4(rgb, max(alpha,mu));
// 	// float beta = smoothstep(outline_center-width, outline_center+width, dist);
// 	// rgb = mix(outline_color, color.rgb, beta);
// 	// gl_FragColor = vec4(rgb, max(color.a,beta));

// 	gl_FragColor.a *= te4_fragcolor.a;
// }
