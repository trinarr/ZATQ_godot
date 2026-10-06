extends "res://scripts/ui/shared/shared_view.gd"
# The host supplies the visible safe area in this component's coordinates.
var cover_rect := Rect2(Vector2.ZERO, LAYOUT.BASE_SIZE)
var dimmer: ColorRect

func _init() -> void:
	super()
	size = LAYOUT.BASE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func add_shade(alpha: float) -> void:
	dimmer = ColorRect.new()
	dimmer.color = Color(0,0,0,alpha)
	add_child(dimmer)
	set_cover_rect(cover_rect)

func set_cover_rect(rect: Rect2) -> void:
	cover_rect = rect
	if is_instance_valid(dimmer):
		dimmer.position = rect.position
		dimmer.size = rect.size
