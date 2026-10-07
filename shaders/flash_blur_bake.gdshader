shader_type canvas_item;
render_mode unshaded;
uniform vec4 multiplier = vec4(1.0);
uniform vec3 offset = vec3(0.0);
// Sigma in pixels of the exported 2x texture; zero keeps sharp parts cheap.
uniform vec2 blur_sigma = vec2(0.0);
uniform float blur_angle = 0.0;
uniform float blur_strength : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D blur_texture : filter_linear, repeat_disable;
// fragment COLOR already includes TEXTURE. Keep the vertex tint separately
// so both sharp and blurred samples are multiplied by it exactly once.
varying vec4 canvas_tint;
void vertex() {
 canvas_tint = COLOR;
}
vec4 sample_premultiplied(vec2 uv, vec2 texel_size) {
 vec2 edge = texel_size * 0.5;
 vec4 tap = texture(blur_texture, clamp(uv, edge, vec2(1.0)-edge));
 return vec4(tap.rgb*tap.a, tap.a);
}
// Three densely spaced minor-axis samples preserve narrow perpendicular blur.
vec4 directional_sample(vec2 uv, vec2 minor, vec2 texel_size) {
 return sample_premultiplied(uv,texel_size)*0.5
      + sample_premultiplied(uv+minor,texel_size)*0.25
      + sample_premultiplied(uv-minor,texel_size)*0.25;
}
// Center plus five positive/negative bilinear pairs represents a 21-point axis.
// The weight is independent of radius, so narrowing the blur keeps brightness.
vec2 gaussian_pair(int index) {
 if (index == 0) {return vec2(0.0,1.0);}
 float sign_value = index <= 5 ? 1.0 : -1.0;
 int pair_index = index <= 5 ? index-1 : index-6;
 float t1 = float(pair_index*2+1)/5.0;
 float t2 = float(pair_index*2+2)/5.0;
 float w1 = exp(-0.5*t1*t1);
 float w2 = exp(-0.5*t2*t2);
 return vec2(sign_value*(t1*w1+t2*w2)/(w1+w2),w1+w2);
}
void fragment() {
 vec4 pixel = texture(TEXTURE, UV);
 vec2 sigma = blur_sigma*clamp(blur_strength,0.0,1.0);
 if (max(sigma.x,sigma.y) > 0.001) {
  vec2 major = vec2(cos(blur_angle),sin(blur_angle))*sigma.x*TEXTURE_PIXEL_SIZE;
  vec2 minor = vec2(-sin(blur_angle),cos(blur_angle))*sigma.y*TEXTURE_PIXEL_SIZE;
  vec4 sum = vec4(0.0);
  float weights = 0.0;
  if (sigma.y < 1.5) {
   // 81 underlying major-axis positions, packed into 41 bilinear samples.
   // At Episode I's largest radius the underlying spacing is about one texel.
   vec2 minor_offset = minor*1.41421356;
   sum = directional_sample(UV,minor_offset,TEXTURE_PIXEL_SIZE);
   weights = 1.0;
   for (int i = 0; i < 20; i++) {
    float t1 = float(i*2+1)/20.0;
    float t2 = float(i*2+2)/20.0;
    float w1 = exp(-0.5*t1*t1);
    float w2 = exp(-0.5*t2*t2);
    float weight = w1+w2;
    vec2 delta = major*(t1*w1+t2*w2)/weight;
    sum += (directional_sample(UV+delta,minor_offset,TEXTURE_PIXEL_SIZE)
          + directional_sample(UV-delta,minor_offset,TEXTURE_PIXEL_SIZE))*weight;
    weights += weight*2.0;
   }
  } else {
   // Dense 21x21 Gaussian grid packed into 11x11 bilinear samples.
   for (int x = 0; x < 11; x++) {
    vec2 px = gaussian_pair(x);
    for (int y = 0; y < 11; y++) {
     vec2 py = gaussian_pair(y);
     float weight = px.y*py.y;
     sum += sample_premultiplied(UV+major*px.x+minor*py.x,TEXTURE_PIXEL_SIZE)*weight;
     weights += weight;
    }
   }
  }
  pixel = vec4(sum.rgb/max(sum.a,0.00001),sum.a/weights);
 }
 pixel *= canvas_tint;
 COLOR = vec4(clamp(pixel.rgb * multiplier.rgb + offset, vec3(0.0), vec3(1.0)), pixel.a * multiplier.a);
}
