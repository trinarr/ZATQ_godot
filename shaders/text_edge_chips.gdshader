shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/text_edge_chips.gdshaderinc"
varying vec2 glyph_position;
void vertex() {
	glyph_position = VERTEX;
}
void fragment() {
	if (chip_strength > 0.0) {
		vec2 chip_step = TEXTURE_PIXEL_SIZE * 1.6 * chip_scale;
		float inner = min(min(texture(TEXTURE, UV + vec2(chip_step.x, 0.0)).a, texture(TEXTURE, UV - vec2(chip_step.x, 0.0)).a), min(texture(TEXTURE, UV + vec2(0.0, chip_step.y)).a, texture(TEXTURE, UV - vec2(0.0, chip_step.y)).a));
		COLOR.a *= edge_chip_mask(glyph_position, inner);
	}
}
