extends "res://scripts/ui/shared/metal_popup.gd"
signal accepted

# Every episode uses the same frame, header, shader button and arrow.
# Only the weapon/key sprite and its authored bounds depend on the item.
func configure(artwork: String, caption: String) -> void:
	add_shade(0.9)
	var frame: Array = episode_components["item_keys"]
	var content: Array = episode_components.get(artwork,frame)
	draw_metal_body(BODY_RECT)

	for part: Dictionary in content:
		if str(part.get("source","")).begins_with("Weapons/"):
			COMPONENTS.draw(self,[part])
	_draw_brushes("item_keys",self)
	COMPONENTS.draw(self,frame,"foreground")
	_adopt_button_icons(self)
	var title := draw_metal_header("@loc:ui.item_popup.title")
	title.name = "ItemTitle"
	title.add_theme_color_override("font_color",Color("cccccc"))
	draw_metal_subtitle(caption,"ItemDescription")
	_hit("@loc:ui.main.37",Rect2(656,326,65,58),func(): accepted.emit())
