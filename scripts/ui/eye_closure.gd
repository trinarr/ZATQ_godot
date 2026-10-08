extends Node2D
# Reusable soft eyelids. MovieClip playback supplies original poses; new scenes
# can use configure_default() and animate_closure() without an exported clip.
const TEXTURE := preload("res://assets/flash_ui/shared_components/eye_lid.png")
const OPEN_FADE_SECONDS := 0.35
const OPEN_FADE_START := 0.70
const CLOSE_FADE_SECONDS := 0.12
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
 _set_pose(closure)
func _set_pose(value: float) -> void:
 if lids.size()!=2:return
 lids.upper.position=Vector2(0,lerpf(46.0,259.95,value)*2.0)
 lids.lower.position=Vector2(0,lerpf(296.95,48.0,value)*2.0)
func animate_closure(value: float, seconds: float) -> void:
 configure_default()
 if motion:motion.kill()
 motion=create_tween()
 var opening: bool=value<closure
 if opening:
  var from: float=closure
  var target: float=clampf(value,0.0,1.0)
  var travel: float=maxf(0.001,seconds)
  var fade_start: float=travel*OPEN_FADE_START
  modulate.a=1.0
  motion.tween_method(func(time: float):
   var pose: float=lerpf(from,target,time/travel)
   closure=clampf(pose,0.0,1.0)
   _set_pose(pose)
   modulate.a=1.0-smoothstep(fade_start,fade_start+OPEN_FADE_SECONDS,time)
  ,0.0,fade_start+OPEN_FADE_SECONDS,fade_start+OPEN_FADE_SECONDS)
  motion.tween_callback(func():closure=target;finished.emit())
 else:
  modulate.a=0.0 if closure<=0.0 else modulate.a
  motion.tween_property(self,"modulate:a",1.0,CLOSE_FADE_SECONDS)
  motion.parallel().tween_method(set_closure,closure,clampf(value,0.0,1.0),maxf(0.0,seconds))
  motion.tween_callback(func():finished.emit())

static func smooth_frames(source: Array, parts: Dictionary, fps: float) -> Array:
 var lower: String=""
 for key: String in parts:
  if parts[key].get("eye_lid","")=="lower":lower=key;break
 if lower.is_empty():return source
 var first: int=-1;var last: int=-1;var first_y:=0.0;var last_y:=0.0
 for i: int in source.size():
  for record: Array in source[i]:
   if record[0]!=lower:continue
   if first<0:first=i;first_y=float(record[1][5])
   last=i;last_y=float(record[1][5])
 if first<0 or absf(last_y-first_y)<1.0:return source
 var result: Array=source.duplicate(true)
 if last_y>first_y:
  # Start fading at 70% of the actual lower-lid travel, not at 70%
  # of the clip length. Continue both lids' travel until alpha reaches zero.
  var fade_start: float=float(last)
  var previous_frame: int=first
  var previous_progress:=0.0
  for i: int in range(first,last+1):
   for record: Array in source[i]:
    if record[0]!=lower:continue
    var progress: float=(float(record[1][5])-first_y)/(last_y-first_y)
    if progress>=OPEN_FADE_START:
     fade_start=lerpf(float(previous_frame),float(i),(OPEN_FADE_START-previous_progress)/maxf(0.0001,progress-previous_progress))
     break
    previous_frame=i;previous_progress=progress
   if fade_start<float(last):break
  var fade_frames: float=OPEN_FADE_SECONDS*fps
  var end: int=maxi(last,ceili(fade_start+fade_frames))
  var initial_lids: Dictionary={}
  for record: Array in source[first]:
   if parts[record[0]].has("eye_lid"):initial_lids[record[0]]=record
  var final_lids: Array=[]
  for record: Array in source[last]:
   if parts[record[0]].has("eye_lid"):final_lids.append(record.duplicate(true))
  while result.size()<=end:result.append(source[-1].duplicate(true))
  for i: int in range(first,end+1):
   var alpha: float=1.0-smoothstep(fade_start,fade_start+fade_frames,float(i))
   var row: Array=result[i]
   if i<=last:
    for record: Array in row:
     if parts[record[0]].has("eye_lid"):record[2][3]*=alpha
   else:
    for j: int in range(row.size()-1,-1,-1):
     if parts[row[j][0]].has("eye_lid"):row.remove_at(j)
    for pose: Array in final_lids:
     var record: Array=pose.duplicate(true)
     var start_pose: Array=initial_lids[record[0]]
     for axis: int in [4,5]:
      record[1][axis]+= (float(pose[1][axis])-float(start_pose[1][axis]))*float(i-last)/float(last-first)
     record[2][3]*=alpha;row.append(record)

 else:
  # A closing clip may insert lids abruptly at its first open pose.
  var fade: int=maxi(1,ceili(CLOSE_FADE_SECONDS*fps))
  for i: int in range(first,mini(last+1,first+fade)):
   for record: Array in result[i]:
    if parts[record[0]].has("eye_lid"):record[2][3]*=smoothstep(0.0,1.0,float(i-first)/float(fade))
 return result
static func blur_strength_at(frame_time: float, phase: String, track: Dictionary) -> float:
 var interval: Array=track.frames
 var progress: float=clampf((frame_time-float(interval[0]))/maxf(1.0,float(interval[1])-float(interval[0])),0.0,1.0)
 if phase!="intro":progress=1.0
 return progress if track.closing else 1.0-progress
