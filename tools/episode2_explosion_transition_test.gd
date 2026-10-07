extends SceneTree
const TIMELINE=preload("res://scripts/ui/episode_timeline.gd")
var checks:=0
var failures:=0
var transitions:Array[String]=[]
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var q:Node=root.get_node("Quest")
 q.save_path="user://episode2_explosion_test.json";q.tmp_path=q.save_path+".tmp";q.backup_path=q.save_path+".bak";q.sound_enabled=true
 var ui:Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await process_frame;await process_frame
 ui.playing=true;q.new_game(2)
 var listener:Callable=func():transitions.append(q.current_id)
 q.changed.connect(listener)
 q._enter("e2_hospital_20")
 var earlier:Node2D=ui.viewport_canvas.episode_timeline
 if is_instance_valid(earlier):earlier.seek_frame(earlier.frames.size()-1)
 ui._choose(0)
 if q.current_id=="e2_hospital_20":ui.viewport_canvas.episode_timeline.seek_frame(ui.viewport_canvas.episode_timeline.frames.size()-1)
 check(q.current_id=="e2_boom_4","shot leads directly to original explosion frame 4")
 var source:Node2D=ui.viewport_canvas.episode_timeline
 check(is_instance_valid(source),"explosion uses authored player")
 if not is_instance_valid(source):quit(1);return
 check(source.spec.clip=="Symbol 2652:3","MovBoom(3) starts at source frame 4")
 check(source.frames.size()==21 and source.phase=="intro" and source.spec.outro.size()==1,"full source flash plays once")
 check(is_equal_approx(source.duration("intro"),21.0/19.0),"original nineteen-fps duration")
 check(q.current().sound.is_empty() and not ui.effects.playing,"no premature explosion sound")
 for part:Dictionary in source.spec.parts.values():check(not "DoorOut.jpg" in part.get("source",""),"episode I entrance door excluded")
 ui._show_pause();check(not ui.paused and not q.current().get("pause_allowed",true),"fatal flash cannot pause")
 for frame:int in range(0,20):
  source.seek_frame(frame)
  check(q.current_id=="e2_boom_4","no transition before source End")
 source.seek_frame(20)
 check(q.current_id=="e2_boom_5","source End advances once to explosion image")
 check(q.current().sound=="Explosion" and ui.effects.playing,"explosion sound starts with source frame 5")
 check(ui.effects.stream.resource_path=="res://assets/audio/Explosion.mp3","original explosion audio")
 var photo:Node2D=ui.viewport_canvas.episode_timeline
 check(photo.spec.clip=="Symbol 2652:4","correct final source frame")
 check(photo.spec.parts.values().any(func(p):return "Boom.jpg" in p.get("source","")),"original explosion photograph")
 check(transitions.count("e2_boom_4")==1 and transitions.count("e2_boom_5")==1,"explosion scenes never restart")
 var losses:int=q.stats_for(2).losses
 photo.seek_frame(photo.frames.size()-1)
 check(q.current_id=="e2_result_35","original hospital death result")
 check(q.stats_for(2).losses==losses+1 and q.result_recorded,"death counted once")
 q._enter(q.current_id);check(q.stats_for(2).losses==losses+1,"result re-entry does not duplicate death")
 check(TIMELINE.catalog().art.city_door_explosion.clip=="Symbol 2652:0","episode I entrance explosion retained")
 check(TIMELINE.catalog().art.city_door_explosion.parts.values().any(func(p):return "DoorOut.jpg" in p.get("source","")),"episode I door retained")
 q.changed.disconnect(listener)
 ui.free();await process_frame
 for path:String in [q.save_path,q.tmp_path,q.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("Episode II explosion transition: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
