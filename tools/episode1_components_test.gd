extends SceneTree
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
 checks+=1
 if not value: failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var quest: Node=root.get_node("Quest")
 quest.save_path="user://e1_parts_test.json";quest.tmp_path="user://e1_parts_test.tmp";quest.backup_path="user://e1_parts_test.bak"
 quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await process_frame
 var screens:=0
 for id: String in quest.nodes:
  var data: Dictionary=quest.nodes[id]
  if int(data.get("episode",1))!=1:continue
  screens+=1
  for auto: int in [0,1]:
   quest.flags={"TakenKey":true,"Auto":auto,"BulletsNumber":-1,"LinkedFr":false}
   quest.current_id=id;ui.playing=true;ui.paused=false;ui._show_story()
   await process_frame
   var n: Dictionary=quest.current()
   check(ui.screen!=null,"screen instantiated: "+id)
   if n.get("kind","") not in ["city_ending","city_death","item","city_decision"] and id!="transport_choice":
    check(ui.edge_hit!=null,"separate pause control: "+id)
   for child: Node in ui.viewport_canvas.art_layer.get_children():
    check(child is TextureRect or child is ColorRect,"art is a primitive component")
    check(child.mouse_filter==Control.MOUSE_FILTER_IGNORE,"art leaves clicks to original hotspots")
    if child is TextureRect:check(child.texture!=null,"texture loaded: "+id)
   for c: Dictionary in quest.available_choices():
    if c.has("mask"):check(ui.COMPONENTS.HIGHLIGHT.has_mask(c.mask) or ResourceLoader.exists("res://assets/flash_ui/"+c.mask+".png"),"interactive mask retained")
 check(screens==127,"all 127 episode screens exercised")
 for name: String in JSON.parse_string(FileAccess.get_file_as_string("res://data/episode1_components.json")):
  for part: Dictionary in ui.episode_components[name]:
   if part.type=="texture":check(ResourceLoader.exists("res://assets/flash_ui/"+part.texture),"component resource: "+name)
   elif part.type=="highlight":check(ui.COMPONENTS.HIGHLIGHT.definitions().regions.has(part.region),"dynamic highlight")
   else:check(part.type=="panel" and part.color.size()==4,"native panel")
 ui.queue_free();await process_frame
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("PASS: %d Episode I component checks; failures %d" % [checks,failures])
 quit(1 if failures else 0)
