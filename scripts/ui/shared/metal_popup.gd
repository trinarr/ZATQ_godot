extends "res://scripts/ui/shared/modal_view.gd"
# Shared native frame for item and result popups. Textures are reused, not copied.
static var header_parts: Dictionary = {}
const BODY_RECT := Rect2(51,30,707,394)
const HEADER_RECT := Rect2(35,0,729,60)
const SUBTITLE_RECT := Rect2(75.5,60,642.5,47.5)

func draw_metal_subtitle(text: String, name: String) -> Label:
	var strip: Dictionary = episode_components.item_keys[1].duplicate(true)
	strip.rect = [SUBTITLE_RECT.position.x,SUBTITLE_RECT.position.y,SUBTITLE_RECT.size.x,SUBTITLE_RECT.size.y]
	COMPONENTS.draw(self,[strip],"background")
	var label := centered_panel_text(text,SUBTITLE_RECT,24)
	label.name = name
	return label

func centered_panel_text(text: String, panel: Rect2, font_size: int, title: bool = false) -> Label:
	var value: String = LOC.text(text).to_upper() if title else LOC.text(text)
	var font: Font = TITLE_FONT if title else BODY_FONT
	while font_size > 12 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size*2).x > (panel.size.x-16)*2:
		font_size -= 1
	var label := _centered_text(text,panel.grow_individual(-8,0,-8,0),font_size,title,true)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	OPTICAL.center(label,LAYOUT.scaled_rect(panel.grow_individual(-8,0,-8,0)))
	label.add_theme_color_override("font_color",Color("cccccc"))
	return label
func draw_metal_body(rect: Rect2) -> void:
	var part: Dictionary = episode_components.item_keys[0].duplicate(true)
	part.rect = [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
	COMPONENTS.draw(self,[part],"background")
func draw_metal_header(text: String) -> Label:
	if header_parts.is_empty():
		header_parts = JSON.parse_string(FileAccess.get_file_as_string("res://data/item_popup_components.json"))
	var before := get_child_count()
	var parts: Array = header_parts.header.duplicate(true)
	for part: Dictionary in parts: part.rect[0] = HEADER_RECT.position.x
	COMPONENTS.draw(self,parts,"background")
	var title := centered_panel_text(text,HEADER_RECT,24,true)
	title.add_theme_color_override("font_color",Color("cccccc"))
	for i: int in range(before,get_child_count()):
		get_child(i).set_meta("movie_clip_fixed",true)
		# Header and its shadow overlay the subtitle even when drawn first.
		get_child(i).z_index = 1
	return title
