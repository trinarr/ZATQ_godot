extends Control
# Assets remain independent layers; door movement is clipped to the doorway.
const LEFT := preload("res://assets/flash_ui/apartment/elevator_door_left.png")
const RIGHT := preload("res://assets/flash_ui/apartment/elevator_door_right.png")
const PRESSED := preload("res://assets/flash_ui/apartment/elevator_down_pressed.png")
const MASK := preload("res://assets/flash_ui/apartment/elevator_landing_light_mask.png")
const LIGHT := preload("res://shaders/elevator_landing_light.gdshader")
const STAGE_SCALE := Vector2(1600.0/1619.0, 960.0/972.0)
const OPENING := Rect2(665,99,337,758)
var view: Control
var left_door: TextureRect
var right_door: TextureRect
var door_clip: Control
var down_light: TextureRect
var call_hit: Button
var light_material: ShaderMaterial
var elapsed := 0.0
var opening := false
var progress := 0.0

func sprite(texture: Texture2D, crop: Rect2, rect: Rect2, host: Control) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = crop
	var image := TextureRect.new()
	image.texture = atlas
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.position = rect.position * STAGE_SCALE
	image.size = rect.size * STAGE_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(image)
	return image

func configure(ui: Control, opened: bool, animate_open: bool) -> void:
	view = ui
	name = "ElevatorLanding"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	light_material = ShaderMaterial.new()
	light_material.shader = LIGHT
	light_material.set_shader_parameter("landing_mask", MASK)
	light_material.set_shader_parameter("light_loss", 0.0)
	view.viewport_canvas.art_layer.get_child(0).material = light_material
	door_clip = Control.new()
	door_clip.position = OPENING.position * STAGE_SCALE
	door_clip.size = OPENING.size * STAGE_SCALE
	door_clip.clip_contents = true
	door_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(door_clip)
	left_door = sprite(LEFT, Rect2(621,97,189,776), Rect2(0,0,OPENING.size.x/2,OPENING.size.y), door_clip)
	right_door = sprite(RIGHT, Rect2(808,96,199,777), Rect2(OPENING.size.x/2,0,OPENING.size.x/2,OPENING.size.y), door_clip)
	# ImageGen supplies a larger button cutout; match its metal rim to the background.
	down_light = sprite(PRESSED, Rect2(1050,440,73,74), Rect2(1075,451,39,39), self)
	down_light.visible = opened
	opening = animate_open
	set_progress(0.0 if not opened or animate_open else 1.0)
	if opening: view.screen.set_meta("episode_animation_block", true)
	# Both states use the whole scene; pause/modals and door motion gate the hit.
	call_hit = view._world_hit("@loc:ui.main.45", Rect2(0,0,800,480), func():
		if not opening and Quest.current_id in ["lift", "lift_button"]: view._choose(0))
	call_hit.name = "AdvanceElevator"

func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	var width := door_clip.size.x/2.0
	left_door.position.x = -width * progress
	right_door.position.x = width + width * progress
	door_clip.visible = progress < 1.0

func set_landing_light_loss(value: float) -> void:
	# Prepared for a later lighting trigger. No caller or timer enables it now.
	var loss := clampf(value, 0.0, 1.0)
	light_material.set_shader_parameter("light_loss", loss)
	left_door.modulate = Color.WHITE * (1.0-loss*0.65)
	right_door.modulate = Color.WHITE * (1.0-loss*0.65)
	left_door.modulate.a = 1.0
	right_door.modulate.a = 1.0

func _process(delta: float) -> void:
	if not opening or view.paused: return
	elapsed += delta
	# Brief call-button confirmation followed by a smooth 0.9-second opening.
	var t := clampf((elapsed-0.25)/0.9, 0.0, 1.0)
	set_progress(t*t*(3.0-2.0*t))
	if t >= 1.0:
		opening = false
		view.screen.set_meta("episode_animation_block", false)
