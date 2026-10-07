extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func click(point: Vector2) -> void:
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.global_position=point; event.pressed=down
		root.push_input(event,true)
		await process_frame
func run() -> void:
	TranslationServer.set_locale("ru")
	var quest: Node = root.get_node("Quest")
	quest.save_path="user://door_hit_test.json";quest.tmp_path="user://door_hit_test.tmp";quest.backup_path="user://door_hit_test.bak";quest.sound_enabled=false
	var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
	await process_frame
	ui.playing=true;quest.new_game(1)
	for viewport_size: Vector2i in [Vector2i(1600,960),Vector2i(2048,920)]:
		root.size=viewport_size
		ui.viewport_canvas.safe_override=Rect2(108,0,viewport_size.x-108,viewport_size.y)
		await process_frame
		ui._fit_stage()
		for taken: bool in [false,true]:
			for fraction: float in [0.2,0.5,0.8]:
				quest.flags.TakenKey=taken;quest.current_id="transport";ui.playing=true;ui.paused=false;ui._show_story()
				await process_frame
				var door: Button=ui.world_layer.find_child(ui.LOC.text("@loc:ui.main.42"),true,false)
				check(door.size==Vector2(364,698),"door bounds match highlight")
				check(door.hit_image!=null,"door uses shared contour")
				var image: Image=door.hit_image
				var y: int=int(image.get_height()*fraction)
				var point := Vector2(-1,y)
				for x: int in range(image.get_width()-12,12,-1):
					if image.get_pixel(x,y).a>0.9 and image.get_pixel(x-8,y).a>0.9:
						point.x=x-4;break
				check(point.x>=0,"test point inside door silhouette")
				check(door._has_point(point),"top/middle/bottom of door receives input")
				await click(door.get_global_transform()*point)
				check(quest.current_id==("transport_choice" if taken else "lift"),"actual door click advances story")
	ui.free()
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	print("Opening door hit: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
