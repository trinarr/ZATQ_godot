shader_type canvas_item;
render_mode unshaded;
uniform vec4 vignette_color : source_color = vec4(0.615686, 0.086275, 0.078431, 1.0);
uniform vec2 source_size = vec2(1600.0, 960.0);
uniform vec2 center = vec2(795.5272, 485.0112);
uniform float half_segment = 296.47194;
uniform float aspect = 0.997405;
uniform float falloff_width = 518.1306;
uniform float falloff_power = 2.309879;
uniform float base_alpha = 0.044866;
uniform float amplitude = 0.908445;
varying vec4 canvas_tint;
void vertex() { canvas_tint = COLOR; }
void fragment() {
	vec2 p = abs(UV * source_size - center);
	p.x = max(p.x - half_segment, 0.0) / aspect;
	float distance = length(p) / falloff_width;
	float alpha = base_alpha + amplitude * (1.0 - exp(-pow(distance, falloff_power)));
	COLOR = vec4(vignette_color.rgb * canvas_tint.rgb, clamp(alpha, 0.0, 1.0) * canvas_tint.a);
}
