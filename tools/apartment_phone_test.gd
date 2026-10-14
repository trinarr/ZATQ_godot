extends SceneTree
const SKETCH := preload("res://scripts/ui/sketch_highlight.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func outlines(ui: Control) -> Array:
	return ui.world_layer.get_children().filter(func(child): return child.get_script() == SKETCH)
func buttons(ui: Control) -> Array:
	return ui.world_layer.get_children().filter(func(child): return child is Button)
func run() -> void:
	var quest: Node = root.get_node("Quest")
	quest.save_path = "user://apartment_phone_test.json"
	quest.tmp_path = "user://apartment_phone_test.tmp"
	quest.backup_path = "user://apartment_phone_test.bak"
	quest.sound_enabled = false
	var ui: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(ui)
	ui.playing = true
	quest.new_game(1)
	quest._enter("morning_choice")
	quest.inspect_apartment_object("apartment_phone")
	check(quest.current_id == "morning_choice", "room introduction blocks phone inspection")
	quest.dismiss_scene_narrative()
	check(outlines(ui).size() == 4 and buttons(ui).size() == 4, "room starts with four neutral interactive objects")
	var flags: Dictionary = quest.flags.duplicate(true)
	buttons(ui)[1].pressed.emit()
	check(quest.current_id == "apartment_phone" and quest.current().kind == "object_inspection", "phone opens reusable inspection type")
	check(quest.flags == flags, "inspection preserves existing story variables")
	check(ui.narrative_layer.active == 1 and ui.narrative_layer.blocks[0].label.text == "ТЕСТ", "inspection uses existing narrative placeholder")
	var selected: Array = outlines(ui)
	check(selected.size() == 1 and selected[0].region_id == "living_phone" and selected[0].active, "only selected phone outline remains active")
	check(selected[0].fill_material.get_shader_parameter("glow_color") == SKETCH.ACTIVE_COLOR, "phone fill uses configurable active color")
	for child: Node in selected[0].get_children():
		if child is Line2D:
			check(is_equal_approx(child.default_color.r, SKETCH.ACTIVE_COLOR.r) and is_equal_approx(child.default_color.g, SKETCH.ACTIVE_COLOR.g), "outline and every halo use active color")
	check(buttons(ui).size() == 1 and buttons(ui)[0].size == Vector2(1600, 960), "selected object has no hotspot; one fullscreen narrative dismissal remains")
	quest.inspect_apartment_object("apartment_phone")
	quest.navigate_apartment("transport")
	check(quest.current_id == "apartment_phone", "inspection cannot retrigger or navigate through hidden objects")
	ui._show_pause()
	check(quest.current_id == "apartment_phone", "pause retains inspection state")
	ui._resume()
	check(outlines(ui).size() == 1 and outlines(ui)[0].active, "resume restores active phone")
	var restored: Node = load("res://scripts/core/quest_state.gd").new()
	restored.save_path = quest.save_path
	restored.tmp_path = quest.tmp_path
	restored.backup_path = quest.backup_path
	root.add_child(restored)
	check(restored.current_id == "apartment_phone" and restored.flags == flags, "save restores phone inspection")
	restored.free()
	if "--screenshots" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://apartment_phone_active.png")
	buttons(ui)[0].pressed.emit()
	check(quest.current_id == "morning_choice" and not quest.scene_narrative_pending(), "narrative tap returns to room without replaying introduction")
	check(ui.narrative_layer.active == 0 and outlines(ui).size() == 4 and buttons(ui).size() == 4, "narrative disappears and all interactive objects return")
	for outline: Node in outlines(ui):
		check(not outline.active and outline.fill_material.get_shader_parameter("glow_color") == Color.WHITE, "all restored outlines are neutral white")
	buttons(ui)[1].pressed.emit()
	check(quest.current_id == "apartment_phone", "phone is clickable again after dismissal")
	buttons(ui)[0].pressed.emit()
	check(quest.flags == flags, "repeated inspection does not alter story variables")
	ui.free()
	await process_frame
	for path: String in [quest.save_path, quest.tmp_path, quest.backup_path]:
		DirAccess.remove_absolute(path)
	print("Apartment phone: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
