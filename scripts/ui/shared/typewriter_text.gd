extends RefCounted
# Keep the complete text shaped and wrapped; reveal glyphs without moving it.
const CHARACTERS_PER_SECOND := 42.0
static func duration(label: Label) -> float:
	return float(label.get_total_character_count())/CHARACTERS_PER_SECOND
static func apply(label: Label, seconds: float, complete: bool = false) -> void:
	label.visible_characters_behavior=TextServer.VC_CHARS_AFTER_SHAPING
	label.visible_characters=label.get_total_character_count() if complete else mini(label.get_total_character_count(),maxi(0,floori(seconds*CHARACTERS_PER_SECOND)))
	var shadow: Label=label.get("shadow_pass")
	if shadow!=null:
		shadow.visible_characters_behavior=label.visible_characters_behavior
		shadow.visible_characters=label.visible_characters
