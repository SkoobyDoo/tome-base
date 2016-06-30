// Simple Water shader. (c) Victor Korsun, bitekas@gmail.com; 2012.
//
// Attribution-ShareAlike CC License.

const float water_PI = 3.1415926535897932;

// play with these parameters to custimize the effect
// ===================================================

//water_speed
const float water_speed = 0.2;
const float water_speed_x = 0.3;
const float water_speed_y = 0.3;

// refraction
const float water_emboss = 0.50;
const float water_intensity = 2.4;
const int water_steps = 10;
const float water_frequency = 12.0;
const int water_angle = 7; // better when a prime

// reflection
const float water_delta = 60.;
const float water_intence = 700.;

const float water_reflectionCutOff = 0.012;
const float water_reflectionIntence = 200000.;

// ===================================================

float water_time = tick / 10000.0;

float water_col(vec2 coord)
{
	float water_delta_theta = 2.0 * water_PI / float(water_angle);
	float col = 0.0;
	float theta = 0.0;
	for (int i = 0; i < water_steps; i++)
	{
		vec2 adjc = coord;
		theta = water_delta_theta*float(i);
		adjc.x += cos(theta)*water_time*water_speed + water_time * water_speed_x;
		adjc.y -= sin(theta)*water_time*water_speed - water_time * water_speed_y;
		col = col + cos( (adjc.x*cos(theta) - adjc.y*sin(theta))*water_frequency)*water_intensity;
	}

	return cos(col);
}

//---------- main

vec4 map_shader_water(void)
{
	vec2 p = (vec2(gl_FragCoord.x - mapCoord.x, texSize.y - gl_FragCoord.y - mapCoord.y)) / texSize.xy, c1 = p, c2 = p;
	float cc1 = water_col(c1);

	c2.x += texSize.x/water_delta;
	float dx = water_emboss*(cc1-water_col(c2))/water_delta;

	c2.x = p.x;
	c2.y += texSize.y/water_delta;
	float dy = water_emboss*(cc1-water_col(c2))/water_delta;

	c1.x += dx*2.;
	c1.y = -(c1.y+dy*2.);

	float alpha = 1.+dot(dx,dy)*water_intence;
		
	float ddx = dx - water_reflectionCutOff;
	float ddy = dy - water_reflectionCutOff;
	if (ddx > 0. && ddy > 0.)
		alpha = pow(alpha, ddx*ddy*water_reflectionIntence);
	
	// c1 = clamp(c1, texCoord.xy, texCoord.xy + texCoord.zw);
	// vec4 col = texture2D(tex, texCoord.xy + c1 * texCoord.zw)*(alpha);
	vec4 col = texture2D(tex, te4_uv) * te4_fragcolor * (alpha);
	return col;
}
