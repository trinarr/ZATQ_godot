extends Control

const LAYOUT := preload("res://scripts/ui/landscape_stage_layout.gd")
const TITLE_FONT: Font = preload("res://fonts/flash/font_1.ttf")
const BODY_FONT: Font = preload("res://fonts/flash/font_2.ttf")
const TV_FONT: Font = preload("res://fonts/flash/font_2836.ttf")
var screen: Control
var overlay: Control
var music := AudioStreamPlayer.new()
var effects := AudioStreamPlayer.new()
var television := Timer.new()
var playing: bool = false
var paused: bool = false
var previous_node: String = ""
var transition_sound: String = ""
var notification: Label
var section: String = "menu"
var selector_kind: String = "episodes"
var selector_index: int = 0
var selectors: Array = []

func _ready() -> void:
	selectors = JSON.parse_string(FileAccess.get_file_as_string("res://data/selectors.json"))
	add_child(music)
	add_child(effects)
	music.volume_db = -16
	effects.volume_db = -5
	music.stream = load("res://assets/audio/MainTheme.mp3")
	music.finished.connect(func():
		if is_inside_tree() and not playing and Quest.sound_enabled: music.play())
	television.wait_time = 3.0
	television.one_shot = true
	television.timeout.connect(func():
		if playing and not paused: Quest.next_channel())
	add_child(television)
	Quest.changed.connect(_show_story)
	Quest.save_failed.connect(_notify)
	get_viewport().size_changed.connect(_fit_stage)
	_show_menu()
	if not Quest.recovery_message.is_empty(): _notify(Quest.recovery_message)

func _exit_tree() -> void:
	music.stop()
	effects.stop()
	music.stream = null
	effects.stream = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		Quest.save_game()
		if playing and not paused: _show_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		Quest.save_game()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(overlay): _close_overlay()
		elif paused: _resume()
		elif playing: _show_pause()
		elif section != "menu": _show_menu()
		get_viewport().set_input_as_handled()
	elif section == "selector" and event.is_action_pressed("ui_left"):
		_cycle_selector(-1)
	elif section == "selector" and event.is_action_pressed("ui_right"):
		_cycle_selector(1)

func _fit_stage() -> void:
	if not is_instance_valid(screen): return
	var viewport_size: Vector2 = get_viewport_rect().size
	var fit: float = LAYOUT.fit_scale(viewport_size)
	screen.scale = Vector2.ONE * fit
	screen.position = LAYOUT.centered_offset(viewport_size)

func _reset_screen() -> void:
	television.stop()
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	overlay = null
	screen = Control.new()
	screen.size = LAYOUT.BASE_SIZE
	add_child(screen)
	_fit_stage()

func _art(filename: String, parent: Control = null, rect: Rect2 = Rect2(0,0,800,480)) -> TextureRect:
	rect = LAYOUT.scaled_rect(rect)
	var image := TextureRect.new()
	image.texture = load("res://assets/flash_ui/" + filename + ".png")
	image.position = rect.position
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else screen).add_child(image)
	image.set_deferred("size",rect.size)
	return image

func _image(filename: String) -> void:
	var image := TextureRect.new()
	image.texture = load("res://assets/images/" + filename)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.size = LAYOUT.BASE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(image)
	image.set_deferred("size",LAYOUT.BASE_SIZE)

func _text(text: String, rect: Rect2, font_size: int = 24, title: bool = false, center: bool = false, parent: Control = null) -> Label:
	rect = LAYOUT.scaled_rect(rect)
	font_size = LAYOUT.scaled_font_size(font_size)
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.add_theme_font_override("font", TITLE_FONT if title else BODY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e1e1e1"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else screen).add_child(label)
	label.set_deferred("size",rect.size)
	return label

func _hit(name: String, rect: Rect2, action: Callable, parent: Control = null) -> Button:
	rect = LAYOUT.scaled_rect(rect)
	var button := Button.new()
	button.name = name
	button.position = rect.position
	button.size = rect.size
	button.flat = true
	button.tooltip_text = name
	var empty := StyleBoxEmpty.new()
	for style in ["normal","hover","pressed","focus","disabled"]:
		button.add_theme_stylebox_override(style,empty)
	button.pressed.connect(action)
	(parent if parent != null else screen).add_child(button)
	return button

func _shade(parent: Control, alpha: float = 0.65) -> void:
	var shade := ColorRect.new()
	shade.size = LAYOUT.BASE_SIZE
	shade.color = Color(0,0,0,alpha)
	parent.add_child(shade)

func _show_menu() -> void:
	playing = false
	paused = false
	section = "menu"
	effects.stop()
	_reset_screen()
	_art("menu" if Quest.sound_enabled else "menu_off")
	_hit("Эпизоды",Rect2(154,51,190,43),func(): _show_selector("episodes"))
	_hit("Тесты",Rect2(154,110,190,43),func(): _show_selector("tests"))
	_hit("Справка",Rect2(154,168,190,43),_show_help)
	_hit("Выход",Rect2(154,226,190,43),func(): Quest.save_game(); get_tree().quit())
	_hit("Звук",Rect2(451,198,39,36),_toggle_sound)
	_hit("Достижения",Rect2(519,196,45,42),func(): _message("Достижения", "Сервис достижений ещё не подключён."))
	if Quest.has_progress:
		_brush_button("Продолжить",Rect2(155,286,190,44),_resume)
	previous_node = ""
	if Quest.sound_enabled and not music.playing: music.play()

func _brush_button(text: String, rect: Rect2, action: Callable, parent: Control = null) -> void:
	_art("brush",parent,rect)
	_text(text,Rect2(rect.position+Vector2(0,11),rect.size-Vector2(0,9)),20,true,true,parent)
	_hit(text,rect,action,parent)

func _selector_items() -> Array:
	return selectors.filter(func(item: Dictionary): return item.kind == selector_kind)

func _show_selector(kind: String) -> void:
	playing = false
	paused = false
	section = "selector"
	selector_kind = kind
	selector_index = 0
	_draw_selector()

func _cycle_selector(direction: int) -> void:
	selector_index = wrapi(selector_index+direction,0,_selector_items().size())
	_draw_selector()

func _draw_selector() -> void:
	_reset_screen()
	var entry: Dictionary = _selector_items()[selector_index]
	_art("selector_%d" % int(entry.frame))
	_text(entry.title,Rect2(56,77,703,35),24,true,true)
	var body_size: int = 21
	while body_size > 13 and BODY_FONT.get_multiline_string_size(entry.description,HORIZONTAL_ALIGNMENT_LEFT,233,body_size).y > 99:
		body_size -= 1
	_text(entry.description,Rect2(435,204,233,100),body_size)
	if selector_kind == "tests":
		_text("Последний результат: отсутствует",Rect2(435,162,239,34),16)
		_text("Количество вопросов: " + entry.questions,Rect2(132,280,282,31),19,false,true)
	else:
		_text(": 0",Rect2(500,160,57,28),21)
		_text(": 0",Rect2(585,160,57,28),21)
	_hit("Предыдущий",Rect2(99,69,57,43),func(): _cycle_selector(-1))
	_hit("Следующий",Rect2(648,69,62,43),func(): _cycle_selector(1))
	_hit("Начать",Rect2(310,351,205,48),_selector_start)
	_hit("Закрыть",Rect2(635,348,49,49),_show_menu)

func _selector_start() -> void:
	var entry: Dictionary = _selector_items()[selector_index]
	if entry.available:
		_request_new()
	else:
		_message(entry.title,"Интерфейс восстановлен. Игровая часть этого раздела ещё не перенесена.")

func _show_help() -> void:
	section = "help"
	_reset_screen()
	_art("help")
	_hit("Закрыть справку",Rect2(652,374,57,60),_show_menu)
	_hit("Назад",Rect2(63,373,322,66),_show_menu)

func _request_new() -> void:
	if not Quest.has_progress:
		_start()
		return
	_message("Начать заново?", "Текущее прохождение будет заменено.", _start)

func _start() -> void:
	playing = true
	paused = false
	section = "story"
	music.stop()
	previous_node = ""
	Quest.new_game()

func _resume() -> void:
	if not Quest.has_progress: return
	playing = true
	paused = false
	section = "story"
	music.stop()
	previous_node = ""
	_show_story()

func _toggle_sound() -> void:
	Quest.set_sound(not Quest.sound_enabled)
	if not Quest.sound_enabled:
		music.stop()
		effects.stop()
	if paused: _show_pause()
	else: _show_menu()

func _show_pause() -> void:
	paused = true
	television.stop()
	effects.stop()
	_close_overlay()
	overlay = Control.new()
	overlay.size = LAYOUT.BASE_SIZE
	screen.add_child(overlay)
	_shade(overlay,0.6)
	_art("pause",overlay)
	_text("Звук: " + ("Вкл" if Quest.sound_enabled else "Выкл"),Rect2(101,179,243,28),22,true,true,overlay)
	_hit("Продолжить",Rect2(0,175,72,100),_resume,overlay)
	_hit("Начать заново",Rect2(15,94,290,64),_request_new,overlay)
	_hit("Звук",Rect2(73,158,280,62),_toggle_sound,overlay)
	_hit("Выйти в меню",Rect2(72,225,280,62),_show_menu,overlay)
	_hit("Выйти из игры",Rect2(20,290,290,62),func(): Quest.save_game();get_tree().quit(),overlay)

func _close_overlay() -> void:
	if is_instance_valid(overlay):
		screen.remove_child(overlay)
		overlay.queue_free()
	overlay = null

func _message(title: String, text: String, confirm: Callable = Callable(), confirm_label: String = "Начать", show_cancel: bool = true) -> void:
	television.stop()
	_close_overlay()
	overlay = Control.new()
	overlay.size = LAYOUT.BASE_SIZE
	screen.add_child(overlay)
	_shade(overlay,0.75)
	_art("decision",overlay)
	_text(title + "\n\n" + text,Rect2(430,72,280,235),22,false,false,overlay)
	_brush_button(confirm_label if confirm.is_valid() else "Понятно",Rect2(65,65,335,50),func():
		_close_overlay()
		if confirm.is_valid(): confirm.call()
		elif paused: _show_pause()
		elif playing: _show_story(),overlay)
	if confirm.is_valid() and show_cancel:
		_brush_button("Отмена",Rect2(65,130,335,50),func():
			_close_overlay()
			if paused: _show_pause(),overlay)

func _choose(index: int) -> void:
	var choice: Dictionary = Quest.available_choices()[index]
	transition_sound = choice.get("sound", "")
	Quest.choose(index)

func _show_story() -> void:
	if not playing or paused: return
	section = "story"
	var node: Dictionary = Quest.current()
	var kind: String = node.get("kind", "story")
	_reset_screen()
	_image(node.get("image","Fon1_1.png"))
	if previous_node != Quest.current_id:
		effects.stop()
		_play_sound(transition_sound if not transition_sound.is_empty() else node.get("sound", ""))
		transition_sound = ""
	previous_node = Quest.current_id
	if kind == "tv":
		_art("tv_%d" % Quest.channel)
		var channel_label := _text("CH %d" % (Quest.channel+1),Rect2(218,290,110,30),20)
		channel_label.add_theme_font_override("font",TV_FONT)
		channel_label.add_theme_color_override("font_color",Color.GREEN)
		_hit("Следующий канал",Rect2(200,44,447,262),func(): _choose(0))
		_hit("Выключить телевизор",Rect2(380,382,44,40),func(): _choose(1))
		television.start()
	elif kind == "item":
		var dim := ColorRect.new()
		dim.size=LAYOUT.BASE_SIZE
		dim.color=Color(0,0,0,0.65)
		screen.add_child(dim)
		_art("item_keys")
		_text(node.text,Rect2(102,71,594,31),24,false,true)
		_hit("Забрать ключи",Rect2(656,326,65,58),func(): _choose(0))
	elif Quest.current_id == "transport_choice":
		_art("story_transport")
		_shade(screen,0.6)
		_art("decision")
		_text(node.text,Rect2(430,72,280,235),24)
		for i in 2:
			var index: int = i
			_text(Quest.available_choices()[i].text,Rect2(66,66+i*65,337,50),24,false,true)
			_hit(Quest.available_choices()[i].text,Rect2(60,54+i*65,349,64),func(): _choose(index))
	elif kind == "boundary":
		_art("pause_button")
		_message("Продолжение",node.text,_show_menu,"В меню",false)
	else:
		_art("story_" + Quest.current_id)
		match Quest.current_id:
			"morning_choice":
				_hit("Выйти на улицу",Rect2(273,200,118,85),func(): _choose(0))
				_hit("Смотреть последние новости",Rect2(470,24,220,134),func(): _choose(1))
			"transport":
				_hit("Выйти на улицу",Rect2(20,18,92,99),func(): _choose(0))
				if not Quest.flags.TakenKey:
					_hit("Взять ключи",Rect2(325,217,77,80),func(): _choose(1))
				else:
					# The original pickup button is hidden after collecting the keys.
					_art("story_transport_no_keys")
			"lift_button": _hit("Первый этаж",Rect2(200,140,450,280),func(): _choose(0))
			_: _hit("Далее",Rect2(70,0,730,480),func(): _choose(0))
	# Flash pause control lives at the left edge, not in a new top bar.
	if kind != "item" and Quest.current_id != "transport_choice":
		_hit("Пауза",Rect2(0,5,60,123),_show_pause)

func _play_sound(sound_name: String) -> void:
	if not Quest.sound_enabled or sound_name.is_empty(): return
	var path: String = "res://assets/audio/" + sound_name + ".mp3"
	if ResourceLoader.exists(path):
		effects.stream = load(path)
		effects.play()

func _notify(message: String) -> void:
	if is_instance_valid(notification): notification.queue_free()
	notification = _text(message,Rect2(65,420,680,45),20)
	notification.add_theme_color_override("font_color",Color("ffd893"))
