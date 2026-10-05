extends SceneTree
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func settle() -> void:
 await process_frame
 await process_frame
func check_tab(scene: Control, label: String) -> void:
 var tab: Rect2 = scene.edge_tab.get_global_rect()
 var safe: Rect2 = scene.viewport_canvas.safe_layer.get_global_rect()
 var hit: Rect2 = scene.edge_hit.get_global_rect()
 check(is_equal_approx(tab.position.x,safe.position.x),label+" at safe left edge")
 check(is_equal_approx(tab.get_center().y,safe.get_center().y),label+" vertically centered")
 check(hit.is_equal_approx(tab),label+" hitbox matches artwork")
 check(safe.encloses(tab),label+" inside safe area")
 check(scene.edge_hit.name==label,label+" callback button")
func run() -> void:
 var quest: Node = root.get_node("Quest")
 quest.save_path="user://opening_layout_test.json"
 quest.tmp_path="user://opening_layout_test.tmp"
 quest.backup_path="user://opening_layout_test.bak"
 quest.sound_enabled=false
 var scene: Control = load("res://scenes/Main.tscn").instantiate()
 root.add_child(scene)
 await settle()
 scene._start()
 for size: Vector2i in [Vector2i(1600,960),Vector2i(2048,920),Vector2i(2400,1080),Vector2i(1280,960)]:
  root.size=size
  await settle()
  var extent: Vector2 = scene.get_viewport_rect().size
  scene.viewport_canvas.safe_override=Rect2(Vector2(90,12),extent-Vector2(130,40))
  scene._fit_stage()
  quest._enter("wake")
  await settle()
  check_tab(scene,"Пауза")
  check(scene.viewport_canvas.art_layer.get_child_count()>0,"wake uses composed artwork")
  check(scene.screen.size==Vector2(1600,960) and is_equal_approx(scene.screen.scale.x,scene.screen.scale.y),"uniform 1600x960 UI")
  for child: Node in scene.screen.get_children():
   if child is TextureRect and child!=scene.edge_tab:
    check(child.texture.get_image().get_used_rect().size==Vector2i.ZERO,"wake foreground has no duplicate opaque image")
  scene.edge_hit.pressed.emit()
  await settle()
  check(scene.paused,"pause button opens overlay")
  check_tab(scene,"Продолжить")
  scene.edge_hit.pressed.emit()
  await settle()
  check(not scene.paused,"resume button resumes gameplay")
  check_tab(scene,"Пауза")
 for id: String in ["screams","morning_choice","transport","lift","lift_button","tv","city_car"]:
  quest._enter(id)
  await settle()
  check(scene.viewport_canvas.art_layer.get_child_count()>0 or scene.viewport_canvas.background.texture!=null,"background: "+id)
  check_tab(scene,"Пауза")
 scene.queue_free()
 await settle()
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
 if failures==0: print("PASS: %d opening and edge-control layout checks" % checks)
 quit(0 if failures==0 else 1)
