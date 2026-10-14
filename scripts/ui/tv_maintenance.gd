@tool
extends Control
# A broadcast image with real translatable text, never baked lettering.
const LOC := preload("res://scripts/core/localization.gd")
const BASE_SIZE := Vector2(1536, 864)
const TITLE_RECT := Rect2(256, 454, 1024, 88)
const SUBTITLE_RECT := Rect2(256, 546, 1024, 58)

@export var title_key: String = "@loc:tv.maintenance.title"
@export var subtitle_key: String = "@loc:tv.maintenance.subtitle"
@onready var background: TextureRect = $Background
@onready var title_label: Label = $MaintenanceTitle
@onready var subtitle_label: Label = $MaintenanceSubtitle

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_fit)
	refresh_text()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh_text()

func refresh_text() -> void:
	title_label.text = LOC.text(title_key)
	subtitle_label.text = LOC.text(subtitle_key)
	_fit()

func _fit() -> void:
	if not is_node_ready() or size.x <= 0.0 or size.y <= 0.0: return
	var factor: float = minf(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)
	var offset: Vector2 = ((size - BASE_SIZE * factor) * 0.5).max(Vector2.ZERO)
	background.position = offset
	background.size = BASE_SIZE * factor
	_fit_label(title_label, TITLE_RECT, 56, factor, offset)
	_fit_label(subtitle_label, SUBTITLE_RECT, 36, factor, offset)

func _fit_label(label: Label, rect: Rect2, pixels: int, factor: float, offset: Vector2) -> void:
	var target_size := rect.size * factor
	var font: Font = label.get_theme_font("font")
	var font_size: int = maxi(1, roundi(pixels * factor))
	while font_size > 1 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > target_size.x:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)
	label.position = offset + rect.position * factor
	label.size = target_size
	# Font changes invalidate Label's minimum-size cache on the next frame.
	label.set_deferred("size", target_size)
