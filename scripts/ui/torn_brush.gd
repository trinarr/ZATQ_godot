extends ColorRect
const SHADER := preload("res://shaders/torn_button.gdshader")
var brush_color := Color("803c3c")
var brush_seed := 1.0
func _ready()->void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 var shader_material := ShaderMaterial.new()
 shader_material.shader = SHADER
 shader_material.set_shader_parameter("brush_color",brush_color)
 shader_material.set_shader_parameter("seed",brush_seed)
 material = shader_material
 resized.connect(_update_size)
 _update_size()
func _update_size()->void:
 if material is ShaderMaterial:material.set_shader_parameter("button_size",size)
