shader_type canvas_item;
render_mode unshaded;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float softness_px = 0.5;
uniform bool clip_enabled = false;
uniform vec4 clip_rect;
#include "res://shaders/text_edge_chips.gdshaderinc"
varying vec2 glyph_position;
varying vec2 canvas_position;
varying float glyph_opacity;
void vertex() {
	glyph_position = VERTEX;
	glyph_opacity = COLOR.a;
	canvas_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	if (clip_enabled && (canvas_position.x < clip_rect.x || canvas_position.y < clip_rect.y || canvas_position.x >= clip_rect.x + clip_rect.z || canvas_position.y >= clip_rect.y + clip_rect.w)) discard;
	vec2 step_uv = TEXTURE_PIXEL_SIZE * softness_px;
	float coverage = texture(TEXTURE, UV).a * 0.5;
	coverage += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a * 0.125;
	coverage += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a * 0.125;
	coverage += texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a * 0.125;
	coverage += texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a * 0.125;
	if (chip_strength > 0.0) {
		vec2 chip_step = TEXTURE_PIXEL_SIZE * 1.6 * chip_scale;
		float inner = min(min(texture(TEXTURE, UV + vec2(chip_step.x, 0.0)).a, texture(TEXTURE, UV - vec2(chip_step.x, 0.0)).a), min(texture(TEXTURE, UV + vec2(0.0, chip_step.y)).a, texture(TEXTURE, UV - vec2(0.0, chip_step.y)).a));
		coverage *= edge_chip_mask(glyph_position, inner);
	}
	COLOR = vec4(shadow_color.rgb, coverage * shadow_color.a * glyph_opacity);
}
