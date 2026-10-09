extends SceneTree
const SHADER_TEXT := preload("res://scripts/ui/shared/shader_text.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func click(point: Vector2) -> void:
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		root.push_input(event,true)
		await process_frame
func touch(point: Vector2) -> void:
	for down: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 0; event.position = point; event.pressed = down
		Input.parse_input_event(event)
		await process_frame
func run() -> void:
	TranslationServer.set_locale("ru")
	Input.emulate_mouse_from_touch = true
	root.size = Vector2i(2048,920)
	var quest: Node = root.get_node("Quest")
	quest.save_path = "user://modal_shadow_regression.json"
	quest.tmp_path = "user://modal_shadow_regression.tmp"
	quest.backup_path = "user://modal_shadow_regression.bak"
	quest.sound_enabled = false
	var ui: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.playing = true
	quest.new_game(1)
	quest._enter("transport")
	await process_frame
	# Real routing and real touch emulation, not an unattached test popup.
	var key: Button = ui.screen.find_child(ui.LOC.text("@loc:ui.main.43"),true,false)
	check(key != null,"door scene exposes key hotspot")
	var point := key.get_global_rect().get_center()
	ui._show_pause()
	await ui.overlay.opening_tween.finished
	var pause: Control = ui.overlay
	key.pressed.emit()
	check(quest.current_id == "transport" and not quest.flags.TakenKey,"modal blocks even a queued hotspot action")
	await click(point)
	check(not ui.paused and ui.overlay == null,"shade mouse click resumes game")
	check(quest.current_id == "transport" and not quest.flags.TakenKey,"shade mouse click does not collect key")
	ui._show_pause()
	await ui.overlay.opening_tween.finished
	await touch(point)
	check(not ui.paused and ui.overlay == null,"shade touch resumes game")
	check(quest.current_id == "transport" and not quest.flags.TakenKey,"emulated touch does not collect key")
	ui._show_pause()
	await ui.overlay.opening_tween.finished
	pause = ui.overlay
	for button: Button in pause.buttons:
		if button.tooltip_text == "Продолжить":
			await click(button.get_global_rect().get_center()); break
	check(not ui.paused,"resume button still works")
	quest._enter("transport_choice")
	await process_frame
	var dialog: Control = ui.screen.find_child("*",true,false)
	for child: Node in ui.screen.get_children():
		if child.get_script() == load("res://scripts/ui/shared/player_dialog.gd"): dialog = child
	check(is_equal_approx(dialog.dimmer.color.a,0.9),"decision shade matches item shade")
	quest._enter("transport")
	await process_frame
	ui._show_player_dialog({"text":"Choice","dismissable":true},[],Callable(),func(): ui._show_story())
	await touch(point)
	check(quest.current_id == "transport" and not quest.flags.TakenKey,"dismissable dialog consumes its complete touch gesture")
	# Reproduce the right-hand justified paragraph from the screenshot.
	var label := SHADER_TEXT.new()
	root.add_child(label)
	label.add_theme_font_override("font",load("res://fonts/oswald/Oswald-Medium.ttf"))
	label.add_theme_font_size_override("font_size",48)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
	label.justification_flags = TextServer.JUSTIFICATION_WORD_BOUND | TextServer.JUSTIFICATION_SKIP_LAST_LINE
	label.text = "Следует ли Джеку сегодня идти до работы пешком или лучше доехать на машине?"
	for width: float in [560,420,720]:
		label.size = Vector2(width,470)
		label.sync_shadow()
		await process_frame
		check(label.shadow_pass.size.is_equal_approx(label.size),"shadow has foreground width after layout")
		check(label.shadow_pass.get_line_count() == label.get_line_count(),"shadow uses identical line wrapping")
		check(label.shadow_pass.position == Vector2.ONE,"shadow offset is one stage pixel")
		check(label.shadow_pass.get_theme_font_size("font_size") == label.get_theme_font_size("font_size"),"shadow font matches")
	label.text = "A translated paragraph that wraps to the same lines in both text passes."
	label.add_theme_font_size_override("font_size",36)
	label.sync_shadow()
	await process_frame
	check(label.shadow_pass.size.is_equal_approx(label.size) and label.shadow_pass.get_line_count() == label.get_line_count(),"translated shadow remains aligned")
	label.free(); ui.free()
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("Modal/shadow regression: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
