shader_type canvas_item;
render_mode unshaded;
uniform vec4 clip_rect;
varying vec2 canvas_position;
void vertex() {
 canvas_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
 if (canvas_position.x < clip_rect.x || canvas_position.y < clip_rect.y || canvas_position.x >= clip_rect.x + clip_rect.z || canvas_position.y >= clip_rect.y + clip_rect.w) discard;
}
