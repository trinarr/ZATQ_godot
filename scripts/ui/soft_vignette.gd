extends ColorRect
# Smooth authored QTE edge tint without a full-screen PNG or texture sampling.
const SHADER := preload("res://shaders/soft_vignette.gdshader")
func configure(part: Dictionary) -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 color=Color.WHITE
 var paint:=ShaderMaterial.new()
 paint.shader=SHADER
 material=paint
 var spec: Dictionary=part.vignette
 paint.set_shader_parameter("source_size",Vector2(spec.size[0],spec.size[1]))
 paint.set_shader_parameter("center",Vector2(spec.center[0],spec.center[1]))
 var rgb: Array=spec.color
 paint.set_shader_parameter("vignette_color",Color(rgb[0],rgb[1],rgb[2]))
 for key: String in ["half_segment","aspect","falloff_width","falloff_power","base_alpha","amplitude"]:
  paint.set_shader_parameter(key,float(spec[key]))
 # EpisodeTimeline applies authored color/alpha without replacing this shader.
 set_meta("interactive_highlight",true)
