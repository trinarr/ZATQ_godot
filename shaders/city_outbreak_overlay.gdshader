shader_type canvas_item;
render_mode unshaded;
uniform vec4 multiplier = vec4(1.0);
uniform vec3 offset = vec3(0.0);
uniform float weather_amount : hint_range(0.0,1.0) = 1.0;
varying vec4 canvas_tint;
void vertex() { canvas_tint = COLOR; }
// Interior of the approved 1600x960 avenue, inset from curbs and buildings.
vec2 road_bounds(float y) {
 if (y < 640.0) return mix(vec2(919.0,922.0),vec2(916.0,920.0),clamp((y-630.0)/10.0,0.0,1.0));
 if (y < 660.0) return mix(vec2(916.0,920.0),vec2(907.0,919.0),clamp((y-640.0)/20.0,0.0,1.0));
 if (y < 680.0) return mix(vec2(907.0,919.0),vec2(900.0,918.0),clamp((y-660.0)/20.0,0.0,1.0));
 if (y < 700.0) return mix(vec2(900.0,918.0),vec2(890.0,916.0),clamp((y-680.0)/20.0,0.0,1.0));
 if (y < 720.0) return mix(vec2(890.0,916.0),vec2(880.0,914.0),clamp((y-700.0)/20.0,0.0,1.0));
 if (y < 740.0) return mix(vec2(880.0,914.0),vec2(872.0,911.0),clamp((y-720.0)/20.0,0.0,1.0));
 if (y < 760.0) return mix(vec2(872.0,911.0),vec2(863.0,907.0),clamp((y-740.0)/20.0,0.0,1.0));
 if (y < 780.0) return mix(vec2(863.0,907.0),vec2(855.0,903.0),clamp((y-760.0)/20.0,0.0,1.0));
 if (y < 800.0) return mix(vec2(855.0,903.0),vec2(846.0,899.0),clamp((y-780.0)/20.0,0.0,1.0));
 if (y < 820.0) return mix(vec2(846.0,899.0),vec2(840.0,896.0),clamp((y-800.0)/20.0,0.0,1.0));
 if (y < 840.0) return mix(vec2(840.0,896.0),vec2(833.0,893.0),clamp((y-820.0)/20.0,0.0,1.0));
 if (y < 860.0) return mix(vec2(833.0,893.0),vec2(826.0,889.0),clamp((y-840.0)/20.0,0.0,1.0));
 if (y < 880.0) return mix(vec2(826.0,889.0),vec2(819.0,885.0),clamp((y-860.0)/20.0,0.0,1.0));
 if (y < 900.0) return mix(vec2(819.0,885.0),vec2(813.0,880.0),clamp((y-880.0)/20.0,0.0,1.0));
 if (y < 920.0) return mix(vec2(813.0,880.0),vec2(808.0,877.0),clamp((y-900.0)/20.0,0.0,1.0));
 if (y < 940.0) return mix(vec2(808.0,877.0),vec2(801.0,873.0),clamp((y-920.0)/20.0,0.0,1.0));
 if (y < 960.0) return mix(vec2(801.0,873.0),vec2(796.0,869.0),clamp((y-940.0)/20.0,0.0,1.0));
 return vec2(796.0,869.0);
}
// Extents of the traffic strip in the source texture, measured at these rows.
vec2 source_bounds(float y) {
 if (y < 640.0) return mix(vec2(929.0,949.0),vec2(910.0,946.0),(y-600.0)/40.0);
 if (y < 680.0) return mix(vec2(910.0,946.0),vec2(890.0,940.0),(y-640.0)/40.0);
 if (y < 720.0) return mix(vec2(890.0,940.0),vec2(871.0,935.0),(y-680.0)/40.0);
 if (y < 760.0) return mix(vec2(871.0,935.0),vec2(850.0,931.0),(y-720.0)/40.0);
 if (y < 800.0) return mix(vec2(850.0,931.0),vec2(830.0,928.0),(y-760.0)/40.0);
 if (y < 840.0) return mix(vec2(830.0,928.0),vec2(809.0,924.0),(y-800.0)/40.0);
 if (y < 880.0) return mix(vec2(809.0,924.0),vec2(791.0,920.0),(y-840.0)/40.0);
 if (y < 920.0) return mix(vec2(791.0,920.0),vec2(771.0,916.0),(y-880.0)/40.0);
 return mix(vec2(771.0,916.0),vec2(751.0,912.0),clamp((y-920.0)/40.0,0.0,1.0));
}
void fragment() {
 vec4 pixel = vec4(0.0);
 if (UV.y < 0.36) {
  pixel = texture(TEXTURE,UV);
  pixel.a *= 0.28;
 } else if (UV.y < 0.50) {
  pixel = texture(TEXTURE,UV);
  pixel.a *= 0.45 * (1.0-smoothstep(0.47,0.50,UV.y));
 } else if (UV.y >= 630.0/960.0) {
  float y = UV.y*960.0;
  vec2 bounds = road_bounds(y);
  float x = UV.x*1600.0;
  if (x >= bounds.x && x <= bounds.y) {
   // Reproject the whole queue into the avenue instead of cropping wrong poses.
   float source_y = mix(600.0,960.0,(y-630.0)/330.0);
   vec2 source = source_bounds(source_y);
   float source_x = mix(source.x,source.y,(x-bounds.x)/(bounds.y-bounds.x));
   pixel = texture(TEXTURE,vec2(source_x/1600.0,source_y/960.0));
   pixel.a *= smoothstep(bounds.x,bounds.x+1.0,x)
    * (1.0-smoothstep(bounds.y-1.0,bounds.y,x)) * smoothstep(630.0,638.0,y);
  }
 }
 float luminance = dot(pixel.rgb,vec3(0.2126,0.7152,0.0722));
 pixel.rgb = mix(vec3(luminance),pixel.rgb,0.88)*0.94;
 luminance = dot(pixel.rgb,vec3(0.2126,0.7152,0.0722));
 vec3 overcast = mix(vec3(luminance),pixel.rgb,0.88)*0.94;
 pixel.rgb = mix(pixel.rgb,overcast,weather_amount);
 pixel *= canvas_tint;
 COLOR = vec4(clamp(pixel.rgb*multiplier.rgb+offset,vec3(0.0),vec3(1.0)),pixel.a*multiplier.a);
}
