uniform sampler2D vectors;
uniform sampler2D planet_texture;
uniform sampler2D clouds_texture;
uniform float tick;
uniform float rotate_angle;
uniform float light_angle;
uniform float planet_time_scale;
uniform float clouds_time_scale;
float M_PI = 3.1415926535897932384626433832795;

mat2 rotate2d(float _angle) {
	return mat2(cos(_angle), -sin(_angle), sin(_angle), cos(_angle));
}

bool has_rotate_matrix = false;
mat2 rotate_planet_matrix;
mat2 rotate_light_matrix;

void main () {
	float time_planet = tick / planet_time_scale;
	float time_cloud = tick / clouds_time_scale;

	// Rotate planet
	if (!has_rotate_matrix) {
		rotate_planet_matrix = rotate2d(rotate_angle);
		rotate_light_matrix = rotate2d(light_angle + M_PI/4.0);
		has_rotate_matrix = true;
	}
	vec2 rotated_coords = rotate_planet_matrix * (te4_uv-vec2(0.5));
	rotated_coords += vec2(0.5);

	vec4 vector = texture2D(vectors, rotated_coords );

	if (distance(rotated_coords, vec2(0.5, 0.5)) > 0.5) {
		discard;
		return;
	}

	// Retrieve planet texture pixel
	vec2 planet_coords;
	planet_coords.x = (vector.r + vector.g/255.0 + time_planet)/2.0;
	planet_coords.y = vector.b + vector.a/255.0;
	if (planet_coords.x > 1.0) {
		planet_coords.x =  planet_coords.x - 1.0;
	}

	vec2 clouds_coords;
	clouds_coords.x = (vector.r + vector.g/255.0 + time_cloud)/2.0;
	clouds_coords.y = vector.b + vector.a/255.0;
	if (clouds_coords.x > 1.0) {
		clouds_coords.x =  clouds_coords.x - 1.0;
	}

	// Calculate shadow.
	vec2 light_coords = vec2(0.0, 0.0);
	vec2 shadow_coords = te4_uv;

	shadow_coords -= vec2(0.5);
	light_coords -= vec2(0.5);
	light_coords = rotate_light_matrix * light_coords;
	float shadow = 0.0;
	shadow = 1.0-pow(distance(light_coords, shadow_coords)*0.9, 3.0);
	if (shadow < 0.05) {
		shadow = 0.05;
	}

	vec4 pixel = texture2D(planet_texture, planet_coords);
        pixel.r *= shadow;
        pixel.g *= shadow;
        pixel.b *= shadow;

	vec4 cloud = texture2D(clouds_texture, clouds_coords);
	cloud.r = 1.0-cloud.r;
	cloud.g = 1.0-cloud.g;
	cloud.b = 1.0-cloud.b;
	cloud.a = cloud.r * shadow;
	cloud.rgb *= cloud.a;

	gl_FragColor = pixel + cloud;
}
