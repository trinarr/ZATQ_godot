shader_type canvas_item;
render_mode unshaded;
uniform vec4 multiplier = vec4(1.0);
uniform vec3 offset = vec3(0.0);
uniform bool has_blur = false;
uniform float blur_strength : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D blur_texture : filter_linear, repeat_disable;
uniform bool art_mask_enabled = false;
uniform vec3 art_mask_x = vec3(1.0,0.0,0.0);
uniform vec3 art_mask_y = vec3(0.0,1.0,0.0);
varying vec4 canvas_tint;
void vertex() {canvas_tint = COLOR;}
void fragment() {
 if (art_mask_enabled) {
  vec3 uv = vec3(UV,1.0);
  vec2 point = vec2(dot(uv,art_mask_x),dot(uv,art_mask_y));
  if (point.x<0.0 || point.y<0.0 || point.x>1.0 || point.y>1.0) discard;
 }
 vec4 pixel = texture(TEXTURE, UV);
 float amount = clamp(blur_strength,0.0,1.0);
 if (has_blur && amount > 0.0) {
  vec4 blurred = texture(blur_texture, UV);
  vec4 premultiplied = mix(vec4(pixel.rgb*pixel.a,pixel.a),
                           vec4(blurred.rgb*blurred.a,blurred.a),amount);
  pixel = vec4(premultiplied.rgb/max(premultiplied.a,0.00001),premultiplied.a);
 }
 pixel *= canvas_tint;
 COLOR = vec4(clamp(pixel.rgb*multiplier.rgb+offset,vec3(0.0),vec3(1.0)),pixel.a*multiplier.a);
}
