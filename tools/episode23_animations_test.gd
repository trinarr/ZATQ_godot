extends SceneTree
const TIMELINE := preload("res://scripts/ui/episode_timeline.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var catalog: Dictionary=TIMELINE.catalog()
 check(catalog.fps==19,"authored document fps")
 for episode: int in [2,3]:
  var count: int=0
  for art: String in catalog.art:
   if int(catalog.art[art].get("episode",1))!=episode:continue
   count+=1
   if catalog.art[art].get("outro_hold",false):
    check(catalog.art[art].outro==[catalog.art[art].intro[-1]],"no exit keys means hold final pose without restarting a nested clip")
   var player:=TIMELINE.new();root.add_child(player);player.configure(art)
   for phase: String in ["intro","outro"]:
    player.play(phase);player.playing=false
    for index: int in player.frames.size():
     player.seek_frame(index)
     check(player.current_frame==index,"source frame selected: "+art)
     for pivot: Node2D in player.sprites.values():
      check(is_finite(pivot.transform.origin.x) and is_finite(pivot.transform.origin.y),"finite layer transform")
      var visual: Control=pivot.get_child(0)
      if visual is TextureRect:check(visual.texture!=null,"sharp/component texture loads: "+art)
    player.play(phase);player.suspended=true
    var frame: int=player.current_frame
    player._process(0.11)
    check(player.current_frame==frame,"pause preserves exact frame")
    player.suspended=false;player._process(0.11)
    check(player.current_frame==mini(2,player.frames.size()-1),"resume continues existing player")
   player.free()
  check(count>30,"animated scenery coverage episode %d" % episode)
 check(catalog.art.e2_roof_6.intro.size()==126,"roof movie is not truncated at 81 frames")
 check(catalog.art.e3_opening_7.intro.size()==37,"opening plays all source stages")
 var quest: Node=root.get_node("Quest")
 quest.save_path="user://episode23_animation_test.json";quest.tmp_path="user://episode23_animation_test.tmp";quest.backup_path="user://episode23_animation_test.bak";quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await process_frame
 for episode: int in [2,3]:
  ui.playing=true;quest.new_game(episode)
  var ids: Array=["e2_roof_6","e2_hospital_18","e2_lift_3"] if episode==2 else ["e3_opening_7","e3_opening_9","e3_john_8"]
  for id: String in ids:
   quest.current_id=id;ui.playing=true;ui.paused=false;ui._show_story()
   var player: Node2D=ui.viewport_canvas.episode_timeline
   check(is_instance_valid(player),"cutscene uses authored player: "+id)
   if not is_instance_valid(player):continue
   var origin: String=quest.current_id
   player._process(0.10)
   ui._show_pause();var frame: int=player.current_frame;player._process(1.0)
   check(player.current_frame==frame,"pause freezes automatic cutscene")
   ui._resume()
   check(ui.viewport_canvas.episode_timeline==player and not player.suspended,"resume keeps cutscene instance")
   player.seek_frame(player.frames.size()-1)
   check(quest.current_id!=origin,"authored last frame advances cutscene")
 for sample: Array in [[2,"e2_hospital_1"],[2,"e2_roof_1"],[3,"e3_opening_1"]]:
  ui.playing=true;quest.new_game(sample[0]);quest.current_id=sample[1];ui.paused=false;ui._show_story()
  var caption_player: Node2D=ui.viewport_canvas.episode_timeline
  check(caption_player.captions.size()>=2,"description and band share a native track")
  if caption_player.captions.size()>=2:
   caption_player.seek_frame(0)
   check(caption_player.captions[0].label.modulate.a==caption_player.captions[1].label.modulate.a,"description band alpha follows text")
 ui.playing=true;quest.new_game(3)
 for id: String in ["e3_opening_8","e3_opening_11","e3_john_6","e3_john_18","e3_john_23","e3_kill_6"]:
  quest.current_id=id;quest.activity={};ui.playing=true;ui.paused=false;ui._show_story()
  var player: Node2D=ui.viewport_canvas.episode_timeline
  check(is_instance_valid(player) and player.spec.get("qte",false),"QTE uses component timeline: "+id)
  var activity: Control
  for child: Node in ui.screen.get_children():
   if child.has_method("press_target"):activity=child;break
  check(is_instance_valid(activity),"native QTE state retained")
  if not is_instance_valid(player) or not is_instance_valid(activity):continue
  var saved: Node2D=player
  var elapsed: float=float(activity.node.seconds)*0.5
  activity.state.remaining=float(activity.node.seconds)-elapsed
  activity.update_visuals()
  var expected: int=0 if activity.node.get("qte_mode","")=="branch" else mini(int(elapsed*19.0),player.frames.size()-1)
  check(player.current_frame==expected,"QTE scene seeks saved elapsed time")
  check(ui.viewport_canvas.episode_timeline==saved and not player.playing,"QTE does not recreate or run a second animation clock")
  ui._show_pause();activity._process(0.5)
  check(player.current_frame==expected,"QTE pause freezes authored visuals")
  ui._resume();activity.update_visuals()
  check(ui.viewport_canvas.episode_timeline==saved,"QTE resumes original timeline")
 ui.free()
 await process_frame
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("Episode II/III animations: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
