shader_type canvas_item;
render_mode unshaded;
uniform vec4 multiplier = vec4(1.0);
uniform vec3 offset = vec3(0.0);
varying vec4 canvas_tint;
void vertex() { canvas_tint = COLOR; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),
  mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0,1.0)),f.x),f.y);
}
void fragment() {
 float sky = 1.0-smoothstep(0.40,0.52,UV.y);
 float cloud = 0.65*noise(UV*vec2(6.0,10.0)) + 0.35*noise(UV*vec2(12.0,20.0));
 // Translucent cool cloud cover, gently darker on the ground than scene one.
 float opacity = mix(0.16,0.30+0.12*cloud,sky);
 vec3 tone = mix(vec3(0.25,0.29,0.35),vec3(0.39,0.43,0.49),sky);
 COLOR = vec4(clamp(tone*multiplier.rgb+offset,vec3(0.0),vec3(1.0)),opacity*canvas_tint.a*multiplier.a);
}
