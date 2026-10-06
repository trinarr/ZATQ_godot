extends Button
# Shared input, shader and states. Text and icons are separate components.
const BRUSH := preload("res://scripts/ui/torn_brush.gd")
var background: ColorRect
var brush_color := Color("803c3c")
var brush_seed := 1.0
func _init() -> void:
 set_meta("torn_button",true)
 mouse_filter = Control.MOUSE_FILTER_STOP
 mouse_force_pass_scroll_events = false
 flat = true
 var empty := StyleBoxEmpty.new()
 for style: String in ["normal","hover","pressed","disabled"]:
  add_theme_stylebox_override(style,empty)
 var focus := StyleBoxFlat.new()
 focus.bg_color = Color.TRANSPARENT
 focus.border_color = Color("e1e1e1")
 focus.set_border_width_all(2)
 add_theme_stylebox_override("focus",focus)
 background = BRUSH.new()
 background.name = "Background"
 add_child(background)
 resized.connect(_layout_content)
 for event: String in ["mouse_entered","mouse_exited","button_down","button_up","focus_entered","focus_exited"]:
  connect(event,_update_state)
func _ready() -> void:
 _layout_content()
 _update_state()
func set_palette(color: Color, seed_value: float = 1.0) -> void:
 brush_color = color
 brush_seed = seed_value
 background.brush_color = color
 background.brush_seed = seed_value
 if background.material is ShaderMaterial:
  background.material.set_shader_parameter("seed",seed_value)
 _update_state()
func _layout_content() -> void:
 background.size = size
func _update_state() -> void:
 var tint := brush_color.darkened(0.2) if is_pressed() else brush_color.lightened(0.12) if is_hovered() else brush_color
 if disabled: tint = tint.darkened(0.3)
 if background.material is ShaderMaterial:
  background.material.set_shader_parameter("brush_color",tint)
