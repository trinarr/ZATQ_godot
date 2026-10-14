extends RefCounted
# Reviewed room passages, pickups and authored object inspections.
const HIGHLIGHT := preload("res://scripts/ui/interactive_highlight.gd")
const SKETCH := preload("res://scripts/ui/sketch_highlight.gd")

static func draw(view: Control) -> void:
	_draw_room(view, Quest.current_id)

static func draw_inspection(view: Control, node: Dictionary) -> void:
	_draw_room(view, str(node.inspection_origin), str(node.inspection_region))

static func _draw_room(view: Control, room: String, selected_region: String = "") -> void:
	view._component_backdrop("layout_bg_" + room)
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/apartment_preview.json"))
	for part: Dictionary in definitions[room]:
		if not Quest.matches(part.get("requires", {})): continue
		if not selected_region.is_empty() and part.region != selected_region: continue
		var outline := SKETCH.new()
		outline.configure(part)
		view._world_host().add_child(outline)
		if not selected_region.is_empty():
			outline.set_active(true)
			continue
		var is_transition: bool = part.region in ["living_tv", "living_window", "living_passage", "hall_passage", "hall_exit_door"]
		var target: String = "tv" if part.region == "living_tv" else "apartment_window" if part.region == "living_window" else "lift" if part.region == "hall_exit_door" else "transport" if room == "morning_choice" else "morning_choice"
		var label: String = "@loc:episode1.nodes.morning_choice__choice_1.data.text" if part.region == "living_tv" else "@loc:ui.main.45" if part.region == "living_window" else "@loc:ui.apartment.to_elevator" if part.region == "hall_exit_door" else "@loc:ui.apartment.to_hall" if room == "morning_choice" else "@loc:ui.apartment.to_living"
		var r: Array = part.rect
		var button: Button = view._world_hit(label if is_transition else part.region, Rect2(r[0],r[1],r[2],r[3]), func():
			var interaction: Dictionary = part.get("interaction", {})
			if interaction.get("type", "") == "object_inspection": Quest.inspect_apartment_object(str(interaction.target))
			elif is_transition: Quest.navigate_apartment(target)
			elif part.region == "hall_keys": Quest.take_apartment_keys(), part.region)
		outline.bind_feedback(button)
