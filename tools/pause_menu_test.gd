extends SceneTree
const PAUSE := preload("res://scenes/shared/PauseMenu.tscn")
var checks := 0
var failures := 0
var resumed := false
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var standalone: Control = PAUSE.instantiate()
	standalone.configure(true)
	root.add_child(standalone)
	await standalone.opening_tween.finished
	check(standalone.buttons.size()==4 and standalone.opening_frame==5,"component can be configured before entering the tree")
	standalone.free()
	var pause: Control = PAUSE.instantiate()
	root.add_child(pause)
	pause.configure(false)
	check(pause.opening_frame==0,"opening begins at first authored frame")
	await pause.opening_tween.finished
	check(pause.opening_frame==5,"opening reaches final authored frame")
	check(pause.buttons.size()==4,"four independent action buttons")
	for button: Button in pause.buttons:
		check(button.get_child_count()==3,"each button owns shadow, background and caption")
		check(button.background.material is ShaderMaterial,"each background has independent shader state")
		check(button.caption is Label and button.caption.mouse_filter==Control.MOUSE_FILTER_IGNORE,"native localized caption does not intercept clicks")
	check(pause.buttons[0].background.material!=pause.buttons[1].background.material,"hover cannot recolor adjacent buttons")
	var sound: Button = pause.sound_button
	var off: String = sound.caption.text
	pause.set_sound_enabled(true)
	check(pause.sound_button==sound and sound.caption.text!=off,"sound updates caption without replacing button")
	check(pause.opening_frame==5,"sound does not restart animation")
	pause.configure(false)
	check(pause.buttons.size()==4,"reconfiguration does not duplicate parts")
	for rect: Rect2 in [Rect2(0,0,1600,960),Rect2(-300,-40,2200,1040),Rect2(50,80,1500,800)]:
		pause.set_cover_rect(rect)
		check(pause.drum.position.x==rect.position.x,"drum attaches to safe left edge")
		check(is_equal_approx(pause.resume_art.get_global_rect().get_center().y,rect.get_center().y),"central button replaces opening arrow at same height")
		check(pause.buttons[0].position==pause.drum.position+Vector2(32,54),"button group preserves original Flash offsets on resize")
		check(pause.dimmer.get_rect()==rect,"shade covers entire visible area")
	check(not pause.resume_hit._has_point(Vector2(-1,0)),"central hit region ignores outside points")
	pause.resume_requested.connect(func(): resumed=true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	pause.dimmer.gui_input.emit(event)
	check(resumed,"background click resumes like original Flash")
	pause.free()
	var quest: Node = root.get_node("Quest")
	quest.save_path="user://pause_menu_test.json"
	quest.tmp_path="user://pause_menu_test.tmp"
	quest.backup_path="user://pause_menu_test.bak"
	quest.sound_enabled=false
	var ui: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.playing=true
	quest.new_game(1)
	await process_frame
	ui._show_pause()
	var overlay: Control = ui.overlay
	check(not ui.edge_tab.visible and not ui.edge_hit.visible,"drum replaces hidden opening tab")
	await overlay.opening_tween.finished
	ui._toggle_sound()
	check(ui.overlay==overlay and overlay.opening_frame==5,"sound preserves open menu and animation state")
	ui._resume()
	check(ui.overlay==null and ui.edge_tab.visible and ui.edge_hit.visible,"resume restores opening tab")
	ui.queue_free()
	await process_frame
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("PASS: %d pause component checks; failures %d" % [checks,failures])
	quit(1 if failures else 0)
