extends Node2D
# A quiet hand-drawn outline. The filled hit mask remains owned by HIGHLIGHT.
const HIGHLIGHT := preload("res://scripts/ui/interactive_highlight.gd")
const FADE_SECONDS := 0.22
const WIDTH := 2.0
const ACTIVE_COLOR := Color(1.0, 0.65, 0.12, 1.0)
const LINE_ALPHA := 0.92 * 0.8 * 0.8
const SAMPLE_SPACING := 6.0
var region_id := ""
var fill_material: ShaderMaterial
var pulse_time := 0.0
var held := false
var active := false
var visibility_tween: Tween

func _ready() -> void:
	modulate.a = 0.0
	visibility_tween = create_tween()
	visibility_tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)

func fade_out() -> void:
	if visibility_tween != null and visibility_tween.is_valid(): visibility_tween.kill()
	visibility_tween = create_tween()
	visibility_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	visibility_tween.tween_callback(queue_free)

func bind_feedback(button: Button) -> void:
	button.button_down.connect(set_held.bind(true))
	button.button_up.connect(set_held.bind(false))
	button.mouse_exited.connect(set_held.bind(false))
	button.focus_exited.connect(set_held.bind(false))

func set_active(value: bool) -> void:
	active = value
	var color: Color = ACTIVE_COLOR if active else Color.WHITE
	fill_material.set_shader_parameter("glow_color", color)
	for child: Node in get_children():
		if child is Line2D:
			var stroke := child as Line2D
			stroke.default_color = Color(color.r, color.g, color.b, stroke.default_color.a)

func set_held(value: bool) -> void:
	if held == value: return
	held = value
	# Resume on the descending side of the peak: release begins at exactly 25%.
	pulse_time = 0.75
	fill_material.set_shader_parameter("fill_alpha", 0.25)

func _process(delta: float) -> void:
	if held: return
	pulse_time = fposmod(pulse_time + delta, 4.5)
	var phase := minf(pulse_time, 1.5) / 1.5
	var alpha := lerpf(0.08, 0.25, 0.5 - 0.5 * cos(phase * TAU))
	fill_material.set_shader_parameter("fill_alpha", alpha)

func configure(part: Dictionary) -> void:
	region_id = part.region
	name = "SketchOutline_" + region_id
	var rect: Array = part.rect
	position = Vector2(rect[0], rect[1]) * 2.0
	var region: Dictionary = HIGHLIGHT.definitions().regions[region_id]
	# Reuse the filled contour mask; pulse only its white interior layer.
	var shared: Dictionary = HIGHLIGHT.build_region(region_id)
	var fill := TextureRect.new()
	fill.name = "PulsingFill"
	fill.texture = shared.texture
	fill.position = -Vector2.ONE * HIGHLIGHT.PADDING
	fill.size = Vector2(region.size[0], region.size[1]) + Vector2.ONE * HIGHLIGHT.PADDING * 2
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fill.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	fill_material = shared.material.duplicate() as ShaderMaterial
	fill_material.set_shader_parameter("fill_alpha", 0.08)
	fill_material.set_shader_parameter("glow_color", Color.WHITE)
	fill_material.set_shader_parameter("alpha_min", 0.08)
	fill_material.set_shader_parameter("alpha_max", 0.25)
	fill_material.set_shader_parameter("period_seconds", 1.5)
	fill_material.set_shader_parameter("pause_seconds", 3.0)
	fill_material.set_shader_parameter("softness_px", 0.0)
	fill.material = fill_material
	add_child(fill)
	var phase := float(absi(region_id.hash()) % 1024) * 0.13
	for contour: Array in region.get("outline_contours", region.contours):
		var stroke := Line2D.new()
		stroke.closed = bool(region.get("outline_closed", true))
		stroke.points = pencil_points(contour, phase, stroke.closed)
		stroke.width = WIDTH
		stroke.default_color = Color(1.0, 1.0, 1.0, LINE_ALPHA)
		stroke.antialiased = true
		stroke.joint_mode = Line2D.LINE_JOINT_ROUND
		var variation := Curve.new()
		variation.add_point(Vector2(0.0, 0.85))
		variation.add_point(Vector2(0.22, 1.08))
		variation.add_point(Vector2(0.60, 0.80))
		variation.add_point(Vector2(0.90, 1.10))
		variation.add_point(Vector2(1.0, 0.85))
		stroke.width_curve = variation
		add_child(stroke)
		# Nested white strokes fade outward while keeping the pencil line crisp.
		for layer: Vector2 in [Vector2(12.0, 0.025), Vector2(9.0, 0.045), Vector2(6.0, 0.08), Vector2(4.0, 0.14)]:
			var halo := stroke.duplicate() as Line2D
			halo.width = layer.x
			halo.default_color = Color(1.0, 1.0, 1.0, layer.y)
			add_child(halo)
			# Keep the halo above the room background at the same Z as the line.
			# Child order places it behind the line without lowering its canvas Z.
			move_child(halo, stroke.get_index())
	set_meta("interactive_highlight", true)
	set_meta("highlight_style", "pencil_outline")

static func pencil_points(contour: Array, phase: float, closed: bool = true) -> PackedVector2Array:
	var vertices := PackedVector2Array()
	for i: int in range(0, contour.size(), 2):
		vertices.append(Vector2(contour[i], contour[i+1]))
	var points := PackedVector2Array()
	var distance := 0.0
	for i: int in (vertices.size() if closed else vertices.size() - 1):
		var start: Vector2 = vertices[i]
		var end: Vector2 = vertices[(i+1) % vertices.size()]
		var length := start.distance_to(end)
		if length <= 0.001: continue
		var normal := (end-start).normalized().orthogonal()
		var samples := maxi(1, ceili(length / SAMPLE_SPACING))
		for j: int in samples:
			var t := float(j) / samples
			var along := distance + t * length
			var roughness := 0.65*sin(along*0.35+phase) + 0.25*sin(along*0.81+phase*1.7)
			# Keep corners on the authored silhouette; perturb only along each edge.
			var envelope := minf(1.0, minf(t, 1.0-t)*length/5.0)
			points.append(start.lerp(end, t) + normal*roughness*envelope)
		distance += length
	if not closed and not vertices.is_empty():
		points.append(vertices[vertices.size() - 1])
	return points
