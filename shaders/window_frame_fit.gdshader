shader_type canvas_item;
render_mode unshaded;
varying vec4 canvas_tint;
void vertex() { canvas_tint = COLOR; }

void fragment() {
 // Stretch the intact frame's pane height while keeping the existing 36 px
 // top/sill in the 800 x 480 scene. Every column uses the same mapping:
 // side jambs, corners and sill cannot drift apart as independent crops did.
 float source_y;
 if (UV.y < 0.075) {
  source_y = mix(0.0, 80.0 / 971.0, UV.y / 0.075);
 } else if (UV.y < 0.925) {
  source_y = mix(80.0 / 971.0, 825.0 / 971.0, (UV.y - 0.075) / 0.85);
 } else {
  source_y = mix(825.0 / 971.0, 1.0, (UV.y - 0.925) / 0.075);
 }
 COLOR = texture(TEXTURE, vec2(UV.x, source_y)) * canvas_tint;
}
