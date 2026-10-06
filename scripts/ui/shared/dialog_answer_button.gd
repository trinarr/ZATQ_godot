extends Button
const LOC := preload("res://scripts/core/localization.gd")
const COMPONENTS := preload("res://scripts/ui/flash_components.gd")
const FONT: Font = preload("res://fonts/flash/font_2.ttf")
static var parts: Dictionary = {}
var caption: Label
var background: TextureRect
var unavailable_mark: TextureRect
var caption_size := 48
func configure(value: String, available: bool = true, font_size: int = 24) -> void:
 if parts.is_empty(): parts = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialog_components.json"))
 name = LOC.text(value) if available else "UnavailableAnswer"
 tooltip_text = LOC.text(value) if available else ""
 size = Vector2(694,128)
 mouse_filter = Control.MOUSE_FILTER_STOP
 mouse_force_pass_scroll_events = false
 disabled = not available
 flat = true
 for style: String in ["normal","hover","pressed","disabled"]: add_theme_stylebox_override(style,StyleBoxEmpty.new())
 var focus := StyleBoxFlat.new()
 focus.bg_color = Color.TRANSPARENT
 focus.border_color = Color("c8c8c8")
 focus.set_border_width_all(2)
 add_theme_stylebox_override("focus",focus)
 COMPONENTS.draw(self,parts.decision_plate)
 background = get_child(0)
 if not available:
  COMPONENTS.draw(self,parts.decision_disabled_mark)
  unavailable_mark = get_child(1)
 else:
  caption = preload("res://scripts/ui/shared/shader_text.gd").new()
  caption.name = "Caption"
  caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
  caption.text = LOC.text(value)
  caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  caption.clip_text = true
  caption.add_theme_font_override("font",FONT)
  caption.add_theme_color_override("font_color",Color("c8c8c8"))
  caption_size = font_size*2
  add_child(caption)
 resized.connect(_layout_caption)
 for event: String in ["mouse_entered","mouse_exited","button_down","button_up"]: connect(event,_update_state)
 _layout_caption()
 _update_state()
func _layout_caption() -> void:
 if not is_instance_valid(caption): return
 caption.position = Vector2(30,12)
 caption.size = (size-Vector2(60,24)).max(Vector2.ONE)
 var fitted := caption_size
 while fitted>16 and FONT.get_multiline_string_size(caption.text,HORIZONTAL_ALIGNMENT_CENTER,caption.size.x,fitted).y>caption.size.y: fitted-=1
 caption.add_theme_font_size_override("font_size",fitted)
func _update_state() -> void:
 # Symbol 97's endpoint tint is 0.69921875; the caption does not move.
 var tint := 0.69921875 if disabled or is_pressed() else 0.80078125 if is_hovered() else 1.0
 if is_instance_valid(background): background.self_modulate = Color(tint,tint,tint)
