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
 var examples: Array=[]
 for episode: int in [1,2,3,4,5,6,101]:
  var table: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/episode%d_text_animations.json" % episode))
  for art: String in table:
   var track: Dictionary=table[art]
   if track.intro.is_empty():continue
   if track.intro[0].any(func(record: Array):return record.size()>3 and not bool(record[3])):
    examples.append({"art":art,"track":track})
 check(examples.size()==78,"all 78 corrected captions have explicit initial visibility")
 for example: Dictionary in examples:
  var art: String=example.art
  var track: Dictionary=example.track
  var text: String=track.anchors.keys()[0]
  var poses: Array=[]
  for _index: int in track.intro.size():poses.append([])
  TIMELINE.data={"fps":19,"art":{art:{"parts":{},"intro":poses,"outro":[[]]}}}
  var player:=TIMELINE.new();host.add_child(player);player.configure(art);player.set_process(false)
  var block:=BLOCK.new()
  var label: Label=block.configure(host,text,Rect2(0,0,600,120),SystemFont.new(),20,{"storage":host,"band_rect":Rect2(0,0,1200,240)})
  player.bind_caption(label,"",block.band)
  check(not label.visible and not block.band.visible,"text and band start hidden: "+art)
  var previous:=0.0
  var revealed:=false
  for frame: int in track.intro.size():
   player.seek_frame(frame)
   var expected: float=0
   var visible:=false
   for record: Array in track.intro[frame]:
    if record[0]==text:
     expected=float(record[2][3]);visible=record.size()<4 or bool(record[3]);break
   check(is_equal_approx(label.modulate.a,expected),"label follows authored alpha: "+art)
   check(is_equal_approx(block.band.modulate.a,expected),"band follows same fade: "+art)
   check(label.visible==visible and block.band.visible==visible,"visibility follows exported frame: "+art)
   if visible:
    if not revealed:check(is_zero_approx(expected),"visibility begins at zero alpha: "+art)
    check(label.modulate.a>=previous,"visible fade is monotonic: "+art)
    previous=label.modulate.a;revealed=true
   else:
    check(is_equal_approx(expected,1.0),"hidden prefix retains authored alpha: "+art)
  player.free();label.free();block.band.free()
 TIMELINE.data=old_data;host.free()
 print("PASS: %d caption entrance checks; failures %d" % [checks,failures])
 quit(1 if failures else 0)
