shader_type canvas_item;
render_mode unshaded;
varying vec4 canvas_tint;
void vertex() { canvas_tint = COLOR; }
void fragment() {
 vec4 sample_color = texture(TEXTURE, UV);
 float luma = dot(sample_color.rgb, vec3(0.2126, 0.7152, 0.0722));
 vec3 steel = mix(vec3(luma), sample_color.rgb, 0.88);
 steel *= vec3(0.96, 0.98, 1.0);
 COLOR = vec4(steel, sample_color.a) * canvas_tint;
}
