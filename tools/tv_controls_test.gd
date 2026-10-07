extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func click(point: Vector2) -> void:
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;event.global_position=point
		root.push_input(event,true)
		await process_frame
func run() -> void:
	TranslationServer.set_locale("ru")
	var quest: Node=root.get_node("Quest")
	quest.save_path="user://tv_controls_test.json";quest.tmp_path="user://tv_controls_test.tmp";quest.backup_path="user://tv_controls_test.bak";quest.sound_enabled=false
	var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
	await process_frame
	ui.playing=true;quest.new_game(1)
	for extent: Vector2i in [Vector2i(1600,960),Vector2i(2048,920),Vector2i(2400,1080)]:
		root.size=extent
		ui.viewport_canvas.safe_override=Rect2(108,0,extent.x-108,extent.y)
		await process_frame
		ui._fit_stage()
		for channel: int in range(7):
			quest.current_id="tv";quest.channel=channel;ui.playing=true;ui._show_story();ui.television.stop()
			await process_frame
			if is_instance_valid(ui.viewport_canvas.episode_timeline):ui.viewport_canvas.episode_timeline.seek_frame(ui.viewport_canvas.episode_timeline.frames.size()-1)
			var label: Label=ui.world_layer.find_child("TVChannel",true,false)
			check(label.text=="CH %d" % (channel+1),"channel caption updates")
			check(Rect2(408,90,876,502).encloses(label.get_rect()),"caption is inside television screen")
			check(ui.viewport_canvas.safe_layer.get_global_rect().encloses(label.get_global_rect()),"caption stays visible at wide aspect ratios")
			var remote: Button=ui.world_layer.find_child(ui.LOC.text("@loc:ui.main.36"),true,false)
			check(remote.size==Vector2(100,105) and remote.hit_image!=null,"remote shares full highlight contour")
			# This point was below the old 80px-tall input rectangle.
			var point:=Vector2(50,92)
			check(remote._has_point(point),"remote lower portion is clickable")
			await click(remote.get_global_transform()*point)
			var timeline: Node2D=ui.viewport_canvas.episode_timeline
			check(quest.current_id=="tv" and timeline.phase=="outro","remote starts original TV-off frames")
			timeline.seek_frame(timeline.frames.size()-1)
			check(quest.current_id=="morning_choice","remote click switches television off")
	quest.current_id="tv";quest.channel=0;ui.playing=true;ui._show_story();ui.television.stop()
	await process_frame
	await click(ui.world_layer.get_global_transform()*Vector2(850,400))
	check(quest.current_id=="tv" and quest.channel==1,"screen click still advances channel")
	check(ui.world_layer.find_child("TVChannel",true,false).text=="CH 2","channel change updates caption")
	ui.free()
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	print("TV controls: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
