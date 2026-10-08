extends Node
# Godot's frame delta may include scene construction before a MovieClip became
# visible. Anchor playback after its first draw, then use ordinary scaled delta.
var waiting_for_presentation := false
var first_step := false
var presented_usec := 0

func _ready() -> void:
 if waiting_for_presentation: _wait_for_draw()

func restart() -> void:
 waiting_for_presentation = true
 first_step = true
 if is_inside_tree(): _wait_for_draw()

func _wait_for_draw() -> void:
 # The dummy renderer emits no draw signal; offline simulations start at the
 # next process boundary instead. Device builds always use the real draw fence.
 if DisplayServer.get_name()=="headless":
  if not get_tree().process_frame.is_connected(_frame_presented):
   get_tree().process_frame.connect(_frame_presented,CONNECT_ONE_SHOT)
  return
 if not RenderingServer.frame_post_draw.is_connected(_frame_presented):
  RenderingServer.frame_post_draw.connect(_frame_presented,CONNECT_ONE_SHOT)

func _frame_presented() -> void:
 presented_usec = Time.get_ticks_usec()
 waiting_for_presentation = false

func advance(delta: float) -> float:
 if waiting_for_presentation: return 0.0
 if first_step:
  first_step = false
  var visible_seconds := float(Time.get_ticks_usec()-presented_usec)/1000000.0
  return minf(delta,visible_seconds*Engine.time_scale)
 return delta

func _exit_tree() -> void:
 if get_tree().process_frame.is_connected(_frame_presented):
  get_tree().process_frame.disconnect(_frame_presented)
 if RenderingServer.frame_post_draw.is_connected(_frame_presented):
  RenderingServer.frame_post_draw.disconnect(_frame_presented)
