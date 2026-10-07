extends SceneTree
const TIMELINE=preload("res://scripts/ui/episode_timeline.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
 TranslationServer.set_locale("ru")
 var q:Node=root.get_node("Quest")
 q.save_path="user://shelter_transition_test.json";q.tmp_path=q.save_path+".tmp";q.backup_path=q.save_path+".bak";q.sound_enabled=false
 var ui:Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await process_frame;await process_frame
 ui.playing=true;q.new_game(1)
 var starts:Dictionary={"forest":"forest_cellar","taxi":"taxi_move","dorvud":"dorvud_room"}
 var results:Dictionary={"forest":"ending_6","taxi":"ending_77","dorvud":"ending_78"}
 var clips:Dictionary={"forest":"Symbol 2791:5","taxi":"Symbol 2515:5","dorvud":"Symbol 2968:7"}
 for prefix:String in results:
  # Enter each actual source frame once, then use UI choices, not direct jumps.
  q._enter(prefix+"_shelter_1")
  for step:int in range(1,4):
   var id:=prefix+"_shelter_"+str(step)
   check(q.current_id==id,"next authored diary state: "+id)
   check(q.current().art=="ep1_"+id,"diary has independent artwork")
   var player:Node2D=ui.viewport_canvas.episode_timeline
   check(is_instance_valid(player) and player.spec.clip==clips[prefix],"original shelter clip: "+id)
   if not is_instance_valid(player):continue
   check(player.frames.size()==5,"five authored frames to next stop")
   check(ui.world_layer.get_meta("episode_animation_block",false),"no skip before original stop")
   var button:Button
   for child:Node in ui.world_layer.get_children():
    if child is Button:button=child;break
   check(button!=null,"native continuation button")
   if button!=null:button.pressed.emit()
   check(q.current_id==id,"early tap cannot skip diary animation")
   for part:Dictionary in player.spec.parts.values():
    check(part.type=="panel" and not part.has("texture"),"black original backdrop; no chase photograph")
   check(player.captions.size()==step,"native diary captions bound to original motion")
   for frame:int in player.frames.size():
    player.seek_frame(frame)
    var source:Dictionary=TIMELINE.caption_data[player.art_name]
    for caption:Dictionary in player.captions:
     var found:=false
     for record:Array in source.intro[frame]:
      if record[0]==caption.text:
       check(is_equal_approx(caption.label.modulate.a,float(record[2][3])),"original caption alpha")
       found=true;break
     check(found,"original caption frame exists")
   check(not ui.world_layer.get_meta("episode_animation_block",false),"source stop enables next tap")
   if step<3:check(player.same_clip("ep1_"+prefix+"_shelter_"+str(step+1)),"next page continues same clip without replaying outro")
   if button!=null:button.pressed.emit()
   await process_frame
  check(q.current_id==results[prefix],"surviving ending after diary")
  check(q.current().alive and q.result_recorded,"ending credited once")
 # The legitimate fatal farm chase retains its original photo and result.
 q._enter("farm_chase")
 check(q.current().art=="ep1_farm_chase","fatal farm chase is preserved")
 var chase:Node2D=ui.viewport_canvas.episode_timeline
 check(is_instance_valid(chase),"farm chase still animated")
 if is_instance_valid(chase):
  check(chase.spec.parts.values().any(func(p):return "RunningZombies.jpg" in p.get("source","")),"chase retains authored photograph")
  chase.seek_frame(chase.frames.size()-1)
 await process_frame
 check(q.current_id=="death_4","fatal chase finishes at original death")
 ui.free();await process_frame
 for path:String in [q.save_path,q.tmp_path,q.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("Episode I shelter transitions: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
