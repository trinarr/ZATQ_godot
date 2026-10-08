extends SceneTree
const TIMELINE := preload("res://scripts/ui/episode_timeline.gd")
const BLOCK := preload("res://scripts/ui/shared/narrative_block.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var host := Control.new();root.add_child(host)
 var old_data: Dictionary=TIMELINE.data
 var examples := ["e2_hall_4","e3_john_5","e4_camp_1_v1","e5_hide_5_v1","e6_base_1_v1","john2_10"]
 var episode_ids := [2,3,4,5,6,101]
 for i: int in examples.size():
  var art: String=examples[i]
  var text_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/episode%d_text_animations.json" % episode_ids[i]))
  var track: Dictionary=text_data[art]
  var text: String=track.anchors.keys()[0]
  var poses: Array=[]
  for _index: int in track.intro.size():poses.append([])
  TIMELINE.data={"fps":19,"art":{art:{"parts":{},"intro":poses,"outro":[[]]}}}
  var player:=TIMELINE.new();host.add_child(player);player.configure(art);player.set_process(false)
  var block:=BLOCK.new()
  var label: Label=block.configure(host,text,Rect2(0,0,600,120),SystemFont.new(),20,{"storage":host,"band_rect":Rect2(0,0,1200,240)})
  player.bind_caption(label,"",block.band)
  check(label.modulate.a==0 and block.band.modulate.a==0,"no premature text or band: "+art)
  var previous:=0.0
  for frame: int in track.intro.size():
   player.seek_frame(frame)
   var expected: float=0
   for record: Array in track.intro[frame]:
    if record[0]==text:expected=float(record[2][3]);break
   check(is_equal_approx(label.modulate.a,expected),"label follows authored alpha: "+art)
   check(is_equal_approx(block.band.modulate.a,expected),"band follows same fade: "+art)
   check(label.modulate.a>=previous,"entrance fade has no disappearance: "+art)
   previous=label.modulate.a
  player.free();label.free();block.band.free()
 TIMELINE.data=old_data;host.free()
 print("PASS: %d caption entrance checks; failures %d" % [checks,failures])
 quit(1 if failures else 0)
