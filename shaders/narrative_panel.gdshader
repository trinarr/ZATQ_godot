shader_type canvas_item;
render_mode unshaded;

uniform vec2 panel_size = vec2(1504.0, 160.0);

float hash(vec2 p) {
 return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
 vec2 i = floor(p);
 vec2 f = fract(p);
 f = f * f * (3.0 - 2.0 * f);
 return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
            mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void fragment() {
 // Pixel-space distress stays the same size when a longer caption grows upward.
 vec2 p = UV * panel_size;
 vec2 q = abs(p - panel_size * 0.5) - (panel_size * 0.5 - vec2(10.0));
 float edge = -(length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0)) + 3.0;
 float coarse = noise(p * 0.055);
 float fine = noise(p * 0.43 + vec2(41.0, 17.0));
 float torn = edge + (coarse - 0.5) * 13.0 + (fine - 0.5) * 4.0;
 float aa = max(fwidth(torn), 0.7);
 float body = smoothstep(-aa, aa, torn);
 float rim = 1.0 - smoothstep(0.0, 20.0, edge);
 float erosion = smoothstep(0.2, 0.7, fine);
 float paint = body * mix(1.0, erosion, rim * 0.65);
 float second_edge = edge - 7.0 + (noise(p * 0.12 + vec2(73.0, 9.0)) - 0.5) * 12.0;
 paint *= mix(0.5, 1.0, smoothstep(-aa, aa, second_edge));
 COLOR.a *= paint;
}
