extends Label
# The second glyph pass uses a shader, never a baked bitmap or theme shadow.
const SHADOW := preload("res://shaders/text_shadow.gdshader")
static var shadow_material: ShaderMaterial
var shadow_pass: Label
var shadow_offset := Vector2.ONE:
	set(value):
		shadow_offset = value
		request_shadow_sync()
var signature: Array = []
var sync_pending := false
var shadow_updates := 0

func _init() -> void:
	add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	if shadow_material == null:
		shadow_material = ShaderMaterial.new()
		shadow_material.shader = SHADOW
	shadow_pass = Label.new()
	shadow_pass.name = "TextShadow"
	shadow_pass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow_pass.show_behind_parent = true
	shadow_pass.material = shadow_material
	shadow_pass.add_theme_color_override("font_color",Color.WHITE)
	shadow_pass.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	shadow_pass.add_theme_color_override("font_outline_color",Color.TRANSPARENT)
	shadow_pass.add_theme_constant_override("outline_size",0)
	add_child(shadow_pass)
	set_process(false)
	resized.connect(request_shadow_sync)
	theme_changed.connect(request_shadow_sync)
	visibility_changed.connect(request_shadow_sync)
	draw.connect(request_shadow_sync)
	tree_entered.connect(request_shadow_sync)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		request_shadow_sync()

func request_shadow_sync() -> void:
	if sync_pending or not is_instance_valid(shadow_pass): return
	sync_pending = true
	sync_shadow.call_deferred()

func sync_shadow() -> void:
	sync_pending = false
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var spacing := get_theme_constant("line_spacing")
	var next: Array = [text,size,font,font_size,spacing,horizontal_alignment,vertical_alignment,autowrap_mode,justification_flags,clip_text,visible_characters,uppercase,language,text_direction,shadow_offset,get_theme_color("font_color").a]
	if next == signature: return
	signature = next
	shadow_updates += 1
	shadow_pass.horizontal_alignment = horizontal_alignment
	shadow_pass.vertical_alignment = vertical_alignment
	shadow_pass.autowrap_mode = autowrap_mode
	shadow_pass.justification_flags = justification_flags
	shadow_pass.clip_text = clip_text
	shadow_pass.visible_characters = visible_characters
	shadow_pass.uppercase = uppercase
	shadow_pass.language = language
	shadow_pass.text_direction = text_direction
	shadow_pass.add_theme_font_override("font",font)
	shadow_pass.add_theme_font_size_override("font_size",font_size)
	shadow_pass.add_theme_constant_override("line_spacing",spacing)
	shadow_pass.self_modulate.a = get_theme_color("font_color").a
	# Label clamps its size against the CURRENT font/wrapping minimum. Set
	# geometry last, after the complete text layout, or the first unwrapped
	# measurement leaves the shadow wider than the foreground.
	shadow_pass.text = text
	shadow_pass.size = size
	shadow_pass.position = shadow_offset
