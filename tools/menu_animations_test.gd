extends SceneTree
const LOGO := preload("res://scripts/ui/menu_logo.gd")
const TIMELINE := preload("res://scripts/ui/menu_timeline.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var quest: Node = root.get_node("Quest")
	quest.save_path="user://menu_animations_test.json"
	quest.tmp_path="user://menu_animations_test.tmp"
	quest.backup_path="user://menu_animations_test.bak"
	quest.sound_enabled=false
	var ui: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(ui)
	var logo: Control = ui.menu_logo
	check(logo.parts.size()==4,"four shared logo parts")
	check(logo.position==Vector2(830,140),"menu logo original position")
	for frame: int in 9:
		logo.seek_frame(frame)
		for track: Dictionary in TIMELINE.timelines().logo.tracks:
			check(is_equal_approx(logo.parts[track.source].self_modulate.a,track.alpha[frame]),"authored logo alpha")
	for part: Dictionary in ui.art_components.adaptive_menu:
		if not String(part.source).begins_with("Symbol 132/"): continue
		check(logo.parts[part.source].texture==load("res://assets/flash_ui/"+part.texture),"logo reuses existing texture resource")
	ui._toggle_sound()
	check(ui.menu_logo==logo and logo.frame==8,"sound does not restart logo")
	ui._show_help()
	var motion: Node = ui.menu_opening
	check(ui.menu_logo==logo and logo.position==Vector2(830,280),"help keeps same logo and shifts it down")
	check(motion.frame==1 and motion.playing,"help starts at Flash frame 2")
	var close: Button = ui.screen.get_node("Закрыть справку")
	check(close.mouse_filter==Control.MOUSE_FILTER_IGNORE,"help controls locked during entry")
	var cancel := InputEventAction.new()
	cancel.action="ui_cancel";cancel.pressed=true
	ui._unhandled_key_input(cancel)
	check(ui.section=="help","Back cannot interrupt locked Flash opening")
	for frame: int in range(1,7):
		motion.seek_frame(frame)
		var offset: Array = TIMELINE.timelines().panels.help.offsets[frame]
		for i: int in motion.nodes.size():
			check(motion.nodes[i].position.is_equal_approx(motion.origins[i]+Vector2(offset[0],offset[1])*2),"panel art and hit targets follow same key")
		check(logo.position==Vector2(830,280),"help logo is independent of moving panel")
	check(not motion.playing and close.mouse_filter==Control.MOUSE_FILTER_STOP,"input restored on final key")
	ui._show_menu()
	check(ui.menu_logo==logo and logo.frame==8 and logo.position==Vector2(830,140),"help return preserves completed logo")
	for kind: String in ["episodes","tests"]:
		ui._show_selector(kind)
		check(ui.menu_logo==null,"selector removes menu logo")
		motion=ui.menu_opening
		check(motion.playing and motion.frame==1,"both selectors animate on entry")
		ui._cycle_selector(1)
		check(ui.selector_index==0,"selector ignores switches before opening finishes")
		motion.seek_frame(4)
		ui._cycle_selector(1)
		check(ui.selector_index==1 and ui.menu_opening==null,"cycling updates immediately without replaying opening")
		ui._show_menu()
		check(ui.menu_logo.frame==0,"return from selector replays new logo")
	ui._show_help()
	motion=ui.menu_opening
	motion.seek_frame(6)
	var original: Vector2 = ui.screen.get_node("Закрыть справку").position
	for size: Vector2i in [Vector2i(1600,960),Vector2i(2400,1080),Vector2i(1280,960)]:
		root.size=size
		ui._fit_stage()
		check(ui.screen.get_node("Закрыть справку").position==original,"resize does not accumulate motion offsets")
	ui._show_selector("episodes")
	# Measure visible playback, excluding cold scene/GPU setup.
	if DisplayServer.get_name()=="headless":await process_frame
	else:await RenderingServer.frame_post_draw
	await create_timer(0.3).timeout
	check(not ui.menu_opening.playing and ui.menu_opening.frame==4,"selector finishes through real process clock")
	ui._show_menu()
	if DisplayServer.get_name()=="headless":await process_frame
	else:await RenderingServer.frame_post_draw
	await create_timer(0.6).timeout
	check(ui.menu_logo.finished and ui.menu_logo.frame==8,"logo stops at last frame through real process clock")
	ui.queue_free()
	await process_frame
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("PASS: %d menu animation checks; failures %d" % [checks,failures])
	quit(1 if failures else 0)
