// Static sparse chips. Only the narrow glyph boundary can be removed.
uniform float chip_strength : hint_range(0.0, 1.0) = 0.0;
uniform float chip_scale : hint_range(0.5, 2.0) = 1.0;
float chip_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}
float edge_chip_mask(vec2 position, float inner) {
	if (chip_strength <= 0.0) return 1.0;
	vec2 p = position / chip_scale;
	vec2 cell = floor(p / 8.0);
	float seed = chip_hash(cell);
	if (seed < 0.76) return 1.0;
	vec2 center = (cell + vec2(0.2 + 0.6 * chip_hash(cell + 13.0), 0.2 + 0.6 * chip_hash(cell + 37.0))) * 8.0;
	float radius = mix(0.85, 1.65, chip_hash(cell + 61.0));
	float spot = 1.0 - smoothstep(radius - 0.3, radius + 0.3, length(p - center));
	float boundary = 1.0 - smoothstep(0.05, 0.8, inner);
	return 1.0 - chip_strength * spot * boundary;
}
