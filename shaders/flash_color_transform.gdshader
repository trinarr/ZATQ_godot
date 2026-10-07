shader_type canvas_item;
render_mode unshaded;
uniform vec4 multiplier = vec4(1.0);
uniform vec3 offset = vec3(0.0);
// Sigma in pixels of the exported 2x texture; zero keeps sharp parts cheap.
uniform vec2 blur_sigma = vec2(0.0);
uniform float blur_angle = 0.0;
// fragment COLOR already includes TEXTURE. Keep the vertex tint separately
// so both sharp and blurred samples are multiplied by it exactly once.
varying vec4 canvas_tint;
void vertex() {
 canvas_tint = COLOR;
}
void fragment() {
 vec4 pixel = texture(TEXTURE, UV);
 if (max(blur_sigma.x, blur_sigma.y) > 0.0) {
  vec2 major = vec2(cos(blur_angle), sin(blur_angle)) * blur_sigma.x;
  vec2 minor = vec2(-sin(blur_angle), cos(blur_angle)) * blur_sigma.y;
  vec4 sum = vec4(0.0);
  float weights = 0.0;
  // Local texture sampling: foreground UI and neighbouring objects stay sharp.
  // Premultiplied samples prevent dark fringes around transparent source art.
  for (int x = -2; x <= 2; x++) {
   for (int y = -2; y <= 2; y++) {
    float weight = exp(-0.5 * float(x*x + y*y));
    vec2 uv = clamp(UV + (major*float(x) + minor*float(y))*TEXTURE_PIXEL_SIZE,
                    TEXTURE_PIXEL_SIZE*0.5, vec2(1.0)-TEXTURE_PIXEL_SIZE*0.5);
    vec4 tap = texture(TEXTURE, uv);
    sum += vec4(tap.rgb*tap.a, tap.a)*weight;
    weights += weight;
   }
  }
  pixel = vec4(sum.rgb/max(sum.a, 0.00001), sum.a/weights);
 }
 pixel *= canvas_tint;
 COLOR = vec4(clamp(pixel.rgb * multiplier.rgb + offset, vec3(0.0), vec3(1.0)), pixel.a * multiplier.a);
}
