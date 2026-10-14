@tool
extends Control

const LOC := preload("res://scripts/core/localization.gd")
const BASE_SIZE := Vector2(1536, 864)
const FIELDS := {
	"Breaking": ["@loc:tv.dorwood.breaking", Rect2(286, 648, 775, 40), 38],
	"Headline": ["@loc:tv.dorwood.headline", Rect2(294, 693, 760, 50), 45],
	"Location": ["@loc:tv.dorwood.location", Rect2(294, 749, 760, 31), 30]
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(refresh_text)
	refresh_text()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): refresh_text()

func refresh_text() -> void:
	var factor: float = minf(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)
	if factor <= 0.0: return
	var origin: Vector2 = ((size - BASE_SIZE * factor) * 0.5).max(Vector2.ZERO)
	$Background.position = origin
	$Background.size = BASE_SIZE * factor
	for name: String in FIELDS:
		var field: Array = FIELDS[name]
		var label := get_node(name) as Label
		label.text = LOC.text(field[0])
		var rect: Rect2 = field[1]
		var target: Vector2 = rect.size * factor
		var pixels := maxi(1, roundi(float(field[2]) * factor))
		var font := label.get_theme_font("font")
		while pixels > 1 and (font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > target.x or font.get_height(pixels) > target.y): pixels -= 1
		label.add_theme_font_size_override("font_size", pixels)
		label.position = origin + rect.position * factor
		label.size = target
		label.set_deferred("size", target)
