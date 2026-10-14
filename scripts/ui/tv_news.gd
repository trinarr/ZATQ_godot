@tool
extends Control

const LOC := preload("res://scripts/core/localization.gd")
const BASE_SIZE := Vector2(1536, 864)
const FIELDS := {
	"Developing": ["@loc:tv.news.developing", Rect2(294, 638, 434, 42), 38],
	"Headline": ["@loc:tv.news.headline", Rect2(300, 690, 980, 46), 40],
	"Subtitle": ["@loc:tv.news.subtitle", Rect2(300, 730, 980, 40), 35 * 0.92],
	"Discussion": ["@loc:tv.news.discussion", Rect2(130, 777, 1080, 43), 35],
	"TwitterHandle": ["@TRIN", Rect2(168, 715, 106, 56), 40]
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
		if name in ["Developing", "Headline"]: label.text = label.text.to_upper()
		var rect: Rect2 = field[1]
		var target: Vector2 = rect.size * factor
		var pixels := maxi(1, roundi(float(field[2]) * factor))
		var font := label.get_theme_font("font")
		while pixels > 1 and (font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > target.x or font.get_height(pixels) > target.y): pixels -= 1
		label.add_theme_font_size_override("font_size", pixels)
		if name in ["Headline", "Subtitle", "TwitterHandle"]:
			label.add_theme_constant_override("shadow_offset_x", maxi(1, roundi(2.0 * factor)))
			label.add_theme_constant_override("shadow_offset_y", maxi(1, roundi(2.0 * factor)))
		label.position = origin + rect.position * factor
		label.size = target
		label.set_deferred("size", target)
