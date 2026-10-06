extends TextureRect
# One foreground sprite; two alpha-shader layers make a compact extrusion.
const SHADOW_SHADER: Shader = preload("res://shaders/statistic_icon_shadow.gdshader")
static var shared_shadow: ShaderMaterial
var shadow_layers: Array[TextureRect] = []

func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if shared_shadow == null:
		shared_shadow = ShaderMaterial.new()
		shared_shadow.shader = SHADOW_SHADER
	for i: int in 2:
		var layer := TextureRect.new()
		layer.name = "Shadow%d" % (i+1)
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.material = shared_shadow
		layer.show_behind_parent = true
		add_child(layer)
		shadow_layers.append(layer)
	resized.connect(sync_shadow)

func _ready() -> void:
	sync_shadow()

func sync_shadow() -> void:
	for i: int in shadow_layers.size():
		var layer: TextureRect = shadow_layers[i]
		layer.texture = texture
		layer.size = size
		# Offsets use the same 1600x960 authoring space as the sprite, and
		# automatically scale with the episode selector and its safe area.
		layer.position = Vector2(1,2) * float(i+1)/2.0
