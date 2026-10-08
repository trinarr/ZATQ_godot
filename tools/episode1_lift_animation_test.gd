extends SceneTree
const TEST_CLOCK := preload("res://tools/flash_test_clock.gd")
const TIMELINE := preload("res://scripts/ui/episode_timeline.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:
  failures+=1
  push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var original: Dictionary=TIMELINE.catalog().duplicate(true)
 var image:=Image.create(4,4,false,Image.FORMAT_RGBA8)
 image.fill(Color.WHITE)
 var texture:=ImageTexture.create_from_image(image)
 DirAccess.make_dir_recursive_absolute("res://assets/flash_ui")
 var sample_name: String="_lift_test_%s.tres" % get_instance_id()
 var sample_path: String="res://assets/flash_ui/"+sample_name
 check(ResourceSaver.save(texture,sample_path)==OK,"test texture saved")
 var data: Dictionary=original.duplicate(true)
 data.art={"layout_bg_lift":data.art.layout_bg_lift,"layout_bg_lift_button":data.art.layout_bg_lift_button}
 for art: Dictionary in data.art.values():
  for part: Dictionary in art.parts.values():part.texture=sample_name
 TIMELINE.data=data
 var player:=TIMELINE.new();root.add_child(player);player.configure("layout_bg_lift")
 var opening: Array=player.spec.intro
 var authored: Array=player.spec.outro.duplicate(true)
 check(player.frames==opening,"opening retains authored frames")
 player.seek_frame(opening.size()-1)
 var visible_before: Array=[]
 for key: String in player.sprites:
  if player.sprites[key].visible:visible_before.append(key)
 player.play("outro")
 check(player.frames.size()==authored.size(),"closing retains duration")
 for key: String in player.sprites:
  check(player.sprites[key].visible==visible_before.has(key),"closing begins at open pose without a jump")
 for i in player.frames.size():
  var row: Array=player.frames[i]
  var expected: Array=opening[opening.size()-1-i]
  check(row.size()==expected.size(),"closing retains reversed door visibility")
  for j in row.size():
   check(row[j][0]==expected[j][0] and row[j][1]==expected[j][1],"door geometry follows closing sequence")
   check(row[j][2]==authored[i][0][2],"fade to black proceeds forward")
 check(player.spec.outro==authored,"cached authored data stays unchanged")
 TEST_CLOCK.step(player,2.0/float(data.fps))
 var saved_frame: int=player.current_frame
 player.suspended=true;TEST_CLOCK.step(player,1.0)
 check(player.current_frame==saved_frame,"pause freezes closing")
 player.suspended=false
 var completions: Array=[0]
 player.finished.connect(func():completions[0]+=1)
 TEST_CLOCK.step(player,1.0);TEST_CLOCK.step(player,1.0)
 check(completions[0]==1 and not player.playing,"closing finishes once")
 check(player.frames[-1][0][1]==opening[0][0][1],"closing ends at closed door pose")
 var other:=TIMELINE.new();root.add_child(other);other.configure("layout_bg_lift_button");other.play("outro")
 check(other.frames==other.spec.outro,"lift button animation stays unchanged")
 player.free();other.free()
 DirAccess.remove_absolute(sample_path)
 print("Lift animation: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
