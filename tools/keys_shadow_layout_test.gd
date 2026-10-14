extends SceneTree
const HIGHLIGHT := preload("res://scripts/ui/interactive_highlight.gd")
const SHADOW := preload("res://shaders/sprite_soft_shadow.gdshader")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var quest: Node = root.get_node("Quest")
	quest.save_path = "user://keys_shadow_layout.json"
	quest.tmp_path = "user://keys_shadow_layout.tmp"
	quest.backup_path = "user://keys_shadow_layout.bak"
	quest.sound_enabled = false
	var ui: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(ui)
	ui.playing = true
	quest.new_game(1)
	quest._enter("transport")
	quest.dismiss_scene_narrative()
	var passes: Array = ui.viewport_canvas.art_layer.get_children().filter(func(child):
		return child is TextureRect and child.texture != null and child.texture.resource_path.ends_with("/hall_keys.png"))
	check(passes.size() == 3, "hallway draws cast shadow, contact shadow and foreground")
	check(passes[-1].material == null, "keys retain their original colors")
	for shadow: TextureRect in passes.slice(0,2):
		check(shadow.material.shader == SHADOW, "hallway shadow is a shader alpha silhouette")
		check(shadow.mouse_filter == Control.MOUSE_FILTER_IGNORE, "shadow cannot consume a pickup tap")
		check(shadow.material.get_shader_parameter("sprite_size").is_equal_approx(shadow.size), "shadow softness follows displayed size")
		check(float(shadow.material.get_shader_parameter("padding_px")) > 2.0 * float(shadow.material.get_shader_parameter("softness_px")), "blur expands beyond sprite bounds")
	var mask := HIGHLIGHT.mask_image("hall_keys")
	check(mask.get_pixel(51,1).a == 0.0, "obsolete upright ring spike removed from hit contour")
	var key: TextureRect = passes[-1]
	var image := key.texture.get_image()
	if image.is_compressed(): image.decompress()
	var anchor := Vector2(418,300) * 2
	var covered := true
	for y: int in range(0,image.get_height(),3):
		for x: int in range(0,image.get_width(),3):
			if image.get_pixel(x,y).a < 0.8: continue
			var point := key.position-anchor + Vector2(x,y)/Vector2(image.get_size())*key.size
			var pixel := Vector2i(point)
			if mask.get_pixel(pixel.x,pixel.y).a < 0.1: covered = false
	check(covered, "updated holder contour includes opaque pixels of the new bundle")
	quest.take_apartment_keys()
	var panel: Control = ui.overlay
	for child: Node in panel.get_children():
		if child.get_script() == load("res://scripts/ui/flash_ui_entrance.gd"):
			child.seek_frame(child.offsets.size()-1)
	passes = panel.get_children().filter(func(child):
		return child is TextureRect and child.texture != null and child.texture.resource_path.ends_with("/keys_front.png"))
	check(passes.size() == 2, "item panel draws shadow before foreground")
	var front: TextureRect = passes[-1]
	check(front.material == null and passes[0].material.shader == SHADOW, "panel tint applies only to the shadow")
	check(front.size.is_equal_approx(Vector2(536,420)*0.85), "front bundle reduced by exactly fifteen percent")
	check(is_equal_approx(front.get_rect().get_center().y,(107.5+424.0)), "front vertically centered between subtitle bottom and panel bottom")
	check(is_equal_approx(front.get_rect().get_center().x,800), "front horizontally centered")
	check(passes[0].position-front.position == Vector2(8,10), "panel shadow offset down and right")
	panel.accepted.emit()
	check(ui.viewport_canvas.art_layer.get_child_count() == 1, "collecting keys removes both contact shadows too")
	ui.free()
	await process_frame
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("Key shadows and layout: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
