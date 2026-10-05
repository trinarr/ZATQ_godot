extends SceneTree
const CANVAS := preload("res://scripts/ui/adaptive_landscape_canvas.gd")
var checks: int = 0
var failures: int = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var viewport := Vector2(2400,1080)
	check(CANVAS.map_safe_rect(viewport,Rect2(0,0,2400,1080),Rect2(80,0,2240,1080))==Rect2(80,0,2240,1080),"left and right camera insets")
	check(CANVAS.map_safe_rect(Vector2(1200,540),Rect2(0,0,2400,1080),Rect2(80,0,2240,1080))==Rect2(40,0,1120,540),"physical to viewport coordinates")
	check(CANVAS.map_safe_rect(viewport,Rect2(80,0,2320,1080),Rect2(80,0,2320,1080))==Rect2(0,0,2400,1080),"OS already excluded inset: no second margin")
	check(CANVAS.map_safe_rect(viewport,Rect2(0,0,2400,1080),Rect2())==Rect2(Vector2.ZERO,viewport),"invalid native result fallback")
	check(CANVAS.map_safe_rect(viewport,Rect2(40,20,2400,1080),Rect2(100,40,2280,1020))==Rect2(60,20,2280,1020),"offset client window and four edges")
	var quest: Node = root.get_node("Quest")
	quest.save_path="user://safe_test.json"
	quest.tmp_path="user://safe_test.tmp"
	quest.backup_path="user://safe_test.bak"
	quest.sound_enabled=false
	var scene: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(root.content_scale_aspect==Window.CONTENT_SCALE_ASPECT_EXPAND,"viewport expands to physical aspect")
	for size: Vector2i in [Vector2i(1600,960),Vector2i(2048,920),Vector2i(2400,1080),Vector2i(2560,1600)]:
		root.size=size
		await process_frame
		var extent: Vector2=scene.get_viewport_rect().size
		scene.viewport_canvas.safe_override=Rect2(Vector2(40,12),extent-Vector2(100,40))
		scene._fit_stage()
		var canvas: Control=scene.viewport_canvas
		check(canvas.black.color==Color.BLACK and canvas.black.size==extent,"black clear covers window")
		check(canvas.safe_layer.clip_contents,"content clips at safe boundary")
		check(canvas.background.size==canvas.safe_layer.size,"background covers whole safe rectangle")
		check(canvas.background.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,"background fills without empty bands")
		check(is_equal_approx(scene.screen.scale.x,scene.screen.scale.y),"uniform UI scale")
		var visible:=Rect2(scene.screen.position,scene.screen.size*scene.screen.scale)
		check(Rect2(Vector2.ZERO,canvas.safe_layer.size).encloses(visible),"all UI is within safe area")
		check(scene.screen.get_parent()==canvas.safe_layer,"stage belongs to safe clip container")
	scene._start()
	quest._enter("city_car")
	check(scene.viewport_canvas.art_layer.get_child_count()>0,"city backdrop uses independent art components")
	scene._show_pause()
	check(scene.overlay.get_parent()==scene.screen,"pause also stays inside safe area")
	scene._show_menu()
	check(scene.viewport_canvas.art_layer.get_child_count()==0,"menu uses clean background without UI")
	scene.queue_free()
	await create_timer(0.25).timeout
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	if failures==0:print("PASS: %d adaptive safe-area checks" % checks)
	await process_frame
	quit(0 if failures==0 else 1)
