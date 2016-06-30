#resetarg tree_attenuation=35
uniform float tree_attenuation;

vec4 map_shader_tree(void)
{
	float time = tick / 1000.0;
	vec2 xy = te4_uv.xy;

	vec2 ts = texCoord.zw;
	vec2 tx = texCoord.xy;
	if (xy.y <= tx.y + 0.75 * ts.y) {
		xy.x = xy.x + (tx.y + 0.75 * ts.y - xy.y) * sin(time + mapCoord.x / (40.0) + mapCoord.y) / tree_attenuation;
	}

	xy = clamp(xy, tx, tx + ts);
	return texture2D(tex, xy) * te4_fragcolor;
}
