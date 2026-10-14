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
	var view: Control = load("res://scenes/ui/TVVestnik.tscn").instantiate()
	host.add_child(view)
	await process_frame
	await process_frame
	check(view.get_node("Brand").text == "MAX", "Russian channel name")
	check(view.get_node("ChannelSuffix").text == "24", "24 replaces TV suffix")
	check(view.get_node("Time").text == "8:03", "corrected time")
	check(view.get_node("QuoteName").text == "ММВБ", "Russian quote name")
	check(view.get_node("Headline").text == "Губернатор Тамбовской области призвал жителей не поднимать излишней паники", "Tambov replaces Tomsk with other wording preserved")
	check(view.get_node("QuoteValue").text == "1333,49" and view.get_node("QuoteChange").text == "-1,26%", "quote amounts preserved")
	TranslationServer.set_locale("en")
	await process_frame
	await process_frame
	check(view.get_node("Brand").text == "MAX", "English channel name")
	check(view.get_node("QuoteName").text == "MICEX", "live quote name translation")
	check("Tambov" in view.get_node("Headline").text and "Tomsk" not in view.get_node("Headline").text, "live translated headline")
	check(view.get_node("Time").text == "8:03" and view.get_node("ChannelSuffix").text == "24", "time and suffix are locale independent")
	for locale: String in ["ru", "en"]:
		TranslationServer.set_locale(locale)
		for extent: Vector2 in [Vector2(1536, 864), Vector2(640, 360), Vector2(1920, 960), Vector2(640, 960)]:
			host.size = extent
			await process_frame
			await process_frame
			var background: TextureRect = view.get_node("Background")
			check(is_equal_approx(background.size.x / background.size.y, 16.0 / 9.0), "background aspect preserved")
			var blue: ColorRect = view.get_node("BrandPanel")
			var red: ColorRect = view.get_node("SuffixPanel")
			check(background.get_rect().encloses(blue.get_rect()) and background.get_rect().encloses(red.get_rect()), "logo panels remain on broadcast background")
			check(is_equal_approx(blue.size.x / blue.size.y, 132.0 / 55.0), "compact blue panel proportions")
			check(is_equal_approx(blue.position.x + blue.size.x, red.position.x), "logo panels meet without gaps")
			for name: String in view.FIELDS:
				var label: Label = view.get_node(name)
				check(background.get_rect().encloses(label.get_rect()), "translated field stays on broadcast background")
				check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "translated field cannot intercept channel tap")
				var font := label.get_theme_font("font")
				var pixels := label.get_theme_font_size("font_size")
				check(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x <= label.size.x, "translated field fits its allotted width")
	host.free()
	print("Vestnik localization: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
