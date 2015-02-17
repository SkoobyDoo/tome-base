#version 330
layout (location = 0) in vec2 te4_position;
layout (location = 1) in vec2 te4_texcoord;
layout (location = 2) in vec4 te4_color;
out vec4 te4_frag_color;
out vec2 te4_uv;

void main()
{
	gl_Position.xy = te4_position;
	gl_Position.z = 0.0;
	gl_Position.w = 1.0;

	te4_frag_color = te4_color;
	te4_uv = te4_texcoord;
}
