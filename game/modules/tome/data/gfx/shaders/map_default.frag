#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D tex;
uniform float tick;
varying vec2 mapCoord;
varying vec2 texSize;
varying vec4 texCoord;
varying float kind;

#kinddefinitions#

void main(void)
{
	#kindselectors#
}
