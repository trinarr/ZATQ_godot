extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(scene: Control, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/"+file_name+".png")
func run() -> void:
	var scene: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	var quest: Node = root.get_node("Quest")
	quest.save_path="user://ui_capture.tmp.json"
	quest.tmp_path="user://ui_capture.write.tmp"
	quest.backup_path="user://ui_capture.backup.json"
	await capture(scene,"menu")
	scene._show_selector("tests")
	await capture(scene,"tests")
	scene._show_selector("episodes")
	await capture(scene,"episodes")
	scene._start()
	quest._enter("morning_choice")
	await capture(scene,"story")
	quest._enter("keys")
	await capture(scene,"keys")
	quest._enter("transport_choice")
	await capture(scene,"decision")
	quest._enter("tv")
	await capture(scene,"tv")
	scene._show_pause()
	await capture(scene,"pause")
	scene.queue_free()
	await create_timer(0.25).timeout
	for path in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit()
