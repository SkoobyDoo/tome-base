uniform sampler2D displMapTex;
uniform sampler2D normalMapTex;

uniform float spikeLength;
uniform float spikeWidth;
uniform float spikeOffset;

uniform float growthSpeed;

uniform float tick;
uniform float tick_start;
uniform float time_factor;

uniform vec3 color;

void main(void)
{
	vec2 radius = gl_TexCoord[0].xy - vec2(0.5, 0.5);
	float innerRadius = 0.25;
	float outerRadius = 0.5;
	
	vec2 planarPos;
	vec4 displacement = texture2D(displMapTex, gl_TexCoord[0].xy);

	vec2 point = gl_TexCoord[0].xy;
	float eps = 0.05;
	vec2 basisY = vec2(
		 texture2D(displMapTex, point + vec2(eps, 0.0)).a - texture2D(displMapTex, point + vec2(-eps, 0.0)).a,
		-texture2D(displMapTex, point + vec2(0.0, eps)).a + texture2D(displMapTex, point + vec2(0.0, -eps)).a);
	basisY /= length(basisY) + 0.001;
	vec2 basisX = vec2(basisY.y, -basisY.x);

	planarPos.x = displacement.b * 6.0 / spikeWidth + spikeOffset;
	planarPos.y = displacement.a * 20.0 / (spikeLength * clamp((tick - tick_start) / time_factor * growthSpeed, 0.0, 1.0) + 0.001);

	vec4 normalMap = texture2D(normalMapTex, vec2(planarPos.x, clamp(1.0 - planarPos.y, 0.01, 0.99)));
	vec3 localNormal = normalMap.rgb;
	localNormal -= vec3(0.5, 0.5, 0.5);
	localNormal.x = -localNormal.x;
	localNormal.z = -localNormal.z;
	localNormal /= length(localNormal);

	vec3 globalNormal;
	globalNormal.xy  = basisX * localNormal.x + basisY * localNormal.y;
	globalNormal.z = localNormal.z;

	vec2 lightDir2 = vec2(cos(tick / time_factor), sin(tick / time_factor));
	float ang = 3.1415 * 0.2;
	vec3 lightDir3 = vec3(lightDir2 * sin(ang), cos(ang));

	float diffuse = clamp(-dot(lightDir3, globalNormal), 0.0, 1.0);
	float specular = 0.0;
	if(dot(lightDir3, globalNormal) < 0.0)
	{
		vec3 reflectedLight = lightDir3 - globalNormal * dot(lightDir3, globalNormal) * 2.0;
		specular += pow(clamp(-dot(reflectedLight, vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 30.0);
	}
	//vec3(0.624, 0.820, 0.933);
	vec4 resultColor = vec4(color * diffuse + vec3(1.0, 1.0, 1.0) * specular, normalMap.a * gl_Color.a);
	
	gl_FragColor = resultColor;///
}