extends "res://scripts/ui/shared/modal_view.gd"
signal accepted

# Every episode uses the same frame, header, shader button and arrow.
# Only the weapon/key sprite and its authored bounds depend on the item.
func configure(artwork: String, caption: String) -> void:
	add_shade(0.65)
	var frame: Array = episode_components["item_keys"]
	var content: Array = episode_components.get(artwork,frame)
	COMPONENTS.draw(self,[frame[0],frame[1]],"background")
	for part: Dictionary in content:
		if str(part.get("source","")).begins_with("Weapons/"):
			COMPONENTS.draw(self,[part])
	_draw_brushes("item_keys",self)
	COMPONENTS.draw(self,frame,"foreground")
	_adopt_button_icons(self)
	_text(caption,Rect2(102,71,594,31),24,false,true)
	_hit("@loc:ui.main.37",Rect2(656,326,65,58),func(): accepted.emit())
