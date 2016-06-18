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

void main()
{
	gl_Position = mvp * te4_position;
	te4_uv = te4_texcoord;
	te4_fragcolor = te4_color * displayColor;
	kind = te4_kind;
	mapCoord = te4_mapcoord.xy;
	texSize = te4_mapcoord.zw;
	texCoord = te4_texinfo;
}
