extends RefCounted
# Temporary art review: highlighted objects remain inert until their scenes are updated.
const HIGHLIGHT := preload("res://scripts/ui/interactive_highlight.gd")

static func draw(view: Control) -> void:
	var room: String = Quest.current_id
	view._component_backdrop("layout_bg_" + room)
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/apartment_preview.json"))
	for part: Dictionary in definitions[room]:
		var glow := HIGHLIGHT.new()
		glow.configure(part)
		view._world_host().add_child(glow)
		if part.region not in ["living_passage", "hall_passage"]: continue
		var target: String = "transport" if room == "morning_choice" else "morning_choice"
		var label: String = "@loc:ui.apartment.to_hall" if room == "morning_choice" else "@loc:ui.apartment.to_living"
		var r: Array = part.rect
		view._world_hit(label, Rect2(r[0],r[1],r[2],r[3]), func(): Quest.navigate_apartment(target), part.region)
