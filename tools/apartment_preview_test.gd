extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var quest: Node = root.get_node("Quest")
	quest.save_path = "user://apartment_test.json"
	quest.tmp_path = "user://apartment_test.tmp"
	quest.backup_path = "user://apartment_test.bak"
	quest.sound_enabled = false
	var ui: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(ui)
	ui.playing = true
	quest.new_game(1)
	quest._enter("morning_choice")
	for room: String in ["morning_choice", "transport", "morning_choice"]:
		check(quest.current_id == room, "correct room after passage")
		await process_frame
		var glows: Array = []
		var hits: Array = []
		for child: Node in ui.world_layer.get_children():
			if child.get_meta("interactive_highlight",false): glows.append(child)
			if child is Button: hits.append(child)
		check(glows.size() == (4 if room == "morning_choice" else 3), "all reviewed highlights visible")
		check(hits.size() == 1, "only passage clickable")
		check(ui.viewport_canvas.episode_timeline == null, "no old opening animation")
		var flags: Dictionary = quest.flags.duplicate(true)
		for index: int in range(quest.available_choices().size()): quest.choose(index)
		check(quest.current_id == room and quest.flags == flags, "legacy choices remain inert")
		quest.navigate_apartment("lift")
		check(quest.current_id == room, "unreviewed exit blocked")
		var hit: Button = hits[0]
		check(hit._has_point(hit.size/2), "passage center clickable")
		check(not hit._has_point(Vector2(-1,-1)), "mask rejects outside")
		hit.pressed.emit()
		check(quest.flags == flags, "navigation does not collect keys or change flags")
		var snapshot: Variant = quest._read(quest.save_path)
		check(snapshot != null and snapshot.current_id == quest.current_id, "room saved after passage")
	ui.free()
	await process_frame
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("Apartment preview: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
