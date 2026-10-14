@tool
extends Control

const LOC := preload("res://scripts/core/localization.gd")
const BASE_SIZE := Vector2(1536, 864)
const FIELDS := {
	"Brand": ["@loc:tv.vestnik.brand", Rect2(1290, 48, 122, 55), 42],
	"ChannelSuffix": ["@loc:tv.vestnik.suffix", Rect2(1418, 48, 60, 55), 42],
	# Keep the end of the headline clear of the TV's lower-right mute indicator.
	"Headline": ["@loc:tv.vestnik.headline", Rect2(20, 744, 1376, 50), 36],
	"Time": ["@loc:tv.vestnik.time", Rect2(98, 797, 174, 65), 55],
	"QuoteName": ["@loc:tv.vestnik.quote_name", Rect2(311, 797, 422, 65), 48],
	"QuoteValue": ["@loc:tv.vestnik.quote_value", Rect2(841, 797, 244, 65), 52],
	"QuoteChange": ["@loc:tv.vestnik.quote_change", Rect2(1122, 797, 300, 65), 52]
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
	for panel_name: String in ["BrandPanel", "SuffixPanel"]:
		var panel := get_node(panel_name) as ColorRect
		var panel_rect := Rect2(1283, 47, 132, 55) if panel_name == "BrandPanel" else Rect2(1415, 47, 64, 55)
		panel.position = origin + panel_rect.position * factor
		panel.size = panel_rect.size * factor
	for name: String in FIELDS:
		var field: Array = FIELDS[name]
		var label := get_node(name) as Label
		label.text = LOC.text(field[0])
		var rect: Rect2 = field[1]
		var target: Vector2 = rect.size * factor
		var pixels := maxi(1, roundi(float(field[2]) * factor))
		var font := label.get_theme_font("font")
		while pixels > 1 and (font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > target.x or font.get_height(pixels) > target.y):
			pixels -= 1
		label.add_theme_font_size_override("font_size", pixels)
		label.position = origin + rect.position * factor
		label.size = target
		label.set_deferred("size", target)
