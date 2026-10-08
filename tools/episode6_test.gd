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
 quest.save_path="user://episode6_test.json";quest.tmp_path="user://episode6_test.tmp";quest.backup_path="user://episode6_test.bak";quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui);await settle()
 check(quest.episode_starts.has(6),"sixth graph loaded")
 check(ui.selectors.filter(func(e):return int(e.get("episode",0))==6 and e.available).size()==1,"one existing selector card")
 var walks: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/episode6_walkthroughs.json"))
 quest.extra_stats["6"]={"wins":0,"losses":0,"endings":[]}
 for target: String in walks.results:
  ui._start_episode(6)
  check(quest.current_id=="e6_carrier_1_v1","independent original start")
  for index: Variant in walks.results[target].choices:quest.choose(int(index))
  check(quest.current_id==target,"source ending route: "+target)
  check(quest.result_recorded,"result credited")
  var before: Dictionary=quest.stats_for(6).duplicate(true)
  quest._load_save();check(before==quest.stats_for(6),"saved result not counted twice")
 check(quest.stats_for(6).wins==2 and quest.stats_for(6).losses==22,"all 24 original episode results, no weapon test 150")
 check(quest.ending_count(6)==2 and quest.stats_for(6).endings.size()==2,"two original white check marks")
 check(not quest.episode_starts.has(7),"final episode has no nonexistent continuation")
 var data: Dictionary=quest.current("e6_carrier_7_v1")
 var state: Dictionary={"taps":0,"remaining":data.seconds};QTE.initialize(state,data)
 check(QTE.press(state,data)==0,"saving the man is the original fatal branch")
 check(QTE.timeout({"taps":0,"required_taps":1},data)==1,"not saving him continues the story")
 data=quest.current("e6_boats_7_v1");state={"taps":0,"remaining":data.seconds};QTE.initialize(state,data)
 QTE.press(state,data);check(QTE.press(state,data)==-1 and state.taps==1,"one press per target cycle")
 state.remaining=float(data.seconds)-float(data.cycle_seconds)-0.001
 check(QTE.press(state,data)==0,"second target disarms soldier")
 quest.new_game(6);quest._enter("e6_boats_7_v1");await settle()
 var positions: String=JSON.stringify(quest.activity.target_windows)
 quest.save_game();quest._load_save();check(JSON.stringify(quest.activity.target_windows)==positions,"random targets survive save/load")
 ui._show_pause()
 var taps: int=int(quest.activity.taps)
 for child: Node in ui.screen.get_children():
  if child.has_method("press_target"):child.press_target()
 check(int(quest.activity.taps)==taps,"pause blocks QTE")
 ui._resume()
 quest._enter("e6_wake_12_v3");check(not ui._can_pause(),"fatal Alice attack cannot pause")
 quest._enter("e6_pickup_m4_boats");await settle()
 check(ui.section=="story" and quest.current().background_art=="e6_boats_8_v1","pickup keeps the configured current scene")
 # The kitchen uses invisible native HIT buttons, not visible black ovals.
 root.size=Vector2i(2048,920);await settle();ui._fit_stage()
 for probe: Array in [[Vector2(125,350),"e6_pickup_knife"],[Vector2(420,135),"e6_boats_4_v1"]]:
  quest._enter("e6_boats_2_v1");await settle()
  var position: Vector2=ui.world_layer.get_global_transform()*(probe[0]*2)
  for down: bool in [true,false]:
   var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=position;event.pressed=down
   Input.parse_input_event(event);await process_frame
  check(quest.current_id==probe[1],"native kitchen button input: "+probe[1])
 # Draw every conditional state at the original and a wider device aspect ratio.
 for extent: Vector2i in [Vector2i(1600,960),Vector2i(2048,922)]:
  root.size=extent;await settle();ui._fit_stage()
  for id: String in walks.states:
   quest.flags.merge(walks.states[id][0],true);quest.current_id=id;quest.episode=6;quest.activity={};ui.playing=true;ui.paused=false
   ui._show_story();await process_frame
   var node: Dictionary=quest.current()
   check(ui.section=="story","render: "+id)
   if node.kind not in ["city_ending","city_death","city_pickup","city_decision","activity_dialogue"]:check(ui.viewport_canvas.component_background_active,"component art: "+id)
   for caption: Node in ui.screen.get_children():
    if caption is Label and caption.visible:check(caption.get_line_count()<=caption.get_visible_line_count(),"caption unclipped: "+id)
 var player_type=load("res://scripts/ui/episode_timeline.gd")
 for art: String in player_type.catalog().art:
  var spec: Dictionary=player_type.catalog().art[art]
  if int(spec.episode)!=6:continue
  var player: Node2D=player_type.new();root.add_child(player);player.configure(art);player.playing=false
  for phase: String in ["intro","outro"]:
   player.play(phase);player.playing=false
   for i: int in player.frames.size():
    player.seek_frame(i)
    for record: Array in player.frames[i]:check(player.sprites[record[0]].visible,"authored layer: "+art)
  for variable: String in spec.get("variables",{}):
   var expected: int=spec.variables[variable].size()
   check(spec.variables[variable].size()==expected,"complete independent control timeline")
   for i: int in spec.variables[variable].size():
    player.apply_variable_frame(variable,i)
    for record: Array in spec.variables[variable][i]:check(player.sprites[record[0]].visible,"variable pose layer")
  player.free()
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:DirAccess.remove_absolute(path)
 print("Episode VI: ",checks," checks; ",failures," failures")
 quit(1 if failures else 0)
