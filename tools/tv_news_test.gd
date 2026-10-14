extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	TranslationServer.set_locale("ru")
	var host := Control.new()
	host.size = Vector2(1536, 864)
	root.add_child(host)
	var view: Control = load("res://scenes/ui/TVNews.tscn").instantiate()
	host.add_child(view)
	await process_frame
	await process_frame
	check(view.get_node("Developing").text == "РАЗВИТИЕ СОБЫТИЙ", "Russian developing story")
	check(view.get_node("Headline").text == "ЗАПРЕТ ЖЕСТОКИХ ВИДЕОИГР НЕ ПРИНЯТ", "Russian headline")
	check(view.get_node("Subtitle").text == "Защита детей против свободы слова", "Russian subtitle")
	check(view.get_node("Discussion").text == "Примите участие в обсуждении в Twitter", "Russian discussion without hashtag")
	check(view.get_node("TwitterHandle").text == "@TRIN", "fictional Twitter handle")
	for name: String in ["Headline", "Subtitle", "TwitterHandle"]:
		check(view.get_node(name).get_theme_color("font_shadow_color").a > 0.0, "white text has a black shadow")
	TranslationServer.set_locale("en")
	await process_frame
	await process_frame
	check(view.get_node("Developing").text == "DEVELOPING STORY", "English developing story")
	check(view.get_node("Headline").text == "VIOLENT VIDEO GAME LAW STRUCK DOWN", "English headline")
	check(view.get_node("Subtitle").text == "Protecting kids vs. free speech rights", "English subtitle")
	check(view.get_node("Discussion").text == "Join the conversation on Twitter", "English discussion without hashtag")
	for locale: String in ["ru", "en"]:
		TranslationServer.set_locale(locale)
		for extent: Vector2 in [Vector2(1536, 864), Vector2(640, 360), Vector2(1920, 960), Vector2(640, 960)]:
			host.size = extent
			await process_frame
			await process_frame
			var background: TextureRect = view.get_node("Background")
			check(is_equal_approx(background.size.x / background.size.y, 16.0 / 9.0), "background aspect preserved")
			for name: String in view.FIELDS:
				var label: Label = view.get_node(name)
				check(background.get_rect().encloses(label.get_rect()), "translated field stays on broadcast background")
				check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "translated field cannot intercept channel tap")
				var font := label.get_theme_font("font")
				var pixels := label.get_theme_font_size("font_size")
				check(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x <= label.size.x, "translated field fits its allotted width")
	host.free()
	print("News localization: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
