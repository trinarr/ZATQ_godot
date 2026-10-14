shader_type canvas_item;
render_mode unshaded;

// A separate shadow pass expands its quad so softness is not clipped at
// the sprite bounds. All sizes are local canvas pixels, not texture texels.
uniform vec2 sprite_size = vec2(100.0);
uniform float padding_px = 12.0;
uniform float softness_px = 3.0;
uniform vec4 shadow_color : source_color = vec4(0.03, 0.02, 0.015, 0.6);
varying float vertex_alpha;

void vertex() {
	vertex_alpha = COLOR.a;
	VERTEX += (UV * 2.0 - 1.0) * padding_px;
}

void fragment() {
	vec2 uv = (UV * (sprite_size + vec2(padding_px * 2.0)) - vec2(padding_px)) / sprite_size;
	vec2 step_uv = vec2(softness_px) / sprite_size;
	float alpha = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			float weight = exp(-float(x*x + y*y) * 0.5);
			vec2 sample_uv = uv + vec2(float(x), float(y)) * step_uv;
			if (sample_uv.x >= 0.0 && sample_uv.y >= 0.0 && sample_uv.x <= 1.0 && sample_uv.y <= 1.0) {
				alpha += texture(TEXTURE, sample_uv).a * weight;
			}
		}
	}
	COLOR = vec4(shadow_color.rgb, alpha / 6.168925 * shadow_color.a * vertex_alpha);
}
