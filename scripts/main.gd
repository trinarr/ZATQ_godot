extends "res://scripts/ui/shared/shared_view.gd"

const MENU_LOGO := preload("res://scripts/ui/menu_logo.gd")
const MENU_TIMELINE := preload("res://scripts/ui/menu_timeline.gd")
const PAUSE_MENU := preload("res://scenes/shared/PauseMenu.tscn")
const ITEM_POPUP := preload("res://scenes/shared/ItemPopup.tscn")
const PLAYER_DIALOG := preload("res://scenes/shared/PlayerDialog.tscn")
const ENDING_CHECKS := preload("res://scripts/ui/ending_checks.gd")
const SAFE_CANVAS := preload("res://scripts/ui/adaptive_landscape_canvas.gd")
const ACTIVITY := preload("res://scripts/ui/story_activity.gd")
const CITY := preload("res://scripts/ui/city_gameplay.gd")
const TV_FONT: Font = preload("res://fonts/dseg/DSEG7Classic-Regular.ttf")
var viewport_canvas: Control
var edge_tab: TextureRect
var edge_hit: Button
const NARRATIVE_LAYER := preload("res://scripts/ui/shared/narrative_layer.gd")
var narrative_layer: Control
var pause_storage: Control
var reusable_pause_tab: TextureRect
var reusable_pause_hit: Button
var pause_action: Callable
var texture_prefetch: Node
static var pause_atlas: AtlasTexture
var screen: Control
var world_layer: Control
var menu_logo: Control
var menu_opening: Node
var overlay: Control
var music := AudioStreamPlayer.new()
var effects := AudioStreamPlayer.new()
var television := Timer.new()
var cutscene := Timer.new()
var cutscene_tween: Tween
var playing: bool = false
var paused: bool = false
var previous_node: String = ""
var decision_scene_origin := ""
var decision_dialog: Control
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
	for number: int in Quest.episode_starts:
		var metadata: Dictionary = Quest.episode_metadata.get(number,{})
		var found := false
		for entry: Dictionary in selectors:
			if entry.kind == "episodes" and int(entry.get("episode",0)) == number:
				entry.title = metadata.get("title",entry.title)
				entry.description = metadata.get("description",entry.description)
				entry.episode = number
				entry.available = true
				entry.art = metadata.get("selector_art","")
				found = true
		if not found: selectors.append({"kind":"episodes","title":metadata.get("title",LOC.text("@loc:ui.main.1") + str(number)),"description":metadata.get("description",LOC.text("@loc:ui.main.2")),"frame":2,"questions":"","available":true,"episode":number,"art":metadata.get("selector_art","")})
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
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(screen):
		call_deferred("_refresh_locale")
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		Quest.save_game()
		if playing and not paused: _show_pause()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		call_deferred("_fit_stage")
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		Quest.save_game()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(menu_opening) and menu_opening.playing:
		get_viewport().set_input_as_handled()
		return
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
	_layout_world_layer()
	_layout_edge_tab()
	for child: Node in screen.get_children():
		if child.has_method("set_cover_rect"): child.set_cover_rect(_cover_rect())

func _stop_cutscene() -> void:
	cutscene.stop()
	if cutscene_tween != null and cutscene_tween.is_valid(): cutscene_tween.kill()
	cutscene_tween = null
	if is_instance_valid(screen): screen.modulate = Color.WHITE
	if is_instance_valid(viewport_canvas): viewport_canvas.background.modulate = Color.WHITE

func _reset_screen(preserve_logo: bool = false) -> void:
	decision_scene_origin = ""
	decision_dialog = null
	menu_opening = null
	if is_instance_valid(menu_logo):
		if preserve_logo: menu_logo.reparent(self)
		else:
			menu_logo.free()
			menu_logo = null
	television.stop()
	_stop_cutscene()
	if narrative_layer == null:
		texture_prefetch = preload("res://scripts/ui/texture_prefetch.gd").new()
		add_child(texture_prefetch)
		narrative_layer = NARRATIVE_LAYER.new()
		add_child(narrative_layer)
		pause_storage = Control.new()
		pause_storage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pause_storage.hide()
		add_child(pause_storage)
	narrative_layer.reset()
	for item: Control in [reusable_pause_tab,reusable_pause_hit]:
		if is_instance_valid(item):
			item.reparent(pause_storage,false)
			item.hide()
	overlay = null
	edge_tab = null
	edge_hit = null
	pause_action = Callable()
	if screen == null:
		screen = Control.new()
		screen.size = LAYOUT.BASE_SIZE
		viewport_canvas.safe_layer.add_child(screen)
		world_layer = Control.new()
		world_layer.name = "WorldInteraction"
		world_layer.size = LAYOUT.BASE_SIZE
		world_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(world_layer)
	for host: Control in [world_layer,screen]:
		for child: Node in host.get_children():
			if child == world_layer: continue
			host.remove_child(child)
			child.queue_free()
		if host.has_meta("episode_animation_block"): host.remove_meta("episode_animation_block")
		if host.has_meta("pause_locked"): host.remove_meta("pause_locked")
	_set_backdrop(load("res://assets/flash_ui/background.png"))
	_fit_stage()

func _narrative_text(value: String, rect: Rect2, font_size: int = 24, options: Dictionary = {}) -> Label:
	var host: Control = options.get("host",screen)
	var font: Font = options.get("font",BODY_FONT)
	if font == BODY_FONT: font = NARRATIVE_FONT
	return narrative_layer.show_block(host,value,rect,font,font_size,options)

func _set_backdrop(texture: Texture2D, crop_pause: bool = false) -> void:
	viewport_canvas.set_background(texture, crop_pause)

func _layout_world_layer() -> void:
	if not is_instance_valid(world_layer): return
	# Story artwork retains the full Flash frame; interaction shares its exact
	# transform while captions, pause and modals keep the fitted UI space.
	world_layer.scale = viewport_canvas.art_layer.scale / screen.scale
	world_layer.position = screen.get_global_transform().affine_inverse() * viewport_canvas.art_layer.global_position

func _world_host() -> Control:
	return world_layer if viewport_canvas.component_background_active else screen

func _world_art(filename: String) -> Control:
	return _art(filename,_world_host())

func _world_hit(label: String, rect: Rect2, action: Callable, mask: String = "") -> Button:
	return _hit(label,rect,action,_world_host(),mask)

func _layout_edge_tab() -> void:
	if not is_instance_valid(edge_tab) or not is_instance_valid(edge_hit): return
	var safe_size: Vector2 = viewport_canvas.safe_layer.size / screen.scale
	var position := Vector2(-screen.position.x/screen.scale.x,(safe_size.y-edge_tab.size.y)*0.5-screen.position.y/screen.scale.y)
	edge_tab.position = position
	edge_hit.position = position
	edge_hit.size = edge_tab.size

func _edge_tab(label: String, action: Callable, parent: Control = null) -> void:
	if not _can_pause(): return
	if pause_atlas == null:
		var source: Texture2D = load("res://assets/flash_ui/pause_button.png")
		var image: Image = source.get_image()
		if image.is_compressed(): image.decompress()
		pause_atlas = AtlasTexture.new()
		pause_atlas.atlas = source
		pause_atlas.region = image.get_used_rect()
	if reusable_pause_tab == null:
		reusable_pause_tab = TextureRect.new()
		reusable_pause_tab.texture = pause_atlas
		reusable_pause_tab.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		reusable_pause_tab.size = pause_atlas.region.size
		reusable_pause_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pause_storage.add_child(reusable_pause_tab)
		reusable_pause_hit = _hit(label,Rect2(Vector2.ZERO,pause_atlas.region.size/2),func():
			if pause_action.is_valid(): pause_action.call(),pause_storage)
	pause_action = action
	edge_tab = reusable_pause_tab
	edge_hit = reusable_pause_hit
	var host: Control = parent if parent != null else screen
	for item: Control in [edge_tab,edge_hit]:
		if item.get_parent()!=host: item.reparent(host,false)
		item.show()
	edge_hit.name = LOC.text(label)
	edge_hit.tooltip_text = LOC.text(label)
	_layout_edge_tab()

func _opening_art(name: String) -> Control:
	_component_backdrop("layout_bg_" + name)
	return _world_art("layout_controls_tv" if name.begins_with("tv_") else "layout_controls_transport_no_keys" if name == "transport" and Quest.flags.TakenKey else "layout_controls_" + name)

func _world_highlight_hit(label: String, artwork: String, source: String, action: Callable) -> Button:
	# A hotspot and its glow share one contour and authored bounds.
	for part: Dictionary in episode_components.get(artwork,[]):
		if part.get("type","") == "highlight" and part.get("source","") == source:
			var r: Array = part.rect
			return _world_hit(label,Rect2(r[0],r[1],r[2],r[3]),action,part.region)
	push_error("Missing interactive highlight: "+artwork+" / "+source)
	return null

func _opening_caption(node: Dictionary) -> void:
	var y: float = 416 if Quest.current_id in ["wake","screams","transport"] else 445
	if Quest.current_id == "lift_button": y = 5.75
	var band_rect := Rect2(-screen.position.x/screen.scale.x,(y-6)*2,viewport_canvas.safe_layer.size.x/screen.scale.x,(480-y+6)*2 if y>400 else 80)
	var caption := _narrative_text(node.text,Rect2(11,y,775,34),24,{"fit":"single","minimum":16,"band_rect":band_rect})
	_bind_episode_caption(caption)

func _shade(parent: Control, alpha: float = 0.65) -> void:
	var shade := ColorRect.new()
	shade.position = -screen.position / screen.scale
	shade.size = viewport_canvas.safe_layer.size / screen.scale
	shade.color = Color(0,0,0,alpha)
	parent.add_child(shade)

func _show_menu() -> void:
	var preserve_logo := section in ["menu","help"]
	playing = false
	paused = false
	section = "menu"
	effects.stop()
	_reset_screen(preserve_logo)
	var menu_art := _art("menu" if Quest.sound_enabled else "menu_off")
	_hit(LOC.text("@loc:ui.main.3"),Rect2(154,51,190,43),func(): _show_selector("episodes"))
	_hit(LOC.text("@loc:ui.main.4"),Rect2(154,110,190,43),func(): _show_selector("tests"))
	_hit(LOC.text("@loc:ui.main.5"),Rect2(154,168,190,43),_show_help)
	_hit(LOC.text("@loc:ui.main.7"),Rect2(451,198,39,36),_toggle_sound)
	_hit(LOC.text("@loc:ui.main.8"),Rect2(519,196,45,42),func(): _message(LOC.text("@loc:ui.main.9"), LOC.text("@loc:ui.main.10")))
	if Quest.has_progress:
		_brush_button(LOC.text("@loc:ui.main.11"),Rect2(155,286,190,44),_resume)
	_mount_menu_logo(menu_art,70)
	previous_node = ""
	if Quest.sound_enabled and not music.playing: music.play()

func _mount_menu_logo(art: Control, y: float) -> void:
	# Replace the final-frame preview with the same four reusable texture parts.
	if art != null:
		for child: Node in art.get_children():
			if String(child.get_meta("flash_source"," ")).begins_with("Symbol 132/"):
				child.free()
	if not is_instance_valid(menu_logo):
		menu_logo = MENU_LOGO.new()
		menu_logo.name = "MenuLogo"
		screen.add_child(menu_logo)
	else: menu_logo.reparent(screen)
	menu_logo.position = Vector2(415,y)*2

func _animate_menu_panel(panel: String) -> void:
	menu_opening = MENU_TIMELINE.new()
	screen.add_child(menu_opening)
	menu_opening.configure(screen,panel,menu_logo)

func _brush_button(text: String, rect: Rect2, action: Callable, parent: Control = null) -> void:
	_torn_text_button(text,rect,action,parent)

func _selector_items() -> Array:
	return selectors.filter(func(item: Dictionary): return item.kind == selector_kind)

func _show_selector(kind: String) -> void:
	playing = false
	paused = false
	section = "selector"
	selector_kind = kind
	selector_index = 0
	_draw_selector(true)

func _cycle_selector(direction: int) -> void:
	if is_instance_valid(menu_opening) and menu_opening.playing: return
	selector_index = wrapi(selector_index+direction,0,_selector_items().size())
	_draw_selector()

func _draw_selector(animate: bool = false) -> void:
	_reset_screen()
	var entry: Dictionary = LOC.resolve_tree(_selector_items()[selector_index])
	_art(entry.art if not str(entry.get("art","")).is_empty() else "selector_%d" % int(entry.frame))
	_text(entry.title,Rect2(56,77,703,35),24,true,true)
	var body_size: int = 21
	while body_size > 13 and BODY_FONT.get_multiline_string_size(entry.description,HORIZONTAL_ALIGNMENT_LEFT,233,body_size).y > 99:
		body_size -= 1
	_text(entry.description,Rect2(435,204,233,100),body_size)
	if selector_kind == "tests":
		_text(LOC.text("@loc:ui.main.12"),Rect2(435,162,239,34),16)
		_text(LOC.text("@loc:ui.main.13") + entry.questions,Rect2(132,280,282,31),19,false,true)
	else:
		var stats: Dictionary = Quest.stats_for(entry.get("episode",1))
		_text(": %d" % (stats.wins if entry.available else 0),Rect2(500,160,57,28),21)
		_text(": %d" % (stats.losses if entry.available else 0),Rect2(585,160,57,28),21)
	if selector_kind == "episodes" and entry.available:
		var checks := ENDING_CHECKS.new()
		screen.add_child(checks)
		checks.configure(int(entry.get("episode",1)),Quest.stats_for(entry.get("episode",1)).endings,Quest.nodes)
	_hit(LOC.text("@loc:ui.main.15"),Rect2(99,69,57,43),func(): _cycle_selector(-1))
	_hit(LOC.text("@loc:ui.main.16"),Rect2(648,69,62,43),func(): _cycle_selector(1))
	_hit(LOC.text("@loc:ui.main.17"),Rect2(310,351,205,48),_selector_start)
	_hit(LOC.text("@loc:ui.main.18"),Rect2(635,348,49,49),_show_menu)
	if animate: _animate_menu_panel("selector")

func _selector_start() -> void:
	var entry: Dictionary = LOC.resolve_tree(_selector_items()[selector_index])
	if entry.available:
		_request_new(entry.get("episode",1))
	else:
		_message(entry.title,LOC.text("@loc:ui.main.19"))

func _show_help() -> void:
	section = "help"
	_reset_screen(true)
	_art("help")
	_hit(LOC.text("@loc:ui.main.20"),Rect2(652,374,57,60),_show_menu)
	_mount_menu_logo(null,140)
	_animate_menu_panel("help")

func _request_new(number: int = 0) -> void:
	if number == 0: number = Quest.episode
	if not Quest.has_progress:
		_start_episode(number)
		return
	_message(LOC.text("@loc:ui.main.22"), LOC.text("@loc:ui.main.23"), _start_episode.bind(number))

func _start() -> void:
	_start_episode(Quest.episode)

func _start_episode(number: int) -> void:
	playing = true
	paused = false
	section = "story"
	music.stop()
	previous_node = ""
	Quest.new_game(number)

func _resume() -> void:
	if paused and (is_instance_valid(viewport_canvas.episode_timeline) or is_instance_valid(decision_dialog)):
		paused = false
		_close_overlay()
		if is_instance_valid(viewport_canvas.episode_timeline): viewport_canvas.episode_timeline.suspended = false
		if is_instance_valid(edge_tab): edge_tab.show()
		if is_instance_valid(edge_hit): edge_hit.show()
		if Quest.current().get("kind","") == "tv": television.start()
		return
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
	if paused and is_instance_valid(overlay) and overlay.has_method("set_sound_enabled"):
		overlay.set_sound_enabled(Quest.sound_enabled)
	elif paused: _show_pause()
	else: _show_menu()

func _can_pause() -> bool:
	if not playing or section != "story": return false
	if is_instance_valid(screen) and screen.get_meta("pause_locked",false): return false
	var node: Dictionary = Quest.current()
	if node.get("kind","") in ["city_death","city_ending"]: return false
	if not node.get("pause_allowed",true): return false
	var conditions: Dictionary = node.get("pause_disabled_when",{})
	return conditions.is_empty() or not Quest.matches(conditions)

func _lock_pause() -> void:
	screen.set_meta("pause_locked",true)
	if is_instance_valid(edge_tab): edge_tab.hide()
	if is_instance_valid(edge_hit): edge_hit.hide()

func _show_pause() -> void:
	# Guard every entry point: button, Escape/Back and application deactivation.
	if not _can_pause(): return
	paused = true
	if is_instance_valid(viewport_canvas.episode_timeline): viewport_canvas.episode_timeline.suspended = true
	television.stop()
	_stop_cutscene()
	effects.stop()
	_close_overlay()
	if is_instance_valid(edge_tab): edge_tab.hide()
	if is_instance_valid(edge_hit): edge_hit.hide()
	var panel := PAUSE_MENU.instantiate()
	overlay = panel
	_attach_panel(panel)
	panel.resume_requested.connect(_resume)
	panel.restart_requested.connect(_request_new)
	panel.sound_requested.connect(_toggle_sound)
	panel.menu_requested.connect(_show_menu)
	panel.configure(Quest.sound_enabled)

func _close_overlay() -> void:
	if is_instance_valid(overlay):
		screen.remove_child(overlay)
		overlay.queue_free()
	overlay = null

func _message(title: String, text: String, confirm: Callable = Callable(), confirm_label: String = "@loc:ui.main.32", show_cancel: bool = true) -> void:
	television.stop()
	_stop_cutscene()
	_close_overlay()
	var panel := PLAYER_DIALOG.instantiate()
	overlay = panel
	_attach_panel(panel)
	var choices: Array = [{"text":confirm_label if confirm.is_valid() else "@loc:ui.main.33"}]
	if confirm.is_valid() and show_cancel: choices.append({"text":"@loc:ui.main.34"})
	panel.choice_selected.connect(func(index: int):
		_close_overlay()
		if index == 0 and confirm.is_valid(): confirm.call()
		elif paused: _show_pause()
		elif playing: _show_story())
	panel.configure({"style":"confirmation","text":title+"\n\n"+text,"font_size":22,"shade_alpha":0.75},choices)

func _choose(index: int) -> void:
	if screen.get_meta("episode_animation_block",false): return
	var timeline: Node2D = viewport_canvas.episode_timeline
	var choice: Dictionary = Quest.available_choices()[index]
	if not choice.get("pause_allowed",true): _lock_pause()
	var destination: Dictionary = Quest.current(choice.get("next","")) if choice.has("next") else {}
	# A decision is an overlay over this scene, not a scene exit.
	if destination.get("kind","") == "city_decision" and destination.get("back","") == Quest.current_id:
		_commit_choice(index)
		return
	var next_art: String = destination.get("art","")
	var sequential: bool = is_instance_valid(timeline) and timeline.same_clip(next_art)
	if is_instance_valid(timeline) and timeline.has_outro() and not sequential and not (Quest.current().get("kind","") == "tv" and index == 0):
		var origin := Quest.current_id
		screen.set_meta("episode_animation_block",true)
		television.stop()
		if Quest.current().get("controls_art","") == "ep1_mainstreet_choice_controls":
			for child: Node in world_layer.get_children():
				if child is Control: child.hide()
			for child: Node in screen.get_children():
				if child is Label: child.hide()
		timeline.finished.connect(func():
			if Quest.current_id == origin and playing:
				screen.set_meta("episode_animation_block",false)
				_commit_choice(index),CONNECT_ONE_SHOT)
		timeline.play("outro")
		return
	_commit_choice(index)

func _commit_choice(index: int) -> void:
	var choice: Dictionary = Quest.available_choices()[index]
	transition_sound = choice.get("sound", "")
	Quest.choose(index)

func _show_story() -> void:
	if not playing or paused: return
	var was_story := section == "story"
	var changing_channel := Quest.current_id == "tv" and previous_node == "tv"
	section = "story"
	var node: Dictionary = Quest.current()
	_prefetch_story_resources()
	var kind: String = node.get("kind", "story")
	if not decision_scene_origin.is_empty() and decision_scene_origin == Quest.current_id:
		if is_instance_valid(decision_dialog):
			decision_dialog.get_parent().remove_child(decision_dialog)
			decision_dialog.queue_free()
		decision_dialog = null
		decision_scene_origin = ""
		previous_node = Quest.current_id
		return
	var retain_decision_scene: bool = kind == "city_decision" and was_story and previous_node == node.get("back","") and is_instance_valid(screen)
	var pickup := kind in ["item","city_pickup"]
	var result := kind in ["city_death","city_ending"]
	if pickup or result:
		television.stop()
		_stop_cutscene()
		if not was_story or previous_node.is_empty():
			_reset_screen()
			_restore_modal_backdrop(node)
		_close_overlay()
		if is_instance_valid(edge_tab): edge_tab.hide()
		if is_instance_valid(edge_hit): edge_hit.hide()
		var backdrop: String = node.get("background_art","")
		if not backdrop.is_empty(): _pickup_backdrop(backdrop)
	elif retain_decision_scene:
		decision_scene_origin = previous_node
		var retained: Node2D = viewport_canvas.episode_timeline
		if is_instance_valid(retained): retained.playing = false
	else:
		_reset_screen()
	if previous_node != Quest.current_id:
		effects.stop()
		_play_sound(transition_sound if not transition_sound.is_empty() else node.get("sound", ""))
		transition_sound = ""
	previous_node = Quest.current_id
	if pickup:
		_show_item_popup(node.get("art","item_keys"),node.text)
		return
	if kind.begins_with("activity_"):
		ACTIVITY.draw(self, node)
	elif kind.begins_with("city_"):
		CITY.draw(self, node)
	elif kind == "tv":
		var controls := _opening_art("tv_%d" % Quest.channel)
		var channel_label := _text(LOC.text("@loc:ui.main.channel_format") % (Quest.channel+1),Rect2(218,69.5,110,30),16,false,false,_world_host())
		channel_label.name = "TVChannel"
		channel_label.add_theme_font_override("font",TV_FONT)
		channel_label.add_theme_color_override("font_color",Color.GREEN)
		if is_instance_valid(viewport_canvas.episode_timeline): viewport_canvas.episode_timeline.bind_caption(channel_label,"@tv_channel")
		_world_hit(LOC.text("@loc:ui.main.35"),Rect2(200,44,447,262),func(): _choose(0))
		_world_highlight_hit("@loc:ui.main.36","layout_controls_tv","/Symbol 2819",func(): _choose(1))
		if changing_channel and is_instance_valid(viewport_canvas.episode_timeline):
			viewport_canvas.episode_timeline.seek_frame(viewport_canvas.episode_timeline.frames.size()-1)
			var remote_motion := preload("res://scripts/ui/flash_ui_entrance.gd").new()
			controls.add_child(remote_motion)
			remote_motion.configure_targets([controls.get_child(0)],"remote")
		television.start()
	elif Quest.current_id == "transport_choice":
		_opening_art("transport")
		_show_player_dialog({"text":node.text,"answer_size":24},Quest.available_choices())
	else:
		_opening_art(Quest.current_id)
		_opening_caption(node)
		match Quest.current_id:
			"morning_choice":
				_world_hit(LOC.text("@loc:ui.main.40"),Rect2(273,200,118,85),func(): _choose(0))
				_world_hit(LOC.text("@loc:ui.main.41"),Rect2(470,24,220,134),func(): _choose(1))
			"transport":
				_world_highlight_hit("@loc:ui.main.42","layout_controls_transport","But1/Symbol 2853",func(): _choose(0))
				if not Quest.flags.TakenKey:
					_world_hit(LOC.text("@loc:ui.main.43"),Rect2(325,217,77,80),func(): _choose(1))
			"lift_button": _world_hit(LOC.text("@loc:ui.main.44"),Rect2(200,140,450,280),func(): _choose(0))
			_: _world_hit(LOC.text("@loc:ui.main.45"),Rect2(70,0,730,480),func(): _choose(0))
	# Flash pause control lives at the left edge, not in a new top bar.
	if not kind.begins_with("city_") and not kind.begins_with("activity_") and kind != "item" and Quest.current_id != "transport_choice":
		_edge_tab(LOC.text("@loc:ui.main.46"),_show_pause)

func _prefetch_story_resources() -> void:
	if texture_prefetch == null: return
	var paths: Array[String] = []
	var timeline := preload("res://scripts/ui/episode_timeline.gd")
	for choice: Dictionary in Quest.available_choices().slice(0,2):
		var target: String = choice.get("next","")
		if target.is_empty(): continue
		var next_node: Dictionary = Quest.current(target)
		var art: String = next_node.get("art","")
		if timeline.has_art(art):
			for part: Dictionary in timeline.catalog().art[art].parts.values():
				if part.has("texture"):
					var path: String = "res://assets/flash_ui/" + part.texture
					if path not in paths: paths.append(path)
		elif episode_components.has(art):
			for part: Dictionary in episode_components[art]:
				if part.has("texture"):
					var path: String = "res://assets/flash_ui/" + part.texture
					if path not in paths: paths.append(path)
		elif not art.is_empty(): paths.append("res://assets/flash_ui/"+art+"."+next_node.get("art_extension","png"))
	texture_prefetch.request(paths)

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

func _refresh_locale() -> void:
	if not is_inside_tree(): return
	if playing:
		var was_paused := paused
		paused = false
		_show_story()
		if was_paused: _show_pause()
	elif section == "selector": _draw_selector()
	elif section == "help": _show_help()
	else: _show_menu()

func _component_backdrop(filename: String) -> bool:
	if playing and viewport_canvas.set_episode_background(filename):
		if Quest.current().get("kind","") in ["city_decision","city_pickup","city_death","city_ending","item"]:
			viewport_canvas.episode_timeline.seek_frame(viewport_canvas.episode_timeline.frames.size()-1)
		return true
	if not episode_components.has(filename): return false
	viewport_canvas.set_component_background(episode_components[filename])
	return true

func _default_parent() -> Control:
	return screen

func _cover_rect() -> Rect2:
	return Rect2(-screen.position/screen.scale,viewport_canvas.safe_layer.size/screen.scale)

func _attach_panel(panel: Control) -> void:
	screen.add_child(panel)
	panel.set_cover_rect(_cover_rect())

func _pickup_backdrop(artwork: String) -> void:
	if not _component_backdrop(artwork):
		_set_backdrop(load("res://assets/flash_ui/"+artwork+".png"))
	_layout_world_layer()

func _restore_modal_backdrop(node: Dictionary) -> void:
	# Saved games can resume directly at an item/result popup without a live scene.
	var origin: String = Quest.popup_origin
	if origin.is_empty():
		for id: String in Quest.nodes:
			for choice: Dictionary in Quest.nodes[id].get("choices",[]):
				if choice.get("next","") == Quest.current_id: origin = id; break
			if not origin.is_empty(): break
	var previous: Dictionary = Quest.current(origin) if not origin.is_empty() else {}
	var art: String = previous.get("art","")
	if Quest.flags.Auto == 0: art = previous.get("art_on_foot",art)
	if episode_components.has("layout_bg_"+origin):
		_component_backdrop("layout_bg_"+origin)
	elif not art.is_empty():
		_pickup_backdrop(art)
	_layout_world_layer()

func _show_item_popup(artwork: String, caption: String) -> void:
	var panel := ITEM_POPUP.instantiate()
	overlay = panel
	_attach_panel(panel)
	panel.accepted.connect(func(): _choose(0))
	panel.configure(artwork,caption)
	panel.play_flash_entrance("item")

func _show_player_dialog(data: Dictionary, choices: Array, selected: Callable = Callable(), dismissed: Callable = Callable()) -> void:
	var panel := PLAYER_DIALOG.instantiate()
	_attach_panel(panel)
	panel.choice_selected.connect(selected if selected.is_valid() else _choose)
	if dismissed.is_valid():
		decision_dialog = panel
		panel.dismissed.connect(dismissed)
	panel.configure(data,choices)
	if playing:
		for answer: Button in panel.answer_slots: answer.animate_flash_hover = true
		panel.play_flash_entrance("dialog")

func _dismiss_story_decision(origin: String) -> void:
	var retained := decision_scene_origin == origin
	Quest._enter(origin)
	if not retained:
		var timeline: Node2D = viewport_canvas.episode_timeline
		if is_instance_valid(timeline):
			timeline.playing = false
			timeline.seek_frame(timeline.frames.size()-1)

func _bind_episode_caption(label: Label, decoration: Control = null) -> void:
	if is_instance_valid(viewport_canvas.episode_timeline): viewport_canvas.episode_timeline.bind_caption(label,"",decoration)
