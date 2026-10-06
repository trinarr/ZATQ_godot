shader_type canvas_item;
render_mode unshaded;

// Adapted from Hangman shaders/hint_icon_extrusion_shadow.gdshader.
// Recolor the icon silhouette, independently of the foreground's brown tint.
uniform vec4 shadow_color : source_color = vec4(0.06, 0.035, 0.035, 0.82);
varying float vertex_alpha;

void vertex() {
	vertex_alpha = COLOR.a;
}

void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	COLOR = vec4(shadow_color.rgb, alpha * alpha * vertex_alpha * shadow_color.a);
}
