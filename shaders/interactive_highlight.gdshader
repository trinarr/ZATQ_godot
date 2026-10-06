shader_type canvas_item;
render_mode unshaded;
uniform vec4 glow_color : source_color = vec4(0.63137, 0.09412, 0.09412, 1.0);
uniform float alpha_min = 0.5;
uniform float alpha_max = 0.80078125;
uniform float period_seconds = 1.0;
uniform float softness_px = 2.0;
varying vec4 canvas_tint;
void vertex() {
	canvas_tint = COLOR;
}
void fragment() {
	vec2 d = TEXTURE_PIXEL_SIZE * softness_px;
	float a = texture(TEXTURE, UV).a * 0.25;
	a += (texture(TEXTURE, UV + vec2(d.x, 0.0)).a + texture(TEXTURE, UV - vec2(d.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, d.y)).a + texture(TEXTURE, UV - vec2(0.0, d.y)).a) * 0.125;
	a += (texture(TEXTURE, UV + d).a + texture(TEXTURE, UV - d).a
		+ texture(TEXTURE, UV + vec2(d.x, -d.y)).a + texture(TEXTURE, UV + vec2(-d.x, d.y)).a) * 0.0625;
	float pulse = 0.5 - 0.5 * cos(TIME * 6.28318530718 / max(period_seconds, 0.01));
	COLOR = vec4(glow_color.rgb * canvas_tint.rgb, a * mix(alpha_min, alpha_max, pulse) * canvas_tint.a);
}
