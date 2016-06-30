uniform sampler2D tex;
uniform float tick;
varying vec2 mapCoord;
varying vec2 texSize;
varying vec4 texCoord;
varying float kind;

#include "modules/tree.frag"

void main(void)
{
	gl_FragColor = map_shader_tree();
}
