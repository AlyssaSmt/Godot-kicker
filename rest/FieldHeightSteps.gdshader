shader_type spatial;
render_mode cull_back, depth_draw_opaque;

void fragment() {
	ALBEDO = COLOR.rgb;
}
