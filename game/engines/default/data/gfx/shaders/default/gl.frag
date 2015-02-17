#version 330
in vec4 te4_frag_color;
in vec2 te4_uv;
out vec4 te4_color;

uniform sampler2D tex;

void main()
{
	te4_color = texture2D(tex, te4_uv);
}
