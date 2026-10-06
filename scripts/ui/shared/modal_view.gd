extends "res://scripts/ui/shared/shared_view.gd"
# The host supplies the visible safe area in this component's coordinates.
var cover_rect := Rect2(Vector2.ZERO, LAYOUT.BASE_SIZE)
var dimmer: ColorRect

func _init() -> void:
	super()
	size = LAYOUT.BASE_SIZE
	set_meta("modal_view",true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	# Invisible blocker also protects layouts which deliberately have no shade.
	dimmer = ColorRect.new()
	dimmer.name = "InputBlocker"
	dimmer.color = Color.TRANSPARENT
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.mouse_force_pass_scroll_events = false
	dimmer.gui_input.connect(func(_event: InputEvent): dimmer.accept_event())
	add_child(dimmer)
	set_cover_rect(cover_rect)

func _ready() -> void:
	get_parent().child_order_changed.connect(_keep_modal_in_front)
	_keep_modal_in_front()

func _keep_modal_in_front() -> void:
	var parent := get_parent()
	if parent == null: return
	var top: Node
	for sibling: Node in parent.get_children():
		if sibling.has_meta("modal_view") and not sibling.is_queued_for_deletion(): top = sibling
	if top != null and top.get_index()!=parent.get_child_count()-1:
		parent.move_child(top,parent.get_child_count()-1)

func add_shade(alpha: float) -> void:
	dimmer.color = Color(0,0,0,alpha)
	set_cover_rect(cover_rect)

func set_cover_rect(rect: Rect2) -> void:
	cover_rect = rect
	if is_instance_valid(dimmer):
		dimmer.position = rect.position
		dimmer.size = rect.size
