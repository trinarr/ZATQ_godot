extends Node2D
# Reusable soft eyelids. MovieClip playback supplies original poses; new scenes
# can use configure_default() and animate_closure() without an exported clip.
const TEXTURE := preload("res://assets/flash_ui/shared_components/eye_lid.png")
var lids: Dictionary = {}
var closure := 0.0
var motion: Tween
signal finished
func add_lid(part: Dictionary) -> Node2D:
 var pivot:=Node2D.new()
 var image:=TextureRect.new()
 image.texture=TEXTURE;image.flip_v=part.eye_lid=="lower"
 image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 image.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var r: Array=part.rect
 image.position=Vector2(r[0],r[1])*2.0;image.size=Vector2(r[2],r[3])*2.0
 pivot.add_child(image);add_child(pivot);lids[part.eye_lid]=pivot
 return pivot
func configure_default() -> void:
 if not lids.is_empty():return
 add_lid({"eye_lid":"upper","rect":[-1,-260.95,802,433]})
 add_lid({"eye_lid":"lower","rect":[-1,0,802,433]})
 set_closure(closure)
func set_closure(value: float) -> void:
 closure=clampf(value,0.0,1.0)
 if lids.size()!=2:return
 lids.upper.position=Vector2(0,lerpf(46.0,259.95,closure)*2.0)
 lids.lower.position=Vector2(0,lerpf(296.95,48.0,closure)*2.0)
func animate_closure(value: float, seconds: float) -> void:
 configure_default()
 if motion:motion.kill()
 motion=create_tween()
 motion.tween_method(set_closure,closure,clampf(value,0.0,1.0),maxf(0.0,seconds))
 motion.tween_callback(func():finished.emit())
static func blur_strength_at(frame_time: float, phase: String, track: Dictionary) -> float:
 var interval: Array=track.frames
 var progress: float=clampf((frame_time-float(interval[0]))/maxf(1.0,float(interval[1])-float(interval[0])),0.0,1.0)
 if phase!="intro":progress=1.0
 return progress if track.closing else 1.0-progress
