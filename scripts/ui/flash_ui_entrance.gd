extends Node
signal finished
static var data: Dictionary = {}
var offsets: Array = []
var nodes: Array[Control] = []
var origins: Array[Vector2] = []
var elapsed := 0.0
var start_frame := 1
var playing := false
static func catalog() -> Dictionary:
 if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://data/episode1_ui_animations.json"))
 return data
func configure(host: Control, kind: String) -> void:
 var spec: Dictionary=catalog().tracks[kind];offsets=spec.offsets;start_frame=spec.start_frame
 for child: Node in host.get_children():
  if child is Control and child!=host.get("dimmer") and not child.get_meta("movie_clip_fixed",false):
   nodes.append(child);origins.append(child.position)
 playing=true;seek_frame(start_frame)
func seek_frame(index: int) -> void:
 var frame:=clampi(index,0,offsets.size()-1)
 var offset:=Vector2(offsets[frame][0],offsets[frame][1])*2
 for i: int in nodes.size():
  if is_instance_valid(nodes[i]):nodes[i].position=origins[i]+offset
 if frame==offsets.size()-1 and playing:
  playing=false;finished.emit()
func _process(delta: float) -> void:
 if not playing:return
 elapsed+=delta;seek_frame(start_frame+int(floor(elapsed*catalog().fps)))

func configure_targets(targets: Array, kind: String) -> void:
 var spec: Dictionary=catalog().tracks[kind];offsets=spec.offsets;start_frame=spec.start_frame
 for target: Control in targets:nodes.append(target);origins.append(target.position)
 playing=true;seek_frame(start_frame)
