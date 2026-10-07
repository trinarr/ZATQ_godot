extends SceneTree
var checks := 0
var failures := 0
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
 quest.save_path="user://episode4_test.json";quest.tmp_path="user://episode4_test.tmp";quest.backup_path="user://episode4_test.bak"
 quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui);await settle()
 check(quest.episode_starts.has(4),"fourth graph loaded")
 check(ui.selectors.any(func(e):return int(e.get("episode",0))==4 and e.available),"fourth episode enabled in menu")
 check(ui.LOC.text(quest.episode_metadata[4].title)=="IV. Исход","original episode title")
 var cases: Dictionary={64:"e4_church_1_v1",68:"e4_camp_1_v1",67:"e4_army_1_v1",-1:"e4_camp_1_v1"}
 for ending in cases:
  quest.stats_for(3).last_ending=ending;ui._start_episode(4)
  check(quest.current_id==cases[ending],"continuation matches active third-episode ending")
  check(not quest.flags.TakenKnife and quest.flags.BulletsNumber==-1,"new episode resets equipment")
 quest.stats_for(3).last_ending=64;quest._enter("e3_north_7")
 check(quest.stats_for(3).last_ending==64,"third episode writes active surviving ending")
 quest.stats_for(3).last_ending=67;quest.save_game();quest.stats_for(3).last_ending=68;quest._load_save()
 check(quest.stats_for(3).last_ending==67,"active ending survives save/reload")
 var walks: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/episode4_walkthroughs.json"))
 quest.extra_stats["4"]={"wins":0,"losses":0,"endings":[]}
 var lookup: Dictionary={"e4_church_1_v1":64,"e4_camp_1_v1":68,"e4_army_1_v1":67}
 for target: String in walks.results:
  var route: Dictionary=walks.results[target]
  quest.stats_for(3).last_ending=lookup[route.start];ui._start_episode(4)
  for index in route.choices:
   check(int(index)<quest.available_choices().size(),"route choice exists: "+quest.current_id)
   quest.choose(int(index))
  check(quest.current_id==target,"original ending reached: "+target)
  check(quest.episode==4 and quest.result_recorded,"result credited to fourth episode")
  var stats: Dictionary=quest.stats_for(4).duplicate(true)
  ui._show_story();quest._load_save()
  check(quest.stats_for(4)==stats,"result reload does not duplicate rewards/statistics")
  await settle()
 check(quest.stats_for(4).wins==3 and quest.stats_for(4).losses==31,"all three escapes and thirty-one death routes")
 check(quest.ending_count(4)==3 and quest.stats_for(4).endings.size()==3,"three original white check marks")
 # Every reached state renders using shared UI and retains native caption layout.
 for extent: Vector2i in [Vector2i(1600,960),Vector2i(2048,922)]:
  root.size=extent;await settle();ui.viewport_canvas.safe_override=Rect2(100,0,extent.x-100,extent.y);ui._fit_stage()
  for id: String in walks.states:
   var flags: Dictionary=walks.states[id][0]
   quest.flags.merge(flags,true);quest.current_id=id;quest.episode=4;ui.playing=true;ui.paused=false
   ui._show_story()
   var timeline: Node2D=ui.viewport_canvas.episode_timeline
   if is_instance_valid(timeline):timeline.seek_frame(timeline.frames.size()-1)
   await process_frame
   var node: Dictionary=quest.current()
   check(ui.section=="story","screen draws: "+id)
   if node.kind not in ["city_ending","city_death","city_pickup","city_decision","activity_dialogue"]:
    check(ui.viewport_canvas.component_background_active,"composed scene: "+id)
    check(is_instance_valid(ui.edge_hit)==ui._can_pause(),"pause policy: "+id)
   for caption: Node in ui.screen.get_children():
    if caption is Label and caption.visible:
     check(caption.get_line_count()<=caption.get_visible_line_count(),"all narrative lines visible: "+id)
   for c: Dictionary in quest.available_choices():
    if c.has("mask"):
     check(ui.COMPONENTS.HIGHLIGHT.has_mask(c.mask),"dynamic hit contour: "+id)
     var button: Button=ui.world_layer.find_child(ui.LOC.text(c.text),true,false)
     check(button!=null and ui.viewport_canvas.safe_layer.get_global_rect().encloses(button.get_global_rect()),"hit bounds inside complete authored frame: "+id)
 # Every authored intro/outro frame loads and applies through the common player.
 var timeline_type=load("res://scripts/ui/episode_timeline.gd")
 var animated_count:=0
 for art: String in timeline_type.catalog().art:
  if int(timeline_type.catalog().art[art].episode)!=4:continue
  animated_count+=1
  var player: Node2D=timeline_type.new();root.add_child(player);player.configure(art)
  for phase: String in ["intro","outro"]:
   player.play(phase);player.playing=false
   for index: int in player.frames.size():
    player.seek_frame(index)
    check(player.current_frame==index,"authored frame selected: "+art)
    for record: Array in player.frames[index]:
     var pivot: Node2D=player.sprites[record[0]]
     check(pivot.visible and pivot.transform.origin.is_equal_approx(Vector2(record[1][4],record[1][5])*2),"authored layer position: "+art)
     var visual: Control=pivot.get_child(0)
     if visual is TextureRect:check(visual.texture!=null,"component texture loads: "+art)
  player.free()
 check(animated_count==93,"all ninety-three animated scenes")
 # Original End-gated scenes cannot be skipped; pause still works for a nonfatal intro.
 quest._enter("e4_camp_1_v1")
 check(ui.world_layer.get_meta("episode_animation_block",false),"End-gated intro blocks story input")
 check(ui._can_pause(),"nonfatal intro keeps pause available")
 ui.viewport_canvas.episode_timeline.seek_frame(ui.viewport_canvas.episode_timeline.frames.size()-1)
 check(not ui.world_layer.get_meta("episode_animation_block",false),"End unlocks story input")
 quest._enter("e4_camp_14_v1");ui._show_pause()
 check(not ui.paused and not ui._can_pause(),"committed death intro cannot be paused")
 # Preserve both conditional knife results and item origin backdrops.
 for taken: bool in [false,true]:
  quest.flags.TakenKnife=taken;quest._enter("e4_jess_3_v3");quest.choose(0)
  check(quest.current_id==("e4_result_106" if taken else "e4_result_105"),"knife-dependent Jessica outcome")
 quest._enter("e4_camp_10_v1");quest.choose(0)
 check(quest.current_id=="e4_pickup_flashbang","independent camp item hotspot")
 check(ui.overlay!=null and ui.viewport_canvas.component_background_active,"item popup keeps configured scene background")
 ui.free();await settle()
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("Episode IV: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
