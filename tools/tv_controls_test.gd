extends SceneTree
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func click(point: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame
func screenshot(name: String) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://" + name + ".png")
func run() -> void:
	TranslationServer.set_locale("ru")
	var quest: Node = root.get_node("Quest")
	quest.save_path = "user://tv_controls_test.json"
	quest.tmp_path = "user://tv_controls_test.tmp"
	quest.backup_path = "user://tv_controls_test.bak"
	quest.sound_enabled = false
	var ui: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(ui)
	ui.playing = true
	quest.new_game(1)
	quest._enter("morning_choice")
	quest.navigate_apartment("tv")
	check(quest.current_id == "morning_choice", "TV blocked while room narrative is visible")
	quest.dismiss_scene_narrative()
	var buttons: Array = ui.world_layer.get_children().filter(func(child): return child is Button)
	buttons[0].pressed.emit()
	check(quest.current_id == "tv" and quest.channel == 0, "living TV contour opens first channel")
	await create_timer(0.65).timeout
	var view: Control = ui.television_view
	check(view.accepting_input and view.room.scale == Vector2(2, 2), "room zoom finishes before taps are enabled")
	check((view.room.transform * view.TV_CENTER).is_equal_approx(Vector2(800, 480)), "TV centered in authored frame")
	check(not view.has_node("Hand"), "no hand or remote overlay")
	check(view.channel_label.text == "CH1", "original channel indicator starts at CH1")
	check(view.channel_label.get_theme_font("font").resource_path.ends_with("JetBrainsMonoNL-Regular.ttf"), "CH uses a font with real uppercase letter shapes")
	check(ui.narrative_layer.active == 1 and ui.narrative_layer.blocks[0].label.text == view.narrative_text(), "first channel has its own standard narrative")
	var seen_narratives: Array[String] = [view.narrative_text()]
	var mute: TextureRect = view.broadcast_viewport.get_node("Mute")
	check(mute.texture.get_size() == Vector2(28, 28) and mute.visible, "original mute bitmap remains visible")
	check(mute.mouse_filter == Control.MOUSE_FILTER_IGNORE and view.channel_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "TV indicators cannot intercept taps")
	for indicator: Control in [mute, view.channel_label]:
		check(Rect2(0, 0, 1536, 864).encloses(indicator.get_rect()), "indicator lies inside broadcast screen")
	check(quest.TV_IMAGES == ["tv/commercial.png", "tv/sport_news.png", "tv/hazmat_vestnik.png", "tv/news_anchor.png", "tv/dorwood_nqc.png", "tv/maintenance_aera.png"], "only five approved images and maintenance are channels")
	await screenshot("tv_first_channel")
	await create_timer(3.2).timeout
	check(quest.channel == 0, "no automatic channel timer")
	await click(view.get_global_transform() * Vector2(800, 900))
	check(quest.channel == 1 and ui.television_view == view, "tap on narrative panel changes channel without resetting zoom")
	check(view.changing_channel and not view.accepting_input, "channel change disables repeated taps during fade")
	check(view.broadcast.modulate.r < 1.0 and view.channel_index == 0, "old broadcast fades before replacement")
	ui._next_tv_channel()
	check(quest.channel == 1, "rapid repeated tap cannot skip a channel")
	ui._show_pause()
	await process_frame
	var faded: Color = view.broadcast.modulate
	await create_timer(0.25).timeout
	check(view.broadcast.modulate.is_equal_approx(faded) and view.channel_index == 0, "pause freezes channel fade")
	ui._resume()
	await create_timer(0.25).timeout
	check(view.accepting_input and view.broadcast.modulate.is_equal_approx(Color.WHITE), "channel fade finishes and restores input")
	check(view.channel_label.text == "CH2", "tap updates channel indicator")
	check(ui.narrative_layer.active == 1 and ui.narrative_layer.blocks[0].label.text == view.narrative_text(), "channel change replaces narrative instead of stacking")
	seen_narratives.append(view.narrative_text())
	ui._show_pause()
	check(view.suspended, "pause suspends TV input and animation")
	var paused_tap := InputEventMouseButton.new()
	paused_tap.button_index = MOUSE_BUTTON_LEFT
	paused_tap.pressed = true
	view._gui_input(paused_tap)
	check(quest.channel == 1, "pause cannot change channel")
	ui._resume()
	check(not view.suspended and ui.television_view == view, "resume retains TV view")
	var restored: Node = load("res://scripts/core/quest_state.gd").new()
	restored.save_path = quest.save_path
	restored.tmp_path = quest.tmp_path
	restored.backup_path = quest.backup_path
	root.add_child(restored)
	check(restored.current_id == "tv" and restored.channel == 1, "save restores TV and channel")
	var legacy: Dictionary = quest._snapshot()
	legacy.erase("tv_channel_set")
	for index: int in range(8):
		legacy.channel = index
		check(restored._valid(legacy) and restored._saved_tv_channel(legacy) == [3, 1, 0, 4, 2, 2, 2, 5][index], "old eight-channel saves migrate correctly")
	var previous: Dictionary = quest._snapshot()
	previous.tv_channel_set = "approved_six"
	for index: int in range(6):
		previous.channel = index
		check(restored._valid(previous) and restored._saved_tv_channel(previous) == [3, 1, 0, 4, 2, 5][index], "six-channel saves preserve the broadcast after reordering")
	restored.save_path = "user://tv_legacy_test.json"
	var legacy_file := FileAccess.open(restored.save_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	restored._load_save()
	check(restored.current_id == "tv" and restored.channel == 5, "old maintenance save resumes on maintenance")
	DirAccess.remove_absolute(restored.save_path)
	var invalid: Dictionary = quest._snapshot()
	invalid.channel = 6
	check(not quest._valid(invalid), "new save rejects out-of-range channel")
	restored.free()
	ui._show_menu()
	ui._resume()
	view = ui.television_view
	check(view.channel_index == 1 and view.camera_progress == 1.0, "continue rebuilds saved close-up")
	check(view.channel_label.text == "CH2", "continue restores channel indicator")
	check(ui.narrative_layer.active == 1 and ui.narrative_layer.blocks[0].label.text == view.narrative_text(), "continue restores saved channel narrative")
	for extent: Vector2i in [Vector2i(1600, 960), Vector2i(2400, 1080), Vector2i(1280, 960)]:
		root.size = extent
		ui.viewport_canvas.safe_override = Rect2(108, 0, extent.x - 108, extent.y)
		await process_frame
		ui._fit_stage()
		check(ui.viewport_canvas.safe_layer.get_global_rect().encloses(view.get_global_rect()), "complete TV frame stays inside safe area")
		await process_frame
		var caption: Label = ui.narrative_layer.blocks[0].label
		check(ui.viewport_canvas.safe_layer.get_global_rect().encloses(caption.get_global_rect()), "narrative stays inside safe area")
	root.size = Vector2i(1600, 960)
	ui.viewport_canvas.safe_override = Rect2()
	ui._fit_stage()
	for index: int in range(2, quest.TV_IMAGES.size()):
		await click(view.get_global_transform() * Vector2(800, 480))
		await create_timer(0.25).timeout
		check(quest.channel == index and view.channel_index == index, "tap advances through ordered channel list")
		check(view.channel_label.text == "CH%d" % (index + 1), "indicator updates on every channel")
		check(ui.narrative_layer.active == 1 and ui.narrative_layer.blocks[0].label.text == view.narrative_text(), "each channel updates the standard narrative")
		check(not view.narrative_text().is_empty() and view.narrative_text() not in seen_narratives, "every channel has a distinct nonempty description")
		seen_narratives.append(view.narrative_text())
		if index == 2:
			check(view.vestnik.visible and not view.picture.visible and not view.maintenance.visible, "Vestnik uses translated broadcast scene")
			await screenshot("tv_vestnik_ru")
			TranslationServer.set_locale("en")
			await process_frame
			check(view.vestnik.get_node("QuoteName").text == "MICEX", "Vestnik changes locale inside television")
			await screenshot("tv_vestnik_en")
			TranslationServer.set_locale("ru")
			await process_frame
		if index == 3:
			check(view.news.visible and not view.picture.visible, "news channel uses localized overlay")
			check(view.news.get_node("Headline").text == "ЗАПРЕТ ЖЕСТОКИХ ВИДЕОИГР НЕ ПРИНЯТ", "news headline uses requested Russian wording")
			await screenshot("tv_news_ru")
			TranslationServer.set_locale("en")
			await process_frame
			check(view.news.get_node("Headline").text == "VIOLENT VIDEO GAME LAW STRUCK DOWN", "news headline changes locale")
			check("#" not in view.news.get_node("Discussion").text, "no real Twitter hashtag")
			await screenshot("tv_news_en")
			TranslationServer.set_locale("ru")
			await process_frame
		if index == 4:
			check(view.dorwood.visible and not view.picture.visible and not view.news.visible, "Dorwood uses localized broadcast scene")
			check(view.dorwood.get_node("Breaking").text == "ЭКСТРЕННЫЙ ВЫПУСК", "Dorwood Russian breaking banner")
			await screenshot("tv_dorwood_ru")
			TranslationServer.set_locale("en")
			await process_frame
			check(view.dorwood.get_node("Location").text == "DORWOOD", "Dorwood language changes while visible")
			await screenshot("tv_dorwood_en")
			TranslationServer.set_locale("ru")
			await process_frame
	check(view.maintenance.visible and not view.picture.visible, "last channel uses localized maintenance scene")
	await screenshot("tv_maintenance_channel")
	TranslationServer.set_locale("en")
	await process_frame
	check(view.maintenance.title_label.text == "TECHNICAL MAINTENANCE", "maintenance locale changes in TV")
	check(view.channel_label.text == "CH6", "channel indicator uses source format when locale translation is empty")
	await click(view.get_global_transform() * Vector2(800, 480))
	check(view.closing and quest.current_id == "tv", "final tap switches off before return")
	check(ui.narrative_layer.active == 0, "power off hides TV narrative")
	ui._show_pause()
	await create_timer(0.3).timeout
	check(quest.current_id == "tv", "power-off transition waits during pause")
	ui._resume()
	await create_timer(0.3).timeout
	check(quest.current_id == "morning_choice" and ui.television_view == null, "power-off returns to living room")
	check(not quest.scene_narrative_pending() and ui.world_layer.get_child_count() == 8, "return immediately restores four contours and hotspots")
	quest.navigate_apartment("tv")
	check(quest.channel == 0, "reopening starts from first channel")
	ui.free()
	await process_frame
	for path: String in [quest.save_path, quest.tmp_path, quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("TV controls: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
