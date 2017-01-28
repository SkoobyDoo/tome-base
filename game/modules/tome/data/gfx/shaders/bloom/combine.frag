uniform sampler2D bloom;
uniform sampler2D base;

void main()
{
	vec4 b = texture2D(base, te4_uv);
	vec4 h = texture2D(bloom, te4_uv);
	float gray = dot(h.rgb, vec3(0.2, 0.2, 0.2));
	// float gray = dot(h.rgb, vec3(0.299, 0.587, 0.114));
	h.a = gray;

	// Exposure tone mapping
	float exposure = 0.3;
	vec3 mapped = vec3(1.0) - exp(-(h) * exposure);

	// Gamma correction 
	mapped = pow(mapped, vec3(1.0 / 1.2));

	gl_FragColor = vec4(mapped, h.a) + b;
	// gl_FragColor = (h + b);
	// gl_FragColor = max(sqrt(h) * 0.4, b / 1.5);
	// gl_FragColor = b;
	// gl_FragColor = b / (b + vec4(1.0));
	// gl_FragColor = h + b;
	// h+=b; h = h / (h + vec4(1.0)); gl_FragColor = sqrt(pow(h, vec4(1.0 / 2.0)));
	// gl_FragColor = h;
	// gl_FragColor = b;
	// gl_FragColor.rgb = b.rgb;
}
