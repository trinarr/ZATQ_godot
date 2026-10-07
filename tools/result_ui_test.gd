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
 var ui: Control=root.get_node_or_null("ZombieApocalypse")
 if ui!=null and is_instance_valid(ui.overlay):
  for child: Node in ui.overlay.get_children():
   if child.has_method("configure_targets"):child.seek_frame(100)
func run() -> void:
 var quest: Node = root.get_node("Quest")
 quest.save_path="user://result_ui_test.json"
 quest.tmp_path="user://result_ui_test.tmp"
 quest.backup_path="user://result_ui_test.bak"
 quest.sound_enabled=false
 quest.episode1_stats={"wins":0,"losses":0,"endings":[]}
 var scene: Control = load("res://scenes/Main.tscn").instantiate()
 root.add_child(scene)
 await settle()
 scene._start()
 for size: Vector2i in [Vector2i(1600,960),Vector2i(2048,920),Vector2i(1280,960)]:
  root.size=size
  await settle()
  var extent: Vector2 = scene.get_viewport_rect().size
  scene.viewport_canvas.safe_override=Rect2(Vector2(90,0),extent-Vector2(90,0))
  scene._fit_stage()
  for id: String in ["death_1","death_2","death_3","death_4","death_5","death_7","death_8","death_9","death_10","death_11","ending_6","ending_77","ending_78"]:
   scene._start()
   quest._enter(id)
   await settle()
   var alive: bool = quest.current().kind=="city_ending"
   var body: Label = scene.screen.find_child("ResultStory",true,false)
   var count: Label = scene.screen.find_child("ResultCount",true,false)
   check(scene.overlay.get_script()==load("res://scripts/ui/shared/result_popup.gd"),"standalone result popup: "+id)
   check(is_equal_approx(scene.overlay.dimmer.color.a,0.9),"result shade matches item popup")
   check(scene.viewport_canvas.background.size==scene.viewport_canvas.safe_layer.size,"single safe-area background")
   check(scene.screen.find_child("ResultOutcome",true,false).text==("Итог: жив" if alive else "Итог: мертв"),"original outcome label")
   check(body.vertical_alignment==VERTICAL_ALIGNMENT_CENTER and body.horizontal_alignment==HORIZONTAL_ALIGNMENT_FILL,"original narrative alignment")
   check(body.get_line_count()<=body.get_visible_line_count(),"all story lines fit: "+id)
   check(body.size.y<=460.1,"body stays inside original panel: "+id)
   check(count.text==("%d/3" % quest.episode1_stats.endings.size() if alive else str(quest.episode1_stats.losses)),"original statistic semantics")
   check((scene.screen.find_child("Начать заново",true,false)!=null) and (scene.screen.find_child("В меню",true,false)!=null),"original result actions")
   check(not is_instance_valid(scene.edge_hit) or not scene.edge_hit.is_visible_in_tree(),"result has no gameplay pause")
   var safe: Rect2 = scene.viewport_canvas.safe_layer.get_global_rect()
   for name: String in ["Начать заново","В меню","ResultStory","ResultOutcome","ResultCount"]:
    check(safe.encloses(scene.screen.find_child(name,true,false).get_global_rect()),"result UI fits safe area: "+name)
 scene.screen.find_child("Начать заново",true,false).pressed.emit()
 await settle()
 check(quest.current_id=="wake" and scene.playing,"restart action")
 quest._enter("death_2")
 await settle()
 scene.screen.find_child("В меню",true,false).pressed.emit()
 await settle()
 check(scene.section=="menu" and not scene.playing,"menu action")
 scene.queue_free()
 await settle()
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
 if failures==0: print("PASS: %d original result UI checks" % checks)
 quit(0 if failures==0 else 1)
