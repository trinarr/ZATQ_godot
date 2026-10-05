extends Control

const FONTS := preload("res://scripts/ui/ui_fonts.gd")
var screen: Control
var music := AudioStreamPlayer.new()
var effects := AudioStreamPlayer.new()
var television := Timer.new()
var playing: bool = false
var previous_node: String = ""
var notification: Label
var transition_sound: String = ""

func _ready() -> void:
	add_child(music)
	add_child(effects)
	music.volume_db = -16
	effects.volume_db = -5
	music.stream = load("res://assets/audio/MainTheme.mp3")
	music.finished.connect(func():
		if not playing and Quest.sound_enabled: music.play())
	television.wait_time = 3.0
	television.one_shot = true
	television.timeout.connect(func():
		if playing: Quest.next_channel())
	add_child(television)
	Quest.changed.connect(_show_story)
	Quest.save_failed.connect(_notify)
	_show_menu()
	if not Quest.recovery_message.is_empty(): _notify(Quest.recovery_message)

func _exit_tree() -> void:
	music.stop()
	effects.stop()
	music.stream = null
	effects.stream = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		Quest.save_game()
		if playing: _show_menu()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if playing: _show_menu()
		elif Quest.has_progress: _resume()
		get_viewport().set_input_as_handled()

func _reset_screen(image_name: String, dim: float = 0.0) -> void:
	television.stop()
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var background := TextureRect.new()
	background.texture = load("res://assets/images/" + image_name)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(background)
	if dim > 0:
		var shade := ColorRect.new()
		shade.color = Color(0.015, 0.025, 0.03, dim)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen.add_child(shade)

func _label(text: String, rect: Rect2, size_px: int = 30) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", FONTS.regular_font())
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", Color("e5ebe7"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(label)
	return label

func _box(rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.04, 0.94)
	style.border_color = Color("4b6c63")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	screen.add_child(panel)
	return panel

func _button(text: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override("font", FONTS.regular_font())
	button.add_theme_font_size_override("font_size", 27)
	button.add_theme_color_override("font_color", Color("f2f0e6"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("314f45") if primary else Color("182b28")
		if state == "hover": style.bg_color = style.bg_color.lightened(0.15)
		if state == "pressed": style.bg_color = style.bg_color.darkened(0.2)
		if state == "disabled": style.bg_color = Color("17201f")
		style.border_color = Color("7c9b80") if primary else Color("48625a")
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	screen.add_child(button)
	return button

func _show_menu() -> void:
	playing = false
	effects.stop()
	_reset_screen("Fon1_1.png", 0.73)
	_label("ZOMBIE\nAPOCALYPSE", Rect2(95, 110, 1100, 220), 94)
	var subtitle := _label("THE QUEST", Rect2(100, 345, 800, 75), 42)
	subtitle.add_theme_color_override("font_color", Color("95b8a2"))
	_label("Джек. Нью-Йорк. Утро, которое изменит всё.", Rect2(100, 450, 1000, 70), 29)
	_button("Продолжить", Rect2(100, 565, 450, 75), _resume, true).disabled = not Quest.has_progress
	_button("Новая игра", Rect2(100, 660, 450, 75), _request_new)
	_button("Звук: " + ("включён" if Quest.sound_enabled else "выключен"), Rect2(100, 755, 450, 75), _toggle_sound)
	_label("Перенос на Godot · 0.1\nНачало первого эпизода", Rect2(1080, 795, 440, 90), 24)
	previous_node = ""
	if Quest.sound_enabled and not music.playing: music.play()

func _request_new() -> void:
	if not Quest.has_progress:
		_start()
		return
	_reset_screen("Fon1_1.png", 0.85)
	_box(Rect2(350, 250, 900, 450))
	_label("Начать заново?", Rect2(400, 295, 800, 80), 44)
	_label("Текущее прохождение будет заменено.", Rect2(400, 400, 800, 100), 30)
	_button("Начать", Rect2(400, 570, 360, 75), _start, true)
	_button("Отмена", Rect2(840, 570, 360, 75), _show_menu)

func _start() -> void:
	playing = true
	music.stop()
	previous_node = ""
	Quest.new_game()

func _resume() -> void:
	if not Quest.has_progress: return
	playing = true
	music.stop()
	previous_node = ""
	_show_story()

func _toggle_sound() -> void:
	Quest.set_sound(not Quest.sound_enabled)
	if not Quest.sound_enabled:
		music.stop()
		effects.stop()
	_show_menu()

func _show_story() -> void:
	if not playing: return
	var node: Dictionary = Quest.current()
	var kind: String = node.get("kind", "story")
	var image_name: String = node.get("image", "Fon1_1.png")
	if kind == "tv": image_name = Quest.TV_IMAGES[Quest.channel]
	_reset_screen(image_name)
	if previous_node != Quest.current_id:
		effects.stop()
		_play_sound(transition_sound if not transition_sound.is_empty() else node.get("sound", ""))
		transition_sound = ""
	previous_node = Quest.current_id
	_box(Rect2(35, 25, 480, 60))
	_label("ЭПИЗОД 1 / ДЖЕК", Rect2(55, 37, 420, 40), 25)
	_button("Пауза", Rect2(1350, 25, 215, 60), _show_menu)
	if Quest.flags.TakenKey:
		_box(Rect2(35, 100, 330, 54))
		_label("Ключи от Subaru R1e", Rect2(50, 110, 305, 40), 22)
	_box(Rect2(35, 650, 1055, 275))
	var text: String = node.get("text", "")
	if kind == "tv": text = "CH %d" % (Quest.channel + 1)
	if kind == "item": text = "Получен предмет\n\n" + text
	_label(text, Rect2(65, 680, 995, 215), 33)
	var choices: Array = Quest.available_choices()
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var index: int = i
		_button(choice.text, Rect2(1120, 665 + i * 120, 445, 100), func():
			transition_sound = choice.get("sound", "")
			Quest.choose(index), i == 0)
	if kind == "boundary":
		_button("Главное меню", Rect2(1120, 680, 445, 100), _show_menu, true)
		_label("Продолжение ещё не перенесено", Rect2(1120, 800, 445, 85), 24)
	if kind == "tv": television.start()

func _play_sound(sound_name: String) -> void:
	if not Quest.sound_enabled or sound_name.is_empty(): return
	var path: String = "res://assets/audio/" + sound_name + ".mp3"
	if ResourceLoader.exists(path):
		effects.stream = load(path)
		effects.play()

func _notify(message: String) -> void:
	if is_instance_valid(notification): notification.queue_free()
	notification = Label.new()
	notification.text = message
	notification.position = Vector2(40, 570)
	notification.add_theme_font_size_override("font_size", 27)
	notification.add_theme_color_override("font_color", Color("ffd893"))
	add_child(notification)
