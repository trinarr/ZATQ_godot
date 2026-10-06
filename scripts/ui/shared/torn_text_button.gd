extends "res://scripts/ui/shared/torn_button.gd"
const LOC := preload("res://scripts/core/localization.gd")
const FONT: Font = preload("res://fonts/flash/font_1.ttf")
var caption: Label
@export var caption_font: Font = FONT
@export var caption_size := 44
@export var caption_key := "":
 set(value):
  caption_key = value
  _refresh_caption()
var padding := Vector2(20,8)
func _init() -> void:
 super()
 caption = preload("res://scripts/ui/shared/shader_text.gd").new()
 caption.name = "Caption"
 caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
 caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 caption.autowrap_mode = TextServer.AUTOWRAP_OFF
 caption.clip_text = true
 caption.set_meta("button_caption",true)
 caption.add_theme_color_override("font_color",Color("e1e1e1"))
 add_child(caption)
 _refresh_caption()
func set_caption(value: String, font: Font = null, font_size: int = -1) -> void:
 caption_key = value
 if font != null: caption_font = font
 if font_size > 0: caption_size = font_size
 _refresh_caption()
func _refresh_caption() -> void:
 if not is_instance_valid(caption): return
 caption.text = " ".join(LOC.text(caption_key).replace("\r"," ").replace("\n"," ").split(" ",false))
 _layout_content()
func _layout_content() -> void:
 super()
 if not is_instance_valid(caption): return
 caption.position = padding
 caption.size = (size-padding*2).max(Vector2.ONE)
 var fitted := caption_size
 while fitted>1 and (caption_font.get_string_size(caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted).x>caption.size.x or caption_font.get_height(fitted)>caption.size.y):
  fitted -= 1
 caption.add_theme_font_override("font",caption_font)
 caption.add_theme_font_size_override("font_size",fitted)
func _notification(what: int) -> void:
 if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(caption): set_caption(caption_key)
