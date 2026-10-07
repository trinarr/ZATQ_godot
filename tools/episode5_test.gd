extends SceneTree
var checks := 0
var failures := 0
const QTE := preload("res://scripts/core/qte_rules.gd")
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
 await process_frame
 await process_frame
func run() -> void:
 TranslationServer.set_locale("ru")
 var quest: Node=root.get_node("Quest")
 quest.save_path="user://episode5_test.json";quest.tmp_path="user://episode5_test.tmp";quest.backup_path="user://episode5_test.bak";quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui);await settle()
 check(quest.episode_starts.has(5),"fifth graph loaded")
 check(ui.selectors.any(func(e):return int(e.get("episode",0))==5 and e.available),"episode selectable")
 var walks: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/episode5_walkthroughs.json"))
 quest.extra_stats["5"]={"wins":0,"losses":0,"endings":[]}
 for target: String in walks.results:
  ui._start_episode(5)
  check(quest.current_id=="e5_plane_1_v1" and not quest.flags.TakenDocs and not quest.flags.TakenArmor,"independent Alice start and equipment reset")
  for index: Variant in walks.results[target].choices:quest.choose(int(index))
  check(quest.current_id==target,"source ending route: "+target)
  check(quest.result_recorded,"result credited")
  var before: Dictionary=quest.stats_for(5).duplicate(true)
  quest._load_save();check(before==quest.stats_for(5),"saved result not counted twice")
 check(quest.stats_for(5).wins==4 and quest.stats_for(5).losses==19,"all original results")
 check(quest.ending_count(5)==3 and quest.stats_for(5).endings.size()==3,"three unique check marks; 136 aliases 133")
 quest.new_game(5);quest._enter("e5_dialogue_lex_0")
 var password: String=quest.flags.PilotCode
 check(password.begins_with("*") and password.ends_with("#") and password.length()>=8,"original generated password")
 quest._enter("e5_dialogue_lex_49")
 check(quest.current().text.contains(password) and quest.available_choices()[0].text.contains(quest.flags.PilotCodeSpaced),"localized dialogue displays generated code")
 quest.save_game();quest.flags.PilotCode="*000000#";quest._load_save()
 check(quest.flags.PilotCode==password,"password persists")
 quest.flags.TakenDocs=false;quest._enter("e5_dialogue_lex_31");check(quest.available_choices().size()==2,"document answer hidden")
 quest.flags.TakenDocs=true;check(quest.available_choices().size()==3,"document answer enabled");quest.choose(2);check(quest.current_id=="e5_upper_3_v3","document answer changes branch")
 quest.flags.PilotCode=password;quest._enter("e5_upper_12_v1");await settle()
 var activity: Control
 for child: Node in ui.screen.get_children():
  if child.has_method("press_target"):activity=child;break
 var keypad: Control=activity.keypad
 check(keypad.buttons.size()==12,"twelve original keypad buttons")
 for ch: String in password:keypad.press(ch)
 check(quest.current_id=="e5_upper_12_v1" and quest.activity.status=="accepted","correct code awaits green feedback")
 ui.paused=true;var remaining: float=quest.activity.feedback_remaining;keypad._process(0.5)
 check(quest.activity.feedback_remaining==remaining,"pause freezes keypad")
 ui.paused=false
 quest.save_game();quest._load_save();ui._show_story();ui.paused=true;await settle()
 for child: Node in ui.screen.get_children():
  if child.has_method("press_target"):activity=child;break
 keypad=activity.keypad
 check(quest.activity.status=="accepted" and is_equal_approx(float(quest.activity.feedback_remaining),remaining),"accepted feedback survives save/reload")
 ui.paused=false;keypad._process(1.0);check(quest.current_id=="e5_upper_13_v1","green feedback opens door")
 quest._enter("e5_upper_12_v1");await settle();for child: Node in ui.screen.get_children():
  if child.has_method("press_target"):activity=child;break
 keypad=activity.keypad
 for i: int in 3:
  keypad.press("*");keypad.press("#")
 check(quest.current_id=="e5_result_123","three wrong submissions fail")
 var ratchet: Dictionary=quest.current("e5_plane_15_v1")
 var state: Dictionary={"taps":0,"remaining":ratchet.seconds};QTE.initialize(state,ratchet)
 check(QTE.press(state,ratchet)==-1 and int(state.lock_frame)==9,"ratchet first impulse")
 QTE.advance(state,ratchet,5.0/19.0);check(int(state.lock_frame)==14,"ratchet returns without taps")
 QTE.press(state,ratchet);QTE.press(state,ratchet);check(QTE.press(state,ratchet)==0,"three quick impulses unlock")
 state.remaining=0.0;check(QTE.timeout(state,ratchet)==1,"timeout fails despite accumulated taps")
 var timed: Dictionary=quest.current("e5_plane_20_v1")
 state={"taps":0,"remaining":timed.seconds};QTE.initialize(state,timed)
 check(QTE.windows(state,timed).size()==3,"three randomized time windows")
 QTE.press(state,timed);check(QTE.press(state,timed)==-1 and int(state.taps)==1,"one hit per cycle")
 state.remaining=float(timed.seconds)-float(timed.cycle_seconds)-0.001
 check(QTE.press(state,timed)==0,"second cycle hit succeeds")
 quest._enter("e5_plane_20_v1");await settle()
 var positions: String=JSON.stringify(quest.activity.target_windows)
 quest.save_game();quest._load_save();await settle()
 check(JSON.stringify(quest.activity.target_windows)==positions,"random target positions survive reload")
 var tapped: int=int(quest.activity.taps)
 ui._show_pause()
 for child: Node in ui.screen.get_children():
  if child.has_method("press_target"):activity=child;break
 activity.press_target()
 check(int(quest.activity.taps)==tapped,"pause blocks native QTE input")
 ui._resume()
 quest._enter("e5_under_4_v1")
 check(not ui._can_pause(),"fatal shooting cannot pause")
 # Draw every conditional state at the original and a wider device aspect ratio.
 for extent: Vector2i in [Vector2i(1600,960),Vector2i(2048,922)]:
  root.size=extent;await settle();ui._fit_stage()
  for id: String in walks.states:
   quest.flags.merge(walks.states[id][0],true);quest.current_id=id;quest.episode=5;quest.activity={};ui.playing=true;ui.paused=false
   ui._show_story();await process_frame
   var node: Dictionary=quest.current()
   check(ui.section=="story","render: "+id)
   if node.kind not in ["city_ending","city_death","city_pickup","city_decision","activity_dialogue"]:check(ui.viewport_canvas.component_background_active,"component art: "+id)
   for caption: Node in ui.screen.get_children():
    if caption is Label and caption.visible:check(caption.get_line_count()<=caption.get_visible_line_count(),"caption unclipped: "+id)
 var player_type=load("res://scripts/ui/episode_timeline.gd")
 for art: String in player_type.catalog().art:
  var spec: Dictionary=player_type.catalog().art[art]
  if int(spec.episode)!=5:continue
  var player: Node2D=player_type.new();root.add_child(player);player.configure(art);player.playing=false
  for phase: String in ["intro","outro"]:
   player.play(phase);player.playing=false
   for i: int in player.frames.size():
    player.seek_frame(i)
    for record: Array in player.frames[i]:check(player.sprites[record[0]].visible,"authored layer: "+art)
  for variable: String in spec.get("variables",{}):
   var expected: int=15 if variable=="lock" else 33
   check(spec.variables[variable].size()==expected,"complete independent control timeline")
   for i: int in spec.variables[variable].size():
    player.apply_variable_frame(variable,i)
    for record: Array in spec.variables[variable][i]:check(player.sprites[record[0]].visible,"variable pose layer")
  player.free()
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:DirAccess.remove_absolute(path)
 print("Episode V: ",checks," checks; ",failures," failures")
 quit(1 if failures else 0)
