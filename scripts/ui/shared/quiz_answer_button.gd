extends "res://scripts/ui/shared/torn_button.gd"
const OPTICAL := preload("res://scripts/ui/shared/optical_text_layout.gd")
const FONT: Font = preload("res://fonts/oswald/Oswald-Medium.ttf")
var caption: Label
var selected := false
func configure(text: String) -> void:
	caption = preload("res://scripts/ui/shared/shader_text.gd").new()
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.text = text
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font",FONT)
	caption.add_theme_color_override("font_color",Color("e1e1e1"))
	add_child(caption)
	_layout_content()
	set_selected(false)
func set_selected(value: bool) -> void:
	selected = value
	set_palette(Color("803c3c") if value else Color("353535"))
func _layout_content() -> void:
	super()
	if not is_instance_valid(caption): return
	var area := Rect2(Vector2(24,10),(size-Vector2(48,20)).max(Vector2.ONE))
	var pixels := 32
	while pixels > 18:
		var paragraph := TextParagraph.new()
		paragraph.width = area.size.x
		paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		paragraph.add_string(caption.text,FONT,pixels)
		if paragraph.get_size().y+caption.get_theme_constant("line_spacing")*(paragraph.get_line_count()-1) <= area.size.y: break
		pixels -= 1
	caption.add_theme_font_size_override("font_size",pixels)
	OPTICAL.center(caption,area)
