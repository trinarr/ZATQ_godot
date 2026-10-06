extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
 await process_frame
 await process_frame
func run() -> void:
 var quest: Node = root.get_node("Quest")
 quest.save_path="user://episode2_test.json"
 quest.tmp_path="user://episode2_test.tmp"
 quest.backup_path="user://episode2_test.bak"
 quest.sound_enabled=false
 quest.episode1_stats={"wins":0,"losses":0,"endings":[]}
 quest.episode2_stats={"wins":0,"losses":0,"endings":[]}
 var scene: Control = load("res://scenes/Main.tscn").instantiate()
 root.add_child(scene)
 await settle()
 var walks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/episode2_walkthroughs.json"))
 for ending: String in walks.results:
  scene._start_episode(2)
  for index: int in walks.results[ending]:
   scene._stop_cutscene()
   check(index<quest.available_choices().size(),"valid choice: "+quest.current_id)
   quest.choose(index)
  scene._stop_cutscene()
  await settle()
  check(quest.current_id==ending,"original route: "+ending)
  check(quest.episode==2 and quest.result_recorded,"episode II result recorded")
  var stats: Dictionary = quest.episode2_stats.duplicate(true)
  scene._show_story()
  quest._load_save()
  check(quest.episode2_stats==stats,"resume does not recount result")
  check(scene.screen.get_node("ResultCount").text==("%d/3" % stats.endings.size() if quest.current().alive else str(stats.losses)),"result shows episode-local statistic")
 check(quest.episode2_stats.wins==3 and quest.episode2_stats.losses==14,"three escapes and fourteen deaths")
 check(quest.episode2_stats.endings.size()==3,"all original surviving endings")
 check(quest.episode1_stats.wins==0 and quest.episode1_stats.losses==0,"statistics remain separate")
 # Save exact weapon/companion state, including a cancellable four-button decision.
 scene._start_episode(2)
 quest.flags.BulletsNumber=4
 quest.flags.LinkedFr=true
 quest._enter("e2_hospital_15_choice_16_1")
 scene._stop_cutscene()
 check(quest.save_game(),"save decision")
 quest.flags.BulletsNumber=-1
 quest.flags.LinkedFr=false
 quest.episode=1
 quest.current_id="wake"
 quest._load_save()
 check(quest.episode==2 and quest.flags.BulletsNumber==4 and quest.flags.LinkedFr,"weapon and companion resume")
 check(quest.current_id=="e2_hospital_15_choice_16_1" and quest.available_choices().size()==4,"decision resumes exactly")
 # Every authored node draws; dynamic labels and controls fit the 2x frame.
 for size: Vector2i in [Vector2i(1600,960),Vector2i(2048,920)]:
  root.size=size
  await settle()
  var extent: Vector2 = scene.get_viewport_rect().size
  scene.viewport_canvas.safe_override=Rect2(Vector2(80,0),extent-Vector2(80,0))
  scene._fit_stage()
  for id: String in walks.states:
   var state: Dictionary = walks.states[id]
   quest.flags.BulletsNumber=state.bullets
   quest.flags.LinkedFr=state.linked
   quest._enter(id)
   scene._stop_cutscene()
   await settle()
   check(scene.viewport_canvas.background.texture!=null or scene.viewport_canvas.component_background_active,"background: "+id)
   check(scene.screen.size==Vector2(1600,960) and is_equal_approx(scene.screen.scale.x,scene.screen.scale.y),"uniform episode II scale")
   for child: Node in scene.screen.get_children():
    if child is Label:
     check(child.position.x>=0 and child.position.x+child.size.x<=1600.1 and child.position.y+child.size.y<=960.1,"label bounds: "+id)
     check(child.get_line_count()<=child.get_visible_line_count(),"all text visible: "+id)
    if child is TextureRect:check(child.texture!=null,"control art: "+id)
 # Arrow regions match the original silhouettes; both branches remain clickable.
 for id: String in ["e2_hospital_16","e2_main_1"]:
  quest.flags.BulletsNumber=4
  quest._enter(id)
  scene._stop_cutscene()
  await settle()
  var choices: Array = quest.available_choices()
  for choice: Dictionary in choices:
   check(choice.has("mask") and choice.rect[2]<730,"arrow uses cropped alpha hit region")
   var button: Button = scene.screen.find_child(choice.text,true,false)
   check(button.hit_image!=null,"arrow mask imported")
   check(button.size.x==choice.rect[2]*2 and button.size.y==choice.rect[3]*2,"arrow hit size is uniformly doubled")
 # Enter through the episode selector, restart the current episode, and return to menu.
 quest.has_progress=false
 scene._show_selector("episodes")
 scene._cycle_selector(1)
 scene.screen.get_node("Начать").pressed.emit()
 await settle()
 check(quest.episode==2 and quest.current_id=="e2_hospital_1","selector starts second episode")
 scene._show_pause()
 scene.overlay.resume_hit.pressed.emit()
 check(scene.playing and not scene.paused,"pause resumes second episode")
 quest._enter("e2_result_38")
 scene.screen.get_node("Начать заново").pressed.emit()
 check(quest.current_id=="e2_hospital_1","restart retains episode")
 quest._enter("e2_result_38")
 scene.screen.get_node("В меню").pressed.emit()
 check(scene.section=="menu","result returns to menu")
 scene._start_episode(1)
 quest._enter("ending_6")
 scene.screen.get_node("Следующий эпизод").pressed.emit()
 check(quest.current_id=="e2_hospital_1" and quest.episode==2,"first episode continues into second")
 # Existing v1 saves remain readable; invalid second-episode data is rejected.
 var data: Dictionary = quest._snapshot().duplicate(true)
 data.flags.BulletsNumber=13
 check(not quest._valid(data),"reject impossible ammo count")
 data=quest._snapshot().duplicate(true);data.episode2_stats.endings=[6]
 check(not quest._valid(data),"reject cross-episode ending")
 scene._start_episode(1)
 data=quest._snapshot().duplicate(true)
 data.erase("episode");data.erase("episode2_stats")
 data.flags.erase("BulletsNumber");data.flags.erase("LinkedFr")
 check(quest._valid(data),"legacy episode I save accepted")
 scene.queue_free()
 await settle()
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 if failures==0:print("PASS: %d complete Episode II checks" % checks)
 quit(0 if failures==0 else 1)
