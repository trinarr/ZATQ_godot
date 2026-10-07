extends SceneTree
const RESULT := preload("res://scenes/shared/ResultPopup.tscn")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	TranslationServer.set_locale("ru")
	var quest: Node = root.get_node("Quest")
	quest.save_path="user://result_popup_test.json";quest.tmp_path="user://result_popup_test.tmp";quest.backup_path="user://result_popup_test.bak"
	quest.sound_enabled=false
	# Standalone result view is independent of Main and emits routing signals.
	for alive: bool in [false,true]:
		var panel: Control = RESULT.instantiate()
		root.add_child(panel)
		panel.configure({"kind":"city_ending" if alive else "city_death","text":"История результата"},{"losses":8,"endings":[6]},3,true)
		await process_frame
		check(panel.get_script().get_base_script()==load("res://scripts/ui/shared/metal_popup.gd"),"result shares item popup base")
		check(panel.find_child("ResultTitle",true,false).text.to_lower()=="ваши результаты:","localized original header")
		check(panel.find_child("ResultCount",true,false).text==("1/3" if alive else "8"),"death and ending statistic semantics")
		check(panel.find_child("Следующий эпизод",true,false)!=null if alive else panel.find_child("Следующий эпизод",true,false)==null,"next episode only for successful ending")
		panel.free()
	var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
	await process_frame
	ui.playing=true;quest.new_game(1)
	quest._enter("transport")
	await process_frame
	var old_screen: Control=ui.screen
	var old_texture: Texture2D=ui.viewport_canvas.art_layer.get_child(0).texture
	quest._enter("death_2")
	await process_frame
	check(ui.screen==old_screen,"result preserves current scene")
	check(ui.viewport_canvas.art_layer.get_child(0).texture==old_texture,"result keeps the original backdrop")
	check(ui.overlay!=null and ui.overlay.get_script()==load("res://scripts/ui/shared/result_popup.gd"),"result is tracked modal")
	check(is_equal_approx(ui.overlay.dimmer.color.a,0.9),"result shade matches item shade")
	check(quest.popup_origin=="transport","result stores origin for reload")
	var body: TextureRect=ui.overlay.get_child(1)
	check(body.texture==load("res://assets/flash_ui/"+ui.episode_components.item_keys[0].texture),"result reuses item metal texture")
	for child: Node in ui.overlay.get_children():
		if child.has_method("configure_targets"): child.seek_frame(1)
	check(body.position.y<120,"result body uses original entrance")
	for child: Node in ui.overlay.get_children():
		if child.has_method("configure_targets"): child.seek_frame(100)
	check(body.position==Vector2(72,120) and body.size==Vector2(1458,788),"bounded authored metal body")
	var count_before: int=quest.episode1_stats.losses
	ui._show_menu();ui.playing=true;ui._show_story()
	await process_frame
	check(ui.viewport_canvas.art_layer.get_child(0).texture==old_texture,"resume restores pre-result backdrop")
	check(quest.episode1_stats.losses==count_before,"drawing result does not increment losses")
	ui.overlay.menu_requested.emit()
	check(ui.section=="menu" and not ui.playing,"menu signal routes correctly")
	ui.free()
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	print("Result popup: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
