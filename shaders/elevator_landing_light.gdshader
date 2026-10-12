shader_type canvas_item;
render_mode unshaded;
uniform sampler2D landing_mask : filter_linear, repeat_disable;
// Zero preserves the approved art. No TIME-driven effect is enabled.
uniform float light_loss : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 source = COLOR;
	float influence = texture(landing_mask, UV).r;
	source.rgb *= 1.0 - influence * light_loss * 0.85;
	COLOR = source;
}
