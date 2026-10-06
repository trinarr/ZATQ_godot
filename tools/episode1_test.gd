extends SceneTree
var checks := 0
var failures := 0
var quest: Node
func check(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 quest = root.get_node("Quest")
 quest.save_path = "user://episode1_test.json"
 quest.tmp_path = "user://episode1_test.tmp"
 quest.backup_path = "user://episode1_test.bak"
 quest.episode1_stats = {"wins":0,"losses":0,"endings":[]}
 quest.sound_enabled = false
 var scene: Control = load("res://scenes/Main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 var paths: Dictionary = {"death_1": [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0], "death_5": [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "death_10": [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 3, 0, 0, 0, 0, 0, 0], "death_2": [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0], "death_3": [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0], "death_11": [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0], "death_9": [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0], "ending_77": [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0], "death_4": [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0], "death_8": [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0], "death_7": [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0], "ending_78": [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0], "ending_6": [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0]}
 for ending: String in paths:
  scene._start()
  for index: int in paths[ending]:quest.choose(index)
  check(quest.current_id==ending,"complete route from wake to "+ending)
  check(quest.current().get("kind","story") in ["city_death","city_ending"],"route has real result")
  check(quest.result_recorded,"result counted")
 check(quest.episode1_stats.wins==3 and quest.episode1_stats.losses==10,"three survival and ten death results")
 check(quest.episode1_stats.endings.size()==3,"all three unique endings found")
 var total: Dictionary = quest.episode1_stats.duplicate(true)
 for i in 3:quest._enter(quest.current_id)
 check(quest.episode1_stats==total,"result screen re-entry does not double-count")
 quest._load_save()
 check(quest.episode1_stats==total,"result resume does not double-count")
 scene._show_menu()
 scene._resume()
 check(quest.episode1_stats==total,"menu/continue does not double-count")
 # Every saved boundary now opens gameplay immediately.
 for id: String in ["farm_boundary","forest_boundary","mainstreet_boundary","taxi_boundary","taxi_escape_boundary","suburb_boundary"]:
  quest._enter(id)
  check(quest.current().get("kind","story")!="boundary" and not quest.available_choices().is_empty(),"legacy boundary continues: "+id)
 # Render every first-episode state and validate every choice under both flag sets.
 for id: String in quest.nodes:
  if int(quest.nodes[id].get("episode",1))!=1:continue
  await process_frame
  quest._enter(id)
  check(quest.current().get("kind","story")!="boundary","no unported first-episode boundary: "+id)
  check(not scene.screen.get_children().is_empty(),"state renders: "+id)
  for child: Node in scene.screen.get_children():
   if child is TextureRect:check(child.texture!=null,"loaded foreground: "+id)
  for auto: int in [0,1]:
   for key: bool in [false,true]:
    quest.flags={"Auto":auto,"TakenKey":key}
    quest._enter(id)
    var choices: Array=quest.available_choices().duplicate(true)
    for i in choices.size():
     quest.flags={"Auto":auto,"TakenKey":key}
     quest._enter(id)
     var choice: Dictionary=quest.available_choices()[i]
     var expected: String=choice.get("next",id)
     var with_keys: bool=choice.get("set",{}).get("TakenKey",quest.flags.TakenKey)
     var by_car: int=choice.get("set",{}).get("Auto",quest.flags.Auto)
     if with_keys and choice.has("with_keys"):expected=choice.with_keys
     if by_car==1 and choice.has("by_car"):expected=choice.by_car
     if choice.get("action","")=="channel":expected=id
     quest.choose(i)
     check(quest.current_id==expected,"choice and flags: %s/%d/%d/%s" % [id,i,auto,key])
 quest.flags={"TakenKey":false,"Auto":0}
 quest._enter("car_to_office")
 quest.choose(0)
 check(quest.current_id=="hired_office_gate","CarGet(1) starts MovCityAuto(3) at frame 7")
 quest.choose(0)
 check(quest.current_id=="office_enter" and quest.flags.Auto==0,"hired office ride enters directly and preserves pedestrian flag")
 check(quest.current().has("text_on_foot"),"original pedestrian office narration retained")
 # Arrow hit regions follow the exported silhouettes, including transparent gaps.
 quest._enter("farm_boundary")
 var arrow: Button=scene.screen.find_child("Продолжить путь",true,false)
 check(arrow.hit_image!=null,"arrow alpha mask loaded")
 check(not arrow._has_point(Vector2(-1,-1)),"arrow rejects outside coordinates")
 var opaque_found:=false
 var clear_found:=false
 for y in range(0,arrow.hit_image.get_height(),16):
  for x in range(0,arrow.hit_image.get_width(),16):
   var point:=Vector2(x,y)/Vector2(arrow.hit_image.get_size())*arrow.size
   if arrow.hit_image.get_pixel(x,y).a>0.1 and not opaque_found:
    opaque_found=true
    check(arrow._has_point(point),"visible arrow is clickable")
   elif arrow.hit_image.get_pixel(x,y).a==0 and not clear_found:
    clear_found=true
    check(not arrow._has_point(point),"transparent arrow gap lets input pass")
 check(opaque_found and clear_found,"mask includes visible and transparent pixels")
 # Pause/re-enter on a diary page and its exact save position.
 quest._enter("taxi_shelter_2")
 scene._show_pause()
 check(scene.paused,"diary can pause")
 scene._resume()
 check(quest.current_id=="taxi_shelter_2" and not scene.paused,"diary resume keeps position")
 check(quest.save_game(),"save diary")
 quest.current_id="wake"
 quest._load_save()
 check(quest.current_id=="taxi_shelter_2","load exact diary page")
 # Old version-1 saves without the new optional statistics fields remain valid.
 var legacy: Dictionary=quest._snapshot()
 legacy.erase("episode1_stats");legacy.erase("result_recorded")
 check(quest._valid(legacy),"old save compatibility")
 var corrupt: Dictionary=quest._snapshot()
 corrupt.episode1_stats={"wins":-1,"losses":0,"endings":[]}
 check(not quest._valid(corrupt),"invalid result statistics rejected")
 scene.queue_free()
 await create_timer(0.25).timeout
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 if failures==0:print("PASS: %d complete Episode I checks" % checks)
 await process_frame
 await process_frame
 quit(0 if failures==0 else 1)
