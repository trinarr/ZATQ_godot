shader_type canvas_item;
render_mode unshaded;

// Normalized coordinates of the two panes in the intact 1619 x 971 frame.
// Kept in the same world layer as the city, so cover/safe-area transforms match.
varying vec4 canvas_tint;
void vertex() { canvas_tint = COLOR; }

float pane_mask(vec2 uv, float left, float right) {
 return smoothstep(left, left + 0.004, uv.x)
  * (1.0 - smoothstep(right - 0.004, right, uv.x))
  * smoothstep(0.075, 0.083, uv.y)
  * (1.0 - smoothstep(0.917, 0.925, uv.y));
}

void fragment() {
 float panes = max(pane_mask(UV, 0.132, 0.482), pane_mask(UV, 0.516, 0.874));
 // Broad, faint room reflections; no fog, refraction or heavy contrast filter.
 float diagonal = UV.x + UV.y * 0.22;
 float streak = exp(-pow((diagonal - 0.38) / 0.045, 2.0));
 streak += 0.65 * exp(-pow((diagonal - 0.77) / 0.060, 2.0));
 float edge = exp(-abs(UV.y - 0.095) * 65.0);
 float opacity = panes * (0.012 + 0.038 * streak + 0.018 * edge);
 COLOR = vec4(vec3(0.72, 0.78, 0.82) * canvas_tint.rgb, opacity * canvas_tint.a);
}
