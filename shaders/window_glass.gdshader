shader_type canvas_item;
render_mode unshaded;

// Normalized coordinates of the two panes in the intact 1619 x 971 frame.
// Kept in the same world layer as the city, so cover/safe-area transforms match.
varying vec4 canvas_tint;
uniform float reflection_strength : hint_range(0.0, 2.0) = 1.0;
void vertex() { canvas_tint = COLOR; }

float pane_mask(vec2 uv, float left, float right) {
 return smoothstep(left, left + 0.004, uv.x)
  * (1.0 - smoothstep(right - 0.004, right, uv.x))
  * smoothstep(0.075, 0.083, uv.y)
  * (1.0 - smoothstep(0.917, 0.925, uv.y));
}

float soft_band(float distance, float width) {
 float normalized = distance / width;
 return exp(-0.5 * normalized * normalized);
}

float pane_reflection(vec2 uv, float left, float right, float phase) {
 vec2 pane = vec2((uv.x - left) / (right - left), (uv.y - 0.075) / 0.85);
 // Each pane reflects the room at a slightly different angle. Local streaks
 // establish the glass surface without washing out the entire city image.
 float diagonal = pane.x + pane.y * (0.26 + phase * 0.04);
 float broad = soft_band(diagonal - (0.40 + phase * 0.10), 0.075);
 float glint = soft_band(diagonal - (0.34 + phase * 0.10), 0.018);
 float echo = soft_band(diagonal - (0.48 + phase * 0.10), 0.020);
 // Soft reflected vertical room trim, restricted to the upper pane.
 float trim = soft_band(pane.x - (0.76 - phase * 0.12), 0.015)
  * (1.0 - smoothstep(0.45, 0.72, pane.y));
 float top = exp(-max(pane.y, 0.0) * 65.0);
 float side = exp(-max(min(pane.x, 1.0 - pane.x), 0.0) * 100.0);
 float opacity = 0.003 + broad * 0.055 + glint * 0.150
  + echo * 0.035 + trim * 0.050 + top * 0.100 + side * 0.065;
 return pane_mask(uv, left, right) * min(opacity * reflection_strength, 0.22);
}

// Dirt is rendered by plain PNG pane overlays, independently of this shader.
void fragment() {
 float opacity = max(pane_reflection(UV, 0.132, 0.482, 0.0),
  pane_reflection(UV, 0.516, 0.874, 1.0));
 COLOR = vec4(vec3(0.82, 0.87, 0.91) * canvas_tint.rgb, opacity * canvas_tint.a);
}
