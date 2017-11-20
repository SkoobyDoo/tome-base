uniform float tick;
uniform vec4 displayColor;
uniform mat4 mvp;
attribute vec4 te4_mapcoord;
attribute vec4 te4_texinfo;
attribute float te4_kind;
varying vec2 mapCoord;
varying vec2 texSize;
varying vec4 texCoord;
varying float kind;

uniform float tree_attenuation;

void main()
{
	vec4 pos = te4_position;
	float time = tick / 1000.0;

	pos.x += 2.0 * sin(time + te4_mapcoord.x / (40.0) + te4_mapcoord.y) * (1.0 - te4_mapcoord.w) * 35.0 / tree_attenuation;

	gl_Position = mvp * pos;

	te4_uv = te4_texcoord;
	te4_fragcolor = te4_color * displayColor;
	kind = te4_kind;
	mapCoord = te4_mapcoord.xy;
	texSize = te4_mapcoord.zw;
	texCoord = te4_texinfo;
}
