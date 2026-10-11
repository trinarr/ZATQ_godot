shader_type canvas_item;
render_mode unshaded;
uniform vec4 multiplier = vec4(1.0);
uniform vec3 offset = vec3(0.0);
uniform float saturation : hint_range(0.0,1.5) = 0.88;
uniform float brightness : hint_range(0.0,1.5) = 0.94;
uniform float weather_amount : hint_range(0.0,1.0) = 1.0;
varying vec4 canvas_tint;
void vertex() { canvas_tint = COLOR; }
void fragment() {
 vec4 pixel = texture(TEXTURE,UV);
 float luminance = dot(pixel.rgb,vec3(0.2126,0.7152,0.0722));
 vec3 graded = mix(vec3(luminance),pixel.rgb,saturation)*brightness;
 pixel.rgb = mix(pixel.rgb,graded,weather_amount);
 pixel *= canvas_tint;
 COLOR = vec4(clamp(pixel.rgb*multiplier.rgb+offset,vec3(0.0),vec3(1.0)),pixel.a*multiplier.a);
}
