vec4 map_shader_normal(void)
{
	return texture2D(tex, te4_uv) * te4_fragcolor;
}
