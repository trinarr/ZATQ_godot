extends Control

const SAFE_CANVAS := preload("res://scripts/ui/adaptive_landscape_canvas.gd")
const ALPHA_HOTSPOT := preload("res://scripts/ui/alpha_hotspot.gd")
const CITY := preload("res://scripts/ui/city_gameplay.gd")
const LAYOUT := preload("res://scripts/ui/landscape_stage_layout.gd")
const TITLE_FONT: Font = preload("res://fonts/flash/font_1.ttf")
const BODY_FONT: Font = preload("res://fonts/flash/font_2.ttf")
const TV_FONT: Font = preload("res://fonts/flash/font_2836.ttf")
var viewport_canvas: Control
var edge_tab: TextureRect
var edge_hit: Button
var screen: Control
var overlay: Control
var music := AudioStreamPlayer.new()
var effects := AudioStreamPlayer.new()
var television := Timer.new()
var cutscene := Timer.new()
var cutscene_tween: Tween
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
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	RenderingServer.set_default_clear_color(Color.BLACK)
	viewport_canvas = SAFE_CANVAS.new()
	add_child(viewport_canvas)
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
	cutscene.one_shot = true
	cutscene.timeout.connect(func():
		if playing and not paused and Quest.current().get("kind", "") == "city_cutscene": Quest.choose(0))
	add_child(cutscene)
	Quest.changed.connect(_show_story)
	Quest.save_failed.connect(_notify)
	get_viewport().size_changed.connect(_fit_stage)
	_show_menu()
	if not Quest.recovery_message.is_empty(): _notify(Quest.recovery_message)

func _exit_tree() -> void:
	_stop_cutscene()
	television.stop()
	music.stop()
	effects.stop()
	music.stream = null
	effects.stream = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		Quest.save_game()
		if playing and not paused: _show_pause()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		call_deferred("_fit_stage")
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
	var safe: Rect2 = viewport_canvas.update_layout(viewport_size)
	var fit: float = LAYOUT.fit_scale(safe.size)
	screen.scale = Vector2.ONE * fit
	screen.position = LAYOUT.centered_offset(safe.size)
	_layout_edge_tab()

func _stop_cutscene() -> void:
	cutscene.stop()
	if cutscene_tween != null and cutscene_tween.is_valid(): cutscene_tween.kill()
	cutscene_tween = null
	if is_instance_valid(screen): screen.modulate = Color.WHITE
	if is_instance_valid(viewport_canvas): viewport_canvas.background.modulate = Color.WHITE

func _reset_screen() -> void:
	television.stop()
	_stop_cutscene()
	if is_instance_valid(screen):
		screen.get_parent().remove_child(screen)
		screen.queue_free()
	overlay = null
	edge_tab = null
	edge_hit = null
	screen = Control.new()
	screen.size = LAYOUT.BASE_SIZE
	viewport_canvas.safe_layer.add_child(screen)
	_set_backdrop(load("res://assets/flash_ui/background.png"))
	_fit_stage()

func _set_backdrop(texture: Texture2D, crop_pause: bool = false) -> void:
	viewport_canvas.set_background(texture, crop_pause)

func _art(filename: String, parent: Control = null, rect: Rect2 = Rect2(0,0,800,480)) -> TextureRect:
	if filename in ["menu", "menu_off", "help"] or filename.begins_with("selector_"):
		filename = "adaptive_" + filename
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
	_set_backdrop(load("res://assets/images/" + filename))

func _layout_edge_tab() -> void:
	if not is_instance_valid(edge_tab) or not is_instance_valid(edge_hit): return
	var safe_size: Vector2 = viewport_canvas.safe_layer.size / screen.scale
	var position := Vector2(-screen.position.x/screen.scale.x,(safe_size.y-edge_tab.size.y)*0.5-screen.position.y/screen.scale.y)
	edge_tab.position = position
	edge_hit.position = position
	edge_hit.size = edge_tab.size

func _edge_tab(label: String, action: Callable, parent: Control = null) -> void:
	if is_instance_valid(edge_tab): edge_tab.hide()
	if is_instance_valid(edge_hit): edge_hit.hide()
	var source: Texture2D = load("res://assets/flash_ui/pause_button.png")
	var image: Image = source.get_image()
	if image.is_compressed(): image.decompress()
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = image.get_used_rect()
	edge_tab = TextureRect.new()
	edge_tab.texture = atlas
	edge_tab.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	edge_tab.size = atlas.region.size
	edge_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else screen).add_child(edge_tab)
	edge_hit = _hit(label,Rect2(Vector2.ZERO,atlas.region.size/2),action,parent)
	_layout_edge_tab()

func _opening_art(name: String) -> void:
	_set_backdrop(load("res://assets/flash_ui/layout_bg_" + name + ".png"))
	_art("layout_controls_tv" if name.begins_with("tv_") else "layout_controls_transport_no_keys" if name == "transport" and Quest.flags.TakenKey else "layout_controls_" + name)

func _opening_caption(node: Dictionary) -> void:
	var y: float = 416 if Quest.current_id in ["wake","screams","transport"] else 445
	if Quest.current_id == "lift_button": y = 5.75
	var band := ColorRect.new()
	band.position = Vector2(-screen.position.x/screen.scale.x,(y-6)*2)
	band.size = Vector2(viewport_canvas.safe_layer.size.x/screen.scale.x,(480-y+6)*2 if y>400 else 80)
	band.color = Color.BLACK
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(band)
	var font_size := 24
	while font_size > 16 and BODY_FONT.get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size*2).x > 1550:
		font_size -= 1
	_text(node.text,Rect2(11,y,775,34),font_size)

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

func _hit(name: String, rect: Rect2, action: Callable, parent: Control = null, mask: String = "") -> Button:
	rect = LAYOUT.scaled_rect(rect)
	var button: Button = Button.new() if mask.is_empty() else ALPHA_HOTSPOT.new()
	if not mask.is_empty():
		button.hit_image = load("res://assets/flash_ui/" + mask + ".png").get_image()
		if button.hit_image.is_compressed(): button.hit_image.decompress()
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
	shade.position = -screen.position / screen.scale
	shade.size = viewport_canvas.safe_layer.size / screen.scale
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
		_text(": %d" % (Quest.episode1_stats.wins if entry.available else 0),Rect2(500,160,57,28),21)
		_text(": %d" % (Quest.episode1_stats.losses if entry.available else 0),Rect2(585,160,57,28),21)
	if selector_kind == "episodes" and entry.available:
		_text("Финалы: %d/3" % Quest.episode1_stats.endings.size(),Rect2(435,313,239,28),18)
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
	_stop_cutscene()
	effects.stop()
	_close_overlay()
	overlay = Control.new()
	overlay.size = LAYOUT.BASE_SIZE
	screen.add_child(overlay)
	_shade(overlay,0.6)
	_art("layout_pause",overlay)
	_text("Звук: " + ("Вкл" if Quest.sound_enabled else "Выкл"),Rect2(101,179,243,28),22,true,true,overlay)
	_edge_tab("Продолжить",_resume,overlay)
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
	_stop_cutscene()
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
	if not kind.begins_with("city_"):
		_image(node.get("image","Fon1_1.png"))
	if previous_node != Quest.current_id:
		effects.stop()
		_play_sound(transition_sound if not transition_sound.is_empty() else node.get("sound", ""))
		transition_sound = ""
	previous_node = Quest.current_id
	if kind.begins_with("city_"):
		CITY.draw(self, node)
	elif kind == "tv":
		_opening_art("tv_%d" % Quest.channel)
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
		_opening_art("transport")
		_shade(screen,0.6)
		_art("decision")
		_text(node.text,Rect2(430,72,280,235),24)
		for i in 2:
			var index: int = i
			_text(Quest.available_choices()[i].text,Rect2(66,66+i*65,337,50),24,false,true)
			_hit(Quest.available_choices()[i].text,Rect2(60,54+i*65,349,64),func(): _choose(index))
	elif kind == "boundary":
		_message("Продолжение",node.text,_show_menu,"В меню",false)
	else:
		_opening_art(Quest.current_id)
		_opening_caption(node)
		match Quest.current_id:
			"morning_choice":
				_hit("Выйти на улицу",Rect2(273,200,118,85),func(): _choose(0))
				_hit("Смотреть последние новости",Rect2(470,24,220,134),func(): _choose(1))
			"transport":
				_hit("Выйти на улицу",Rect2(20,18,92,99),func(): _choose(0))
				if not Quest.flags.TakenKey:
					_hit("Взять ключи",Rect2(325,217,77,80),func(): _choose(1))
			"lift_button": _hit("Первый этаж",Rect2(200,140,450,280),func(): _choose(0))
			_: _hit("Далее",Rect2(70,0,730,480),func(): _choose(0))
	# Flash pause control lives at the left edge, not in a new top bar.
	if not kind.begins_with("city_") and kind != "item" and Quest.current_id != "transport_choice":
		_edge_tab("Пауза",_show_pause)

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
