extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	TranslationServer.set_locale("ru")
	var quest := root.get_node("Quest")
	quest.save_path = "user://item_popup_test.json"
	quest.tmp_path = "user://item_popup_test.tmp"
	quest.backup_path = "user://item_popup_test.bak"
	quest.sound_enabled = false
	var ui: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.playing = true
	quest.new_game(1)
	quest._enter("transport")
	await process_frame
	var old_screen: Control = ui.screen
	var old_art: Node = ui.viewport_canvas.art_layer.get_child(0)
	quest._enter("keys")
	await process_frame
	check(ui.screen == old_screen,"pickup preserves current screen")
	check(ui.viewport_canvas.art_layer.get_child(0) == old_art,"pickup preserves door background")
	check(quest.popup_origin == "transport","origin saved for resuming popup")
	check(ui.overlay != null,"item is tracked modal")
	var saved: Dictionary = quest._snapshot()
	check(quest._valid(saved),"popup origin is valid save data")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("popup_origin")
	check(quest._valid(legacy),"legacy saves remain valid")
	quest.popup_origin = ""
	quest._load_save()
	check(quest.popup_origin == "transport","origin survives save reload")
	check(ui.overlay.find_child("ItemTitle",true,false).text == "Получен новый предмет:","localized Flash title")
	check(ui.overlay.find_child("ItemDescription",true,false).position == Vector2(204,142),"authored description coordinates")
	check(ui.overlay.dimmer.mouse_filter == Control.MOUSE_FILTER_STOP,"shade blocks underlying controls")
	var title: Label = ui.overlay.find_child("ItemTitle",true,false)
	check(title.shadow_pass.material.shader == load("res://shaders/text_shadow.gdshader"),"title uses shader glyph pass")
	title.text = "Translated title"
	title.add_theme_font_size_override("font_size",39)
	await process_frame
	check(title.shadow_pass.text == title.text and title.shadow_pass.get_theme_font_size("font_size")==39,"shadow follows text and fitting")
	ui._show_menu()
	ui.playing = true
	ui._show_story()
	await process_frame
	check(ui.viewport_canvas.component_background_active,"resume reconstructs component backdrop")
	check(ui.viewport_canvas.art_layer.get_child(0).texture == old_art.texture if is_instance_valid(old_art) else ui.viewport_canvas.art_layer.get_child_count()>0,"resume has scene art")
	# Explicit graph background overrides the live scene.
	quest.nodes.keys.background_art = "layout_bg_morning_choice"
	ui._show_story()
	await process_frame
	var expected: Array = ui.episode_components.layout_bg_morning_choice
	check(ui.viewport_canvas.art_layer.get_child(0).texture == load("res://assets/flash_ui/"+expected[0].texture),"graph backdrop override")
	quest.nodes.keys.erase("background_art")
	ui.overlay.accepted.emit()
	await process_frame
	check(quest.current_id == "transport" and ui.overlay == null,"accept resumes normal routing")
	ui.free()
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("Item popup: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
