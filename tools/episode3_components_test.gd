extends SceneTree
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
 checks+=1
 if not value: failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var quest: Node=root.get_node("Quest")
 quest.save_path="user://e3_parts_test.json";quest.tmp_path="user://e3_parts_test.tmp";quest.backup_path="user://e3_parts_test.bak"
 quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await process_frame
 var screens:=0
 for id: String in quest.nodes:
  var data: Dictionary=quest.nodes[id]
  if int(data.get("episode",1))!=3:continue
  screens+=1
  for bullets: int in [-1,4,12]:
   quest.flags={"TakenKey":true,"Auto":0,"BulletsNumber":bullets,"LinkedFr":bullets>0}
   quest.flags.TakenKnife=bullets>0;quest.flags.JohnVariant=1;quest.flags.code="1234"
   quest.activity={};quest.current_id=id;quest.episode=3;ui.playing=true;ui.paused=false;ui._show_story()
   ui._stop_cutscene();ui.paused=true
   await process_frame
   check(ui.screen!=null,"screen instantiated: "+id)
   if data.kind=="activity_dialogue":
    var dialogue: Control
    for child: Node in ui.screen.get_children():
     if child.get_script()==load("res://scripts/ui/shared/player_dialog.gd"):dialogue=child
    check(dialogue!=null and dialogue.backdrop!=null,"dialogue owns art: "+id)
    if dialogue!=null:
     for part: Node in dialogue.backdrop.get_children():
      if part is TextureRect:check(part.texture!=null,"dialogue texture: "+id)
   if data.kind not in ["city_ending","city_death","activity_dialogue"]:
    check(ui.viewport_canvas.component_background_active,"component backdrop: "+id)
   if data.kind not in ["city_ending","city_death","city_pickup","city_decision"]:
    check(ui.edge_hit!=null,"separate pause control: "+id)
   for child: Node in ui.viewport_canvas.art_layer.get_children():
    check(child is TextureRect or child is ColorRect,"art is a primitive component")
    check(child.mouse_filter==Control.MOUSE_FILTER_IGNORE,"art leaves clicks to original hotspots")
    if child is TextureRect:check(child.texture!=null,"texture loaded: "+id)
   if data.kind=="activity_qte":
    var controller: Control
    for child: Node in ui.screen.get_children():
     if child.get_script()==load("res://scripts/ui/story_activity.gd"):controller=child
    check(controller!=null,"QTE controller: "+id)
    var frames: Array=data.get("animation_frames",[])
    for frame: int in frames.size():
     controller.state.remaining=float(data.seconds)-(frame+0.25)/float(data.animation_fps)
     controller.update_visuals()
     check(ui.viewport_canvas.component_background_active,"component animation frame: "+str(frames[frame]))
     check(controller.animation_index==(0 if data.get("qte_mode","")=="branch" else frame),"authored QTE frame index")
   for c: Dictionary in quest.available_choices():
    if c.has("mask"):check(ResourceLoader.exists("res://assets/flash_ui/"+c.mask+".png"),"interactive mask retained")
 check(screens==131,"all 131 episode screens exercised")
 var parts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/episode3_components.json"))
 for name: String in parts:
  for part: Dictionary in parts[name]:
   if part.type=="texture":check(ResourceLoader.exists("res://assets/flash_ui/"+part.texture),"component resource: "+name)
   else:check(part.type=="panel" and part.color.size()==4,"native panel")
 ui.queue_free();await process_frame
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("PASS: %d Episode III component checks; failures %d" % [checks,failures])
 quit(1 if failures else 0)
