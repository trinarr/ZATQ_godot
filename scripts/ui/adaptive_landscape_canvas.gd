extends Control
# Background fills the safe rectangle. Authored UI keeps its uniform scale.
var safe_layer := Control.new()
var background := TextureRect.new()
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
	return safe

func set_background(texture: Texture2D, crop_pause: bool = false) -> void:
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
