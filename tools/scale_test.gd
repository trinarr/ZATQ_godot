extends SceneTree
const LAYOUT := preload("res://scripts/ui/landscape_stage_layout.gd")
var failures: int = 0
var checks: int = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(LAYOUT.BASE_SIZE == LAYOUT.FLASH_SIZE * 2.0,"exact 2x base")
	check(LAYOUT.scaled_rect(Rect2(154,110,190,43)) == Rect2(308,220,380,86),"uniform positions and sizes")
	check(LAYOUT.scaled_font_size(24) == 48,"native font size doubles")
	for viewport in [Vector2(1600,960),Vector2(1920,1080),Vector2(2400,1080),Vector2(2560,1600),Vector2(800,480)]:
		var fit: float = LAYOUT.fit_scale(viewport)
		var offset: Vector2 = LAYOUT.centered_offset(viewport)
		var fitted: Vector2 = LAYOUT.BASE_SIZE * fit
		check(offset.x >= 0 and offset.y >= 0,"nonnegative centered margin")
		check(fitted.x <= viewport.x + 0.01 and fitted.y <= viewport.y + 0.01,"stage stays inside viewport")
		check(is_equal_approx(fitted.x/fitted.y,1600.0/960.0),"aspect stays uniform")
		check((offset * 2.0 + fitted).is_equal_approx(viewport),"centering")
	var quest: Node = root.get_node("Quest")
	quest.sound_enabled=false
	var scene: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.screen.size == Vector2(1600,960),"native stage size")
	var button: Button = scene.screen.get_node("Тесты")
	check(button.position==Vector2(308,220) and button.size==Vector2(380,86),"native hitbox is 2x")
	scene._show_selector("tests")
	await process_frame
	for node in scene.screen.get_children():
		if node is TextureRect: check(node.size==Vector2(1600,960),"native texture size")
		if node is Label:
			check(node.get_theme_font_size("font_size")>=32,"text rasterizes at high base resolution")
			check(node.position.x+node.size.x<=1600.1,"native text fits")
	scene.queue_free()
	await create_timer(0.25).timeout
	if failures==0:print("PASS: %d uniform scaling checks" % checks)
	quit(0 if failures==0 else 1)
