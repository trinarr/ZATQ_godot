extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:
  failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var quest: Node=root.get_node("Quest")
 quest.save_path="user://hotspot_bounds_test.json";quest.tmp_path="user://hotspot_bounds_test.tmp";quest.backup_path="user://hotspot_bounds_test.bak"
 quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 var total_targets:=0
 for viewport_size: Vector2i in [Vector2i(2048,922),Vector2i(2400,1080),Vector2i(1280,960),Vector2i(1600,960)]:
  root.size=viewport_size;await process_frame
  for inset: Vector2 in [Vector2.ZERO,Vector2(108,12)]:
   ui.viewport_canvas.safe_override=Rect2(inset,Vector2(viewport_size)-inset-Vector2(0,12))
   ui._fit_stage()
   var safe: Rect2=ui.viewport_canvas.safe_layer.get_global_rect()
   var transform: Transform2D=ui.viewport_canvas.art_layer.get_global_transform()
   var stage_rect: Rect2=transform*Rect2(0,0,1600,960)
   check(safe.grow(0.01).encloses(stage_rect),"whole Flash frame remains visible at "+str(viewport_size))
   check(transform.get_scale().is_equal_approx(Vector2.ONE*minf(safe.size.x/1600.0,safe.size.y/960.0)),"story art uses uniform fit")
   for id: String in quest.nodes:
    var data: Dictionary=quest.nodes[id]
    if int(data.get("episode",1))>3:continue
    var targets: Array=data.get("choices",[]).duplicate()
    targets.append_array(data.get("targets",[]));targets.append_array(data.get("target_windows",[]))
    for target: Dictionary in targets:
     if not target.has("rect"):continue
     var r: Array=target.rect
     var global_rect: Rect2=transform*Rect2(Vector2(r[0],r[1])*2,Vector2(r[2],r[3])*2)
     check(safe.grow(0.01).encloses(global_rect),id+": authored target fully visible")
     total_targets+=1
   # Check actual UI nodes, not just catalog bounds, including the report scene,
   # near-edge arrows and differently authored QTE controls in all episodes.
   for sample: Array in [[1,"forest_lost"],[1,"forest_boundary"],[1,"farm_entry_1"],[1,"morning_choice"],[2,"e2_roof_8"],[2,"e2_hall_5"],[3,"e3_opening_11"],[3,"e3_john_23"]]:
    ui.playing=true;quest.new_game(sample[0]);quest.current_id=sample[1];quest.activity={};ui.paused=false;ui._show_story()
    ui._fit_stage()
    check(ui.world_layer.get_global_transform().is_equal_approx(ui.viewport_canvas.art_layer.get_global_transform()),sample[1]+": artwork and hits share coordinates")
    for parent: Control in [ui.world_layer,ui.screen]:
     for child: Node in parent.find_children("*","Button",true,false):
      if not child.is_visible_in_tree():continue
      check(safe.grow(0.1).encloses(child.get_global_rect()),sample[1]+": actual button remains inside safe area")
    if sample[1]=="forest_lost":
     for choice: Dictionary in quest.available_choices():
      var r: Array=choice.rect
      var point: Vector2=ui.viewport_canvas.art_layer.get_global_transform()*Vector2((r[0]+r[2]/2)*2,(r[1]+r[3]/2)*2)
      check(safe.has_point(point),"forest arrow center is visible and tappable")
 ui.free();await process_frame
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("Episode hotspot bounds: ",checks," checks across ",total_targets," authored targets, ",failures," failures")
 quit(1 if failures else 0)
