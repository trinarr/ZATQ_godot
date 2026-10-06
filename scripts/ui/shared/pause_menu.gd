extends "res://scripts/ui/shared/modal_view.gd"
signal resume_requested
signal restart_requested
signal sound_requested
signal menu_requested
signal quit_requested
const ACTION_BUTTON := preload("res://scripts/ui/shared/pause_action_button.gd")
const DRUM_X := [-14.0,-5.6,-2.4,0.0,0.0,0.0]
const BUTTONS_X := [-9.0,3.6,10.4,14.55,18.0,16.0]
var resume_art: TextureRect
var resume_hit: Button
var drum: Control
var buttons: Array[Button] = []
var sound_button: Button
var parts: Dictionary
var opening_frame := 5
var opening_tween: Tween

func configure(sound_enabled: bool) -> void:
	if is_instance_valid(drum):
		set_sound_enabled(sound_enabled)
		return
	parts = JSON.parse_string(FileAccess.get_file_as_string("res://data/pause_components.json"))
	add_shade(0.6)
	dimmer.gui_input.connect(_shade_input)
	drum = Control.new()
	drum.name = "Drum"
	drum.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drum)
	COMPONENTS.draw(drum,parts.pause_drum,"background")
	# Flash's central button has its own larger, alpha-shaped hit state.
	var hit: Dictionary = parts.pause_resume_hit[0]
	resume_hit = ALPHA_HOTSPOT.new()
	resume_hit.name = LOC.text("@loc:ui.main.27")
	resume_hit.tooltip_text = LOC.text("@loc:ui.main.27")
	resume_hit.hit_image = load("res://assets/flash_ui/" + hit.texture).get_image()
	if resume_hit.hit_image.is_compressed(): resume_hit.hit_image.decompress()
	resume_hit.size = Vector2(hit.rect[2],hit.rect[3])*2
	resume_hit.flat = true
	for style: String in ["normal","hover","pressed","focus"]:
		resume_hit.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	resume_hit.pressed.connect(func(): resume_requested.emit())
	add_child(resume_hit)
	var center := Control.new()
	center.position = -Vector2(hit.rect[0],hit.rect[1])*2
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resume_hit.add_child(center)
	COMPONENTS.draw(center,parts.pause_resume,"background")
	resume_art = center.get_child(0)
	resume_art.self_modulate.a = 0.5
	COMPONENTS.draw(center,parts.pause_arrow,"background")
	resume_hit.button_down.connect(func(): resume_art.self_modulate.a = 0.69921875)
	resume_hit.button_up.connect(func(): resume_art.self_modulate.a = 0.5)
	_action("restart", "@loc:ui.main.28", "@loc:ui.art.layout_pause.2", Vector2(0,13), func(): restart_requested.emit())
	sound_button = _action("sound", "@loc:ui.main.29", "", Vector2(54,79), func(): sound_requested.emit())
	_action("menu", "@loc:ui.main.30", "@loc:ui.art.layout_pause.1", Vector2(54,144), func(): menu_requested.emit())
	_action("quit", "@loc:ui.main.31", "@loc:ui.art.layout_pause.0", Vector2(10,210), func(): quit_requested.emit())
	set_sound_enabled(sound_enabled)
	# Six authored keyframes at the original 19 fps, including the overshoot.
	_set_opening_frame(0)
	if is_inside_tree(): _play_opening()
	else: ready.connect(_play_opening,CONNECT_ONE_SHOT)

func _play_opening() -> void:
	opening_tween = create_tween()
	for frame: int in range(1,6):
		opening_tween.tween_interval(1.0/19.0)
		opening_tween.tween_callback(_set_opening_frame.bind(frame))

func _action(id: String, title: String, caption: String, offset: Vector2, action: Callable) -> Button:
	var button := ACTION_BUTTON.new()
	button.set_meta("flash_offset",offset)
	add_child(button)
	button.configure(title,caption,parts["pause_"+id+"_shadow"])
	button.pressed.connect(action)
	buttons.append(button)
	return button

func set_sound_enabled(enabled: bool) -> void:
	if is_instance_valid(sound_button):
		sound_button.set_caption(LOC.text("@loc:ui.main.24") + LOC.text("@loc:ui.main.25" if enabled else "@loc:ui.main.26"))

func _shade_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		resume_requested.emit()

func _set_opening_frame(frame: int) -> void:
	opening_frame = frame
	_layout_parts()

func set_cover_rect(rect: Rect2) -> void:
	super.set_cover_rect(rect)
	_layout_parts()

func _layout_parts() -> void:
	if not is_instance_valid(drum): return
	# Keep the central arrow at the opening tab's center, including safe areas.
	var origin := Vector2(cover_rect.position.x,cover_rect.get_center().y-158.45*2)
	drum.position = origin+Vector2(DRUM_X[opening_frame]*2,0)
	var hit: Dictionary = parts.pause_resume_hit[0]
	resume_hit.position = drum.position+Vector2(hit.rect[0],130.95+hit.rect[1])*2
	for button: Button in buttons:
		button.position = origin+(Vector2(BUTTONS_X[opening_frame],14)+Vector2(button.get_meta("flash_offset")))*2
