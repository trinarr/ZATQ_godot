extends "res://scripts/ui/shared/modal_view.gd"
# Shared native frame for item and result popups. Textures are reused, not copied.
static var header_parts: Dictionary = {}
func draw_metal_body(rect: Rect2) -> void:
	var part: Dictionary = episode_components.item_keys[0].duplicate(true)
	part.rect = [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
	COMPONENTS.draw(self,[part],"background")
func draw_metal_header(text: String, rect: Rect2, center: bool = false, x: float = 35.0) -> Label:
	if header_parts.is_empty():
		header_parts = JSON.parse_string(FileAccess.get_file_as_string("res://data/item_popup_components.json"))
	var parts: Array = header_parts.header.duplicate(true)
	for part: Dictionary in parts: part.rect[0] = x
	COMPONENTS.draw(self,parts,"background")
	var title := _text(text,rect,30,true,center)
	title.add_theme_color_override("font_color",Color("cccccc"))
	return title
