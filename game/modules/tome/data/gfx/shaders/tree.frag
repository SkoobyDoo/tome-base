uniform sampler2D tex;
uniform float tick;
varying vec2 mapCoord;
varying vec2 texSize;
varying vec4 texCoord;
varying float kind;

uniform float tree_attenuation;

void main(void)
{
	float time = tick / 1000.0;
	vec2 xy = te4_uv.xy;

	// vec2 ts = texCoord.zw;
	// vec2 tx = texCoord.xy;
	// if (xy.y <= tx.y + 0.75 * ts.y) {
	// 	xy.x = xy.x + (tx.y + 0.75 * ts.y - xy.y) * sin(time + mapCoord.x / (40.0) + mapCoord.y) / tree_attenuation;
	// }

	// xy = clamp(xy, tx, tx + ts);
	gl_FragColor = texture2D(tex, xy) * te4_fragcolor;
}
