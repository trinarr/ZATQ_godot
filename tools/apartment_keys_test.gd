extends SceneTree
const SKETCH := preload("res://scripts/ui/sketch_highlight.gd")
var checks := 0
var failures := 0
var ui: Control
var quest: Node

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func key_layers() -> Array:
	return ui.viewport_canvas.art_layer.get_children().filter(func(child):
		return child is TextureRect and child.material == null and child.texture != null and child.texture.resource_path.ends_with("/hall_keys.png"))

func key_outlines() -> Array:
	return ui.world_layer.get_children().filter(func(child):
		return child.get_script() == SKETCH and child.region_id == "hall_keys")

func check_empty_hall() -> void:
	check(quest.current_id == "transport", "panel returns to hallway")
	check(key_layers().is_empty(), "collected keys absent from art")
	check(key_outlines().is_empty(), "key holder outline absent")
	var buttons: Array = ui.world_layer.get_children().filter(func(child): return child is Button)
	check(buttons.size() == 3, "collected key hotspot removed; other three objects remain")
	check(ui.overlay == null and not quest.scene_narrative_pending(), "hallway resumes immediately without narrative or modal")

func run() -> void:
	quest = root.get_node("Quest")
	quest.save_path = "user://apartment_keys_test.json"
	quest.tmp_path = "user://apartment_keys_test.tmp"
	quest.backup_path = "user://apartment_keys_test.bak"
	quest.sound_enabled = true
	ui = load("res://scenes/Main.tscn").instantiate()
	root.add_child(ui)
	ui.playing = true
	quest.new_game(1)
	quest._enter("transport")
	check(key_layers().size() == 1, "keys are a separate layer before pickup, including during narrative")
	check(ui.viewport_canvas.art_layer.get_child(0).texture != null, "empty hallway background resource loads")
	quest.take_apartment_keys()
	check(quest.current_id == "transport" and not quest.flags.TakenKey, "narrative blocks pickup")
	quest.dismiss_scene_narrative()
	check(key_outlines().size() == 1, "one key holder outline available after narrative")
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/apartment_preview.json"))
	var key_index := -1
	for i: int in definitions.transport.size():
		if definitions.transport[i].region == "hall_keys": key_index = i
	var buttons: Array = ui.world_layer.get_children().filter(func(child): return child is Button)
	var key_button: Button = buttons[key_index]
	key_button.pressed.emit()
	check(quest.current_id == "keys" and quest.popup_origin == "transport", "real key hotspot opens graph item node")
	check(quest.flags.TakenKey, "existing story pickup marks keys collected")
	check(ui.effects.playing and ui.effects.stream.resource_path.ends_with("/KeysTake.mp3"), "pickup plays its own sound")
	check(is_instance_valid(ui.overlay) and ui.overlay.find_child("ItemTitle", true, false) != null, "standard new item panel shown")
	check(ui.overlay.dimmer.mouse_filter == Control.MOUSE_FILTER_STOP, "item panel blocks underlying scene")
	var writes: int = quest.save_writes
	key_button.pressed.emit()
	quest.take_apartment_keys()
	check(quest.current_id == "keys" and quest.save_writes == writes, "double tap cannot grant keys again")
	var saved: Variant = quest._read(quest.save_path)
	check(saved.current_id == "keys" and saved.flags.TakenKey and quest._valid(saved), "save preserves pickup and open panel")
	# Resume from menu while the item panel is still open.
	ui._show_menu()
	quest.flags.TakenKey = false
	quest._load_save()
	ui.playing = true
	ui._show_story()
	check(is_instance_valid(ui.overlay) and quest.current_id == "keys", "resume reconstructs open item panel")
	check(key_layers().is_empty(), "resumed panel reconstructs empty hallway backdrop")
	ui.overlay.accepted.emit()
	check_empty_hall()
	check(not ui.effects.playing and ui.effects.stream.resource_path.ends_with("/KeysTake.mp3"), "return from resumed item panel does not replay room entry sound")
	quest.navigate_apartment("morning_choice")
	quest.dismiss_scene_narrative()
	quest.navigate_apartment("transport")
	check(ui.effects.playing and ui.effects.stream.resource_path.ends_with("/FootSteps.mp3"), "real hallway transition still plays footsteps")
	check_empty_hall()
	quest.take_apartment_keys()
	check(quest.current_id == "transport" and ui.overlay == null, "pickup cannot repeat after returning")
	quest.flags.TakenKey = false
	quest._load_save()
	ui._show_story()
	check(quest.flags.TakenKey, "collected flag survives later hallway save")
	check_empty_hall()
	quest.new_game(1)
	quest._enter("transport")
	quest.dismiss_scene_narrative()
	check(not quest.flags.TakenKey and key_layers().size() == 1 and key_outlines().size() == 1, "new game restores keys and hotspot")
	quest.take_apartment_keys()
	ui.overlay.accepted.emit()
	check(not ui.effects.playing and ui.effects.stream.resource_path.ends_with("/KeysTake.mp3"), "direct item closure suppresses implicit entrance sound")
	quest.flags.TakenKey = false
	quest.take_apartment_keys()
	quest.nodes.keys.choices[0].sound = "KeysTake"
	ui.overlay.accepted.emit()
	check(ui.effects.playing and ui.effects.stream.resource_path.ends_with("/KeysTake.mp3"), "explicit choice sound remains allowed on return")
	ui.effects.stop()
	ui.effects.stream = null
	await process_frame
	ui.free()
	await process_frame
	for path: String in [quest.save_path, quest.tmp_path, quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("Apartment keys: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
