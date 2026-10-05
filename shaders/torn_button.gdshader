shader_type canvas_item;
render_mode unshaded;

uniform vec4 brush_color : source_color = vec4(0.50, 0.235, 0.235, 1.0);
uniform vec2 button_size = vec2(400.0, 100.0);
uniform float seed = 1.0;
uniform float edge_overlay_opacity : hint_range(0.0, 1.0) = 0.5;
uniform float edge_overlay_scale : hint_range(1.0, 2.0) = 1.3;
// Inward reach in normalized brush-height units (96 units per short side).
uniform float edge_overlay_depth : hint_range(0.0, 16.0) = 8.0;

// Work in brush-height units: the native timeline and 2x UI use the same edge.
float hash(vec2 p) {
 vec3 q = fract(vec3(p.xyx) * 0.1031 + seed * 0.017);
 q += dot(q, q.yzx + 33.33);
 return fract((q.x + q.y) * q.z);
}
float noise(vec2 p) {
 vec2 i = floor(p);
 vec2 f = fract(p);
 f = f * f * (3.0 - 2.0 * f);
 return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
            mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
// Independent, enlarged copy of the distress; only its translucent rim is used.
vec2 overlay_rim(vec2 p, float distance_to_edge, vec2 drift) {
 float scale = max(edge_overlay_scale, 1.0);
 vec2 sample_p = p / scale;
 vec2 offset = drift + vec2(109.7, 67.3);
 float coarse = noise(sample_p * 0.085 + offset);
 float medium = noise(sample_p * 0.27 + offset + vec2(17.0, 9.0));
 float fine = noise(sample_p * 0.79 + offset + vec2(5.0, 31.0));
 float dust = noise(sample_p * 1.63 + offset + vec2(41.0, 13.0));
 float waviness = (noise(sample_p * vec2(0.018, 0.035) + offset + vec2(53.0, 7.0)) - 0.5) * 3.0;
 float edge = distance_to_edge / scale + waviness + (coarse - 0.5) * 7.0
              + (medium - 0.5) * 4.0 + (fine - 0.5) * 2.3;
 float aa = max(fwidth(edge), 0.65 / scale);
 float body = smoothstep(-aa, aa, edge - 1.0);
 float rim = 1.0 - smoothstep(1.0, 11.0, distance_to_edge / scale);
 float erosion = smoothstep(0.31, 0.66, medium * 0.65 + fine * 0.35);
 float coverage = body * mix(1.0, erosion, rim * 0.70);
 float speckle = smoothstep(0.60, 0.78, medium * 0.45 + dust * 0.55);
 float fringe = smoothstep(-5.0 - aa, 2.0 + aa, edge) * (1.0 - body) * speckle * 0.18;
 float outward = clamp(coverage + fringe, 0.0, 1.0) * rim;
 // Shift the second torn contour inward, exposing the background through the paint.
 float inner_edge = edge - edge_overlay_depth / scale;
 float inner_body = smoothstep(-aa, aa, inner_edge - 1.0);
 float inner_rim = 1.0 - smoothstep(1.0, 11.0, (distance_to_edge - edge_overlay_depth) / scale);
 float inner_coverage = inner_body * mix(1.0, erosion, inner_rim * 0.70);
 float inward = (1.0 - inner_coverage) * smoothstep(0.0, 2.0 * scale, distance_to_edge);
 return vec2(outward, inward);
}
void fragment() {
 vec4 tint = COLOR;
 vec2 extent = max(button_size, vec2(1.0));
 vec2 span = extent * (96.0 / min(extent.x, extent.y));
 vec2 p = UV * span;
 vec2 drift = vec2(seed * 7.13, seed * 3.71);
 // The rounded silhouette remains visible underneath a narrow distressed rim.
 float coarse = noise(p * 0.085 + drift);
 float medium = noise(p * 0.27 + drift + vec2(17.0, 9.0));
 float fine = noise(p * 0.79 + drift + vec2(5.0, 31.0));
 float dust = noise(p * 1.63 + drift + vec2(41.0, 13.0));
 float aspect = max(extent.x, extent.y) / min(extent.x, extent.y);
 float radius = mix(18.0, 28.0, smoothstep(1.0, 2.2, aspect));
 vec2 half_size = span * 0.5 - vec2(7.0);
 vec2 q = abs(p - span * 0.5) - (half_size - vec2(radius));
 float distance_to_edge = radius - (length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0));
 float waviness = (noise(p * vec2(0.018, 0.035) + drift + vec2(53.0, 7.0)) - 0.5) * 3.0;
 float broken_edge = distance_to_edge + waviness + (coarse - 0.5) * 7.0
                     + (medium - 0.5) * 4.0 + (fine - 0.5) * 2.3;
 float aa = max(fwidth(broken_edge), 0.65);
 float body = smoothstep(-aa, aa, broken_edge - 1.0);
 // Distress follows the rounded contour without rebuilding square corners.
 float rim = 1.0 - smoothstep(1.0, 11.0, distance_to_edge);
 float erosion = smoothstep(0.31, 0.66, medium * 0.65 + fine * 0.35);
 float coverage = body * mix(1.0, erosion, rim * 0.70);
 float speckle = smoothstep(0.60, 0.78, medium * 0.45 + dust * 0.55);
 float fringe = smoothstep(-5.0 - aa, 2.0 + aa, broken_edge)
                * (1.0 - body) * speckle * 0.18;
 // A soft dark, dusty outline like the original painted bitmap, inside the rect.
 float halo = smoothstep(-5.0 - aa, 2.0 + aa, broken_edge) * 0.16;
 float edge_fade = smoothstep(0.0, 2.5, min(min(p.x, span.x - p.x), min(p.y, span.y - p.y)));
 float paint = clamp(coverage + fringe, 0.0, 1.0) * edge_fade;
 halo *= edge_fade;
 float alpha = paint + halo * (1.0 - paint);
 float clouds = noise(p * 0.045 + drift + vec2(73.0, 19.0));
 float worn_rim = mix(0.64, 1.0, smoothstep(0.0, 10.0, distance_to_edge));
 vec3 pigment = brush_color.rgb * worn_rim * (0.94 + clouds * 0.09 + (fine - 0.5) * 0.025);
 vec3 ink = pigment * paint + brush_color.rgb * 0.30 * halo * (1.0 - paint);
 // Composite into gaps in the first edge; the opaque center retains its color.
 vec2 second_edge = overlay_rim(p, distance_to_edge, drift);
 float overlay_alpha = second_edge.x * edge_overlay_opacity * edge_fade;
 float exposed_overlay = overlay_alpha * (1.0 - alpha);
 ink += pigment * exposed_overlay;
 alpha += exposed_overlay;
 float retained_paint = 1.0 - second_edge.y * edge_overlay_opacity;
 ink *= retained_paint;
 alpha *= retained_paint;
 COLOR = vec4(ink / max(alpha, 0.0001), brush_color.a * alpha) * tint;
}
