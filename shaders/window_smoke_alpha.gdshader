shader_type canvas_item;
render_mode unshaded;
varying vec4 canvas_tint;
void vertex() { canvas_tint = COLOR; }
void fragment() {
 vec4 plume = texture(TEXTURE, UV);
 plume.a = min(plume.a * 1.6, 0.70);
 COLOR = plume * canvas_tint;
}
