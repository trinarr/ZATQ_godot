extends SceneTree
const HIGHLIGHT := preload("res://scripts/ui/interactive_highlight.gd")
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
	quest.save_path="user://world_alignment_test.json";quest.tmp_path="user://world_alignment_test.tmp";quest.backup_path="user://world_alignment_test.bak"
	quest.sound_enabled=false
	var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
	quest.new_game(1)
	for viewport_size: Vector2i in [Vector2i(2048,920),Vector2i(2400,1080),Vector2i(1280,960),Vector2i(1600,960)]:
		root.size=viewport_size
		await process_frame
		for inset: float in [0.0,108.0]:
			ui.viewport_canvas.safe_override=Rect2(inset,0,viewport_size.x-inset,viewport_size.y)
			for id: String in ["morning_choice","transport","tv","farm_boundary","metro_junction"]:
				quest.flags={"Auto":0,"TakenKey":false,"BulletsNumber":-1,"LinkedFr":false}
				quest.current_id=id;ui.playing=true;ui.paused=false;ui._show_story()
				ui.television.stop()
				await process_frame
				var art_transform: Transform2D=ui.viewport_canvas.art_layer.get_global_transform()
				check(ui.world_layer.get_global_transform().is_equal_approx(art_transform),"world overlay exactly follows backdrop: "+id)
				for child: Node in ui.world_layer.find_children("*","Control",true,false):
					if child.has_meta("interactive_highlight"):
						var point: Vector2=child.global_position+art_transform.basis_xform(Vector2.ONE*HIGHLIGHT.PADDING)
						var local: Vector2=child.position+Vector2.ONE*HIGHLIGHT.PADDING
						# The immediate art container is at authored origin.
						check(point.is_equal_approx(art_transform*local),"glow outline uses backdrop coordinates")
				check(ui.edge_hit!=null,"pause remains available")
				var safe: Rect2=ui.viewport_canvas.safe_layer.get_global_rect()
				check(is_equal_approx(ui.edge_hit.global_position.x,safe.position.x),"pause stays at safe edge")
				# Resize the open scene instead of rebuilding it: offsets cannot drift.
				ui._fit_stage()
				check(ui.world_layer.get_global_transform().is_equal_approx(ui.viewport_canvas.art_layer.get_global_transform()),"resize preserves shared world transform")
				if id=="transport":
					var keys: Button=ui.world_layer.find_child("Взять ключи",true,false)
					check(keys!=null,"keys hit target belongs to world layer")
					if keys!=null:check(keys.global_position.is_equal_approx(art_transform*Vector2(650,434)),"keys hit target maps to same background coordinate")
	ui.viewport_canvas.safe_override=Rect2(108,0,1940,920);root.size=Vector2i(2048,920)
	quest.flags={"Auto":0,"TakenKey":false,"BulletsNumber":-1,"LinkedFr":false}
	quest.current_id="transport";ui.playing=true;ui._show_story()
	await process_frame
	var key_button: Button=ui.world_layer.find_child("Взять ключи",true,false)
	var click := InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=key_button.get_global_rect().get_center();click.global_position=click.position
	Input.parse_input_event(click)
	await process_frame
	var release: InputEventMouseButton=click.duplicate()
	release.pressed=false
	Input.parse_input_event(release)
	await process_frame
	check(quest.flags.TakenKey,"tap at transformed key position activates correct action")
	ui._show_menu()
	check(ui.screen.scale==Vector2.ONE*ui.LAYOUT.fit_scale(ui.viewport_canvas.safe_layer.size),"main menu keeps fitted UI layout")
	ui.queue_free();await process_frame
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	print("PASS: %d world alignment checks; failures %d" % [checks,failures])
	quit(1 if failures else 0)
