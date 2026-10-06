shader_type canvas_item;
render_mode unshaded;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float softness_px = 0.5;
varying float glyph_opacity;
void vertex() {
	glyph_opacity = COLOR.a;
}
void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * softness_px;
	float coverage = texture(TEXTURE, UV).a * 0.5;
	coverage += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a * 0.125;
	coverage += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a * 0.125;
	coverage += texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a * 0.125;
	coverage += texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a * 0.125;
	COLOR = vec4(shadow_color.rgb, coverage * shadow_color.a * glyph_opacity);
}
