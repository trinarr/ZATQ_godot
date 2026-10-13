extends SceneTree
const SKETCH := preload("res://scripts/ui/sketch_highlight.gd")
var failures := 0
var checks := 0
var ui: Control
var quest: Node
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func room_buttons() -> Array:
	return ui.world_layer.get_children().filter(func(child): return child is Button)
func outlines() -> Array:
	return ui.world_layer.get_children().filter(func(child): return child.get_script() == SKETCH)
func check_intro(room: String, text: String) -> void:
	check(quest.current_id == room and not quest.scene_narrative_seen(room), "first room visit waits for narrative tap")
	check(outlines().is_empty(), "narrative has no visible or interactive outlines")
	var buttons: Array = room_buttons()
	check(buttons.size() == 1, "only narrative dismissal is clickable")
	check(buttons[0].position == Vector2.ZERO and buttons[0].size == Vector2(1600,960), "narrative tap covers the scene")
	check(ui.narrative_layer.active == 1 and ui.narrative_layer.blocks[0].label.text == text, "standard narrative displays exact placeholder")
	check(ui.narrative_layer.blocks[0].label.visible, "narrative label is shown")
func check_ready(room: String) -> void:
	check(quest.current_id == room and quest.scene_narrative_seen(room), "room introduction has been dismissed")
	check(outlines().size() == 4 and room_buttons().size() == 4, "all four room outlines and hotspots are restored")
	check(ui.narrative_layer.active == 0, "no narrative remains over interactive room")
	check(ui.viewport_canvas.episode_timeline == null, "room does not restart the old opening animation")
func click_region(region: String) -> void:
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/apartment_preview.json"))
	var parts: Array = definitions[quest.current_id]
	var buttons: Array = room_buttons()
	for i: int in parts.size():
		if parts[i].region == region:
			buttons[i].pressed.emit()
			return
	check(false, "requested room hotspot exists: " + region)
func restored_state() -> Node:
	var restored: Node = load("res://scripts/core/quest_state.gd").new()
	restored.save_path = quest.save_path
	restored.tmp_path = quest.tmp_path
	restored.backup_path = quest.backup_path
	root.add_child(restored)
	return restored
func run() -> void:
	quest = root.get_node("Quest")
	quest.save_path = "user://apartment_test.json"
	quest.tmp_path = "user://apartment_test.tmp"
	quest.backup_path = "user://apartment_test.bak"
	quest.sound_enabled = false
	ui = load("res://scenes/Main.tscn").instantiate()
	root.add_child(ui)
	ui.playing = true
	quest.new_game(1)
	quest.choose(0)
	check(quest.current_id == "screams", "first city tap follows original story")
	quest.choose(0)
	check_intro("morning_choice", "ТЕСТ")
	quest.navigate_apartment("apartment_window")
	check(quest.current_id == "morning_choice", "window navigation blocked before dismissal")
	room_buttons()[0].pressed.emit()
	check_ready("morning_choice")
	var saved: Variant = quest._read(quest.save_path)
	check(saved.flags.get("ApartmentLivingIntroSeen", false), "living-room dismissal saved immediately")
	click_region("living_window")
	check(quest.current_id == "apartment_window", "window inspection opens after dismissal")
	quest.choose(0)
	check_ready("morning_choice")
	click_region("living_passage")
	check_intro("transport", "Тест")
	quest.navigate_apartment("morning_choice")
	check(quest.current_id == "transport", "hallway passages blocked during narrative")
	room_buttons()[0].pressed.emit()
	check_ready("transport")
	click_region("hall_passage")
	check_ready("morning_choice")
	click_region("living_passage")
	check_ready("transport")
	click_region("hall_passage")
	check_ready("morning_choice")
	var restored := restored_state()
	check(restored.current_id == "morning_choice" and restored.scene_narrative_seen("morning_choice") and restored.scene_narrative_seen("transport"), "reload preserves both dismissed room introductions")
	restored.free()
	var flags: Dictionary = quest.flags.duplicate(true)
	for index: int in quest.available_choices().size(): quest.choose(index)
	quest.dismiss_scene_narrative()
	check(quest.current_id == "morning_choice" and quest.flags == flags, "legacy choices and repeated dismissal cannot advance story")
	quest.navigate_apartment("city_foot")
	check(quest.current_id == "morning_choice", "unreviewed exit remains blocked")
	quest.new_game(1)
	check(not quest.scene_narrative_seen("morning_choice") and not quest.scene_narrative_seen("transport"), "new game resets both introductions")
	quest.choose(0)
	quest.choose(0)
	restored = restored_state()
	check(restored.current_id == "morning_choice" and not restored.scene_narrative_seen("morning_choice"), "reload before tap keeps the narrative pending")
	restored.free()
	var legacy: Dictionary = quest._snapshot()
	legacy.flags.erase("ApartmentLivingIntroSeen")
	legacy.flags.erase("ApartmentHallIntroSeen")
	check(quest._valid(legacy), "older saves without intro flags remain valid")
	legacy.flags.ApartmentHallIntroSeen = "invalid"
	check(not quest._valid(legacy), "malformed intro flag rejected")
	ui.free()
	await process_frame
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("Apartment preview: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
