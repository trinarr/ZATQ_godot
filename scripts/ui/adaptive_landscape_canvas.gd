extends Control
# Decorative background fills the safe rectangle. Authored story art and UI
# retain the complete Flash frame so edge controls cannot be cropped.
var safe_layer := Control.new()
var background := TextureRect.new()
var art_layer := Control.new()
var component_background_active := false
var episode_timeline: Node2D
const EPISODE_TIMELINE := preload("res://scripts/ui/episode_timeline.gd")
const COMPONENTS := preload("res://scripts/ui/flash_components.gd")
var black := ColorRect.new()
var safe_override: Rect2 = Rect2()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	safe_layer.clip_contents = true
	safe_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe_layer)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_layer.add_child(background)
	art_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(art_layer)

static func map_safe_rect(viewport_size: Vector2, window_rect: Rect2, display_safe: Rect2) -> Rect2:
	var full := Rect2(Vector2.ZERO, viewport_size)
	if window_rect.size.x <= 0.0 or window_rect.size.y <= 0.0 or display_safe.size.x <= 0.0 or display_safe.size.y <= 0.0:
		return full
	var visible: Rect2 = window_rect.intersection(display_safe)
	if not visible.has_area(): return full
	var factor := viewport_size / window_rect.size
	return Rect2((visible.position - window_rect.position) * factor, visible.size * factor)

func update_layout(viewport_size: Vector2) -> Rect2:
	var safe := Rect2(Vector2.ZERO, viewport_size)
	if safe_override.has_area():
		safe = safe.intersection(safe_override)
	elif OS.has_feature("android") or OS.has_feature("ios"):
		var window_position: Vector2 = Vector2(DisplayServer.window_get_position())
		window_position -= Vector2(DisplayServer.screen_get_position(DisplayServer.window_get_current_screen()))
		safe = map_safe_rect(viewport_size,Rect2(window_position,Vector2(DisplayServer.window_get_size())),Rect2(DisplayServer.get_display_safe_area()))
	size = viewport_size
	black.size = viewport_size
	safe_layer.position = safe.position
	safe_layer.size = safe.size
	background.size = safe.size
	# Cover scaling crops authored arrows/hotspots on wide and narrow devices.
	# Fit the complete composed scene; world interaction uses this same transform.
	var fit := minf(safe.size.x / 1600.0, safe.size.y / 960.0)
	art_layer.scale = Vector2.ONE * fit
	art_layer.position = (safe.size - Vector2(1600,960) * fit) * 0.5
	return safe

func set_background(texture: Texture2D, crop_pause: bool = false) -> void:
	_clear_art()
	if crop_pause:
		# New city art contains a baked pause tab at the left edge. Omit that tab
		# from the decorative fill so there is only one pause control on screen.
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		var dimensions := texture.get_size()
		atlas.region = Rect2(dimensions.x * 0.09,0,dimensions.x * 0.91,dimensions.y)
		background.texture = atlas
	else:
		background.texture = texture

func _clear_art() -> void:
	component_background_active = false
	episode_timeline = null
	for child: Node in art_layer.get_children():
		art_layer.remove_child(child)
		child.queue_free()
	# Connect a static callback so queued scene destruction cannot resume a
	# coroutine on a freed canvas. Old visuals are released before the next frame.
	if is_inside_tree():
		var prune: Callable = preload("res://scripts/ui/blur_texture_cache.gd").prune
		if not get_tree().process_frame.is_connected(prune):
			get_tree().process_frame.connect(prune,CONNECT_ONE_SHOT)

func set_component_background(parts: Array) -> void:
	_clear_art()
	background.texture = null
	component_background_active = true
	COMPONENTS.draw(art_layer,parts)

func set_episode_background(artwork: String) -> bool:
	if not EPISODE_TIMELINE.has_art(artwork): return false
	_clear_art()
	background.texture = null
	component_background_active = true
	episode_timeline = EPISODE_TIMELINE.new()
	art_layer.add_child(episode_timeline)
	episode_timeline.configure(artwork)
	return true
