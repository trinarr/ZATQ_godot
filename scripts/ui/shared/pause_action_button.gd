extends "res://scripts/ui/shared/torn_text_button.gd"
const COMPONENTS := preload("res://scripts/ui/flash_components.gd")
# Pause-specific original shadow. Behavior is shared with every text button.
func configure(action_name: String, value: String, shadow: Array) -> void:
 name = LOC.text(action_name)
 tooltip_text = LOC.text(action_name)
 size = Vector2(568,118)
 COMPONENTS.draw(self,shadow,"background")
 move_child(get_child(get_child_count()-1),0)
 set_caption(value,FONT,45)
