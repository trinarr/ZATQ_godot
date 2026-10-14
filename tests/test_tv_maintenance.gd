extends SceneTree

# Run after importing resources:
# godot --headless --path . --script tests/test_tv_maintenance.gd
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	TranslationServer.set_locale("ru")
	var host := Control.new()
	host.size = Vector2(1536, 864)
	root.add_child(host)
	var scene := load("res://scenes/ui/TVMaintenance.tscn").instantiate() as Control
	host.add_child(scene)
	await process_frame
	await process_frame
	var title := scene.get_node("MaintenanceTitle") as Label
	var subtitle := scene.get_node("MaintenanceSubtitle") as Label
	assert(title.text == "ТЕХНИЧЕСКИЕ РАБОТЫ")
	assert(subtitle.text == "ВЕЩАНИЕ ВРЕМЕННО ПРИОСТАНОВЛЕНО")
	TranslationServer.set_locale("en")
	await process_frame
	assert(title.text == "TECHNICAL MAINTENANCE")
	assert(subtitle.text == "BROADCAST TEMPORARILY SUSPENDED")
	var extra := Translation.new()
	extra.locale = "de"
	extra.add_message("tv.maintenance.title", "TECHNISCHE WARTUNGSARBEITEN")
	extra.add_message("tv.maintenance.subtitle", "DIE AUSSTRAHLUNG IST VORÜBERGEHEND UNTERBROCHEN")
	TranslationServer.add_translation(extra)
	TranslationServer.set_locale("de")
	await process_frame
	assert(title.text == "TECHNISCHE WARTUNGSARBEITEN")
	for dimensions: Vector2 in [Vector2(640, 360), Vector2(1920, 960), Vector2(640, 960)]:
		host.size = dimensions
		await process_frame
		await process_frame
		var background := scene.get_node("Background") as TextureRect
		assert(is_equal_approx(background.size.x / background.size.y, 16.0 / 9.0))
		assert(background.position.x >= 0.0 and background.position.y >= 0.0)
		for label: Label in [title, subtitle]:
			assert(background.get_rect().encloses(label.get_rect()))
			var font := label.get_theme_font("font")
			var pixels := label.get_theme_font_size("font_size")
			assert(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x <= label.size.x)
			assert(label.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	print("PASS: TV maintenance locale changes, additional language, aspect ratio and text fit")
	host.queue_free()
	quit()
