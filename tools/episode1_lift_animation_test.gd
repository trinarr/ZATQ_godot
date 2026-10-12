extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	TranslationServer.set_locale("ru")
	var quest: Node = root.get_node("Quest")
	quest.save_path = "user://new_lift_test.json"
	quest.tmp_path = "user://new_lift_test.tmp"
	quest.backup_path = "user://new_lift_test.bak"
	quest.sound_enabled = false
	var ui: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(ui)
	ui.playing = true
	quest.new_game(1)
	quest._enter("transport")
	var entry: Button = ui.world_layer.find_child("Выйти к лифту",true,false)
	if entry == null: entry = ui.world_layer.find_child("Go to the elevator",true,false)
	check(entry != null,"entry door has a hotspot")
	var old_flags: Dictionary = quest.flags.duplicate(true)
	entry.pressed.emit()
	check(quest.current_id == "lift", "hall door enters elevator landing")
	check(quest.flags == old_flags,"entry does not collect keys or select car")
	var landing: Control = ui.elevator_view
	check(landing != null and ui.viewport_canvas.episode_timeline == null,"new landing replaces original animation")
	check(landing.progress == 0.0 and landing.door_clip.visible,"doors initially closed")
	check(not landing.down_light.visible,"call button initially unlit")
	check(landing.light_material.get_shader_parameter("light_loss") == 0.0,"landing light mask disabled by default")
	check(landing.left_door.texture != landing.right_door.texture,"independent door textures")
	check(landing.door_clip.clip_contents,"doors retract behind jambs")
	check(landing.call_hit.get_rect() == Rect2(0,0,1600,960),"calling hit covers whole scene")
	check(landing.call_hit.get_rect().has_point(Vector2(400,200)),"tap away from call panel works")
	landing.call_hit.pressed.emit()
	landing = ui.elevator_view
	check(quest.current_id == "lift_button","same scene changes to open state")
	check(landing.down_light.visible and landing.opening,"pressed light accompanies opening")
	check(landing.progress == 0.0,"opening starts at closed pose")
	landing.call_hit.pressed.emit()
	check(quest.current_id == "lift_button","tap during opening cannot skip ahead")
	landing._process(0.65)
	check(landing.progress > 0.0 and landing.progress < 1.0,"doors move gradually")
	check(landing.left_door.position.x < 0.0 and landing.right_door.position.x > landing.door_clip.size.x/2.0,"leaves move in opposite directions")
	ui._show_pause()
	var progress: float = landing.progress
	landing._process(1.0)
	check(landing.progress == progress,"pause freezes opening")
	ui._resume()
	check(ui.elevator_view == landing,"resume preserves exact opening pose")
	landing._process(2.0)
	check(landing.progress == 1.0 and not landing.door_clip.visible,"fully open cabin revealed")
	check(not ui.screen.get_meta("episode_animation_block",false),"opening releases interaction lock")
	var saved: Dictionary = quest._read(quest.save_path)
	check(saved.current_id == "lift_button","open state saved")
	ui.previous_node = ""
	ui._show_story()
	check(ui.elevator_view.progress == 1.0 and not ui.elevator_view.opening,"saved open state restores without replay")
	check(ui.elevator_view.light_material.get_shader_parameter("light_loss") == 0.0,"no flicker after restore")
	var mask: Image = ui.elevator_view.MASK.get_image()
	if mask.is_compressed(): mask.decompress()
	check(mask.get_pixel(800,450).r < .02,"mask protects cabin")
	check(mask.get_pixel(1085,440).r < .02,"mask protects independent call light")
	check(mask.get_pixel(530,300).r > .5,"mask can affect landing wall")
	var expected: String = "Джек нажал на кнопку первого этажа, и лифт понес его в неизвестность..."
	if TranslationServer.get_locale().begins_with("ru"):
		check(quest.current().text == expected,"exact original story text restored")
	ui.elevator_view.call_hit.pressed.emit()
	check(quest.current_id == "city_foot","open-state tap advances to original walking route")
	quest.flags.Auto = 1
	quest._enter("lift_button")
	ui.elevator_view.call_hit.pressed.emit()
	check(quest.current_id == "city_car","original car route remains intact")
	ui.free()
	await process_frame
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("New elevator: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
