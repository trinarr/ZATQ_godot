extends Node
const PLAYBACK_CLOCK := preload("res://scripts/ui/flash_playback_clock.gd")
var playback_clock := PLAYBACK_CLOCK.new()
# Discrete Flash keys. Offset every panel child, including its real hit targets.
signal finished
static var data: Dictionary = {}
var nodes: Array[Control] = []
var origins: Array[Vector2] = []
var input_nodes: Array[Control] = []
var input_filters: Array[int] = []
var focus_modes: Array[int] = []
var offsets: Array = []
var start_frame := 1
var frame := 0
var elapsed := 0.0
var playing := false

func _init() -> void:
	add_child(playback_clock)

static func timelines() -> Dictionary:
	if data.is_empty():
		data = JSON.parse_string(FileAccess.get_file_as_string("res://data/menu_animations.json"))
	return data

func configure(host: Control, panel: String, excluded: Control = null) -> void:
	offsets = timelines().panels[panel].offsets
	# Both original panel scripts jump to Flash frame 2 on creation.
	start_frame = int(timelines().panels[panel].start_frame)
	for child: Node in host.get_children():
		if child is Control and child != excluded:
			nodes.append(child)
			origins.append(child.position)
			_lock_input(child)
	elapsed = 0.0
	playback_clock.restart()
	playing = true
	seek_frame(start_frame)

func _lock_input(node: Control) -> void:
	if node is BaseButton:
		input_nodes.append(node)
		input_filters.append(node.mouse_filter)
		focus_modes.append(node.focus_mode)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children():
		if child is Control: _lock_input(child)

func _process(delta: float) -> void:
	if not playing: return
	elapsed += playback_clock.advance(delta)
	seek_frame(start_frame + int(floor(elapsed * timelines().fps)))

func seek_frame(index: int) -> void:
	frame = clampi(index,0,offsets.size()-1)
	var offset := Vector2(offsets[frame][0],offsets[frame][1])*2
	for i: int in nodes.size():
		if is_instance_valid(nodes[i]): nodes[i].position = origins[i]+offset
	if frame == offsets.size()-1 and playing:
		playing = false
		for i: int in input_nodes.size():
			if is_instance_valid(input_nodes[i]):
				input_nodes[i].mouse_filter = input_filters[i]
				input_nodes[i].focus_mode = focus_modes[i]
		finished.emit()
