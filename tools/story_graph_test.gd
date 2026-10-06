extends SceneTree
const LOC = preload("res://scripts/core/localization.gd")
const MODEL = preload("res://addons/story_graph/graph.gd")
var checks := 0
var failures := 0
func check(value:bool,message:String)->void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
 for episode:int in [1,2]:
  var graph:=MODEL.load_graph("res://data/story_graphs/episode%d.json" % episode)
  check(MODEL.validate(graph).is_empty(),"valid graph")
  var expected:Dictionary={}
  for path:String in (["opening","city_routes","episode1_routes"] if episode==1 else ["episode2_routes"]):
   expected.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/"+path+".json")).nodes,true)
  # Legacy image fields described superseded full-screen opening rasters.
  for id:String in expected:
   expected[id].erase("image")
   if expected[id].get("kind","") in ["city_death","city_ending"] and not graph.nodes[id].data.has("art"):
    expected[id].erase("art") # Shared result component replaced the old raster.
  var compiled:=MODEL.compile(graph)
  check(compiled.size()==expected.size(),"all screens preserved")
  for id:String in expected:
   check(LOC.resolve_tree(compiled.get(id),true)==LOC.resolve_tree(expected[id],true),"lossless migration "+id)
  var quest:Node=root.get_node("Quest")
  for id:String in compiled:check(quest.nodes.get(id)==compiled[id],"runtime uses graph "+id)
  var file: String="user://story_roundtrip.json"
  check(MODEL.save_graph(file,graph)==OK,"atomic graph save")
  check(MODEL.load_graph(file)==graph,"roundtrip all editor positions and data")
  var broken:=graph.duplicate(true)
  broken.edges[0].to="missing"
  check(not MODEL.validate(broken).is_empty(),"broken target rejected")
 var editor:Control=load("res://addons/story_graph/editor.gd").new()
 root.add_child(editor)
 await process_frame
 check(editor.document.nodes.size()==277,"editor loads first episode")
 var old:Dictionary=editor.document.duplicate(true)
 editor.add_block("qte")
 check(editor.document.nodes.size()==278,"add activity")
 editor.undo()
 check(editor.document==old,"undo restores graph")
 editor.redo()
 check(editor.document.nodes.size()==278,"redo activity")
 editor.load_document("res://data/story_graphs/episode2.json")
 check(editor.document.nodes.size()==301,"editor loads second episode")
 editor.focus_block("e2_hospital_1")
 check(editor.selected=="e2_hospital_1","search/focus screen")
 var choice_id: String="e2_hospital_1__choice_0"
 var old_next: String=MODEL.target(editor.document,choice_id,"next")
 var wire: int=editor.port_map[editor.names[choice_id]].find("next")
 editor.connect_blocks(editor.names[choice_id],wire,editor.names["e2_hospital_3"])
 check(MODEL.compile(editor.document).e2_hospital_1.choices[0].next=="e2_hospital_3","wire edit changes runtime route")
 editor.undo()
 check(MODEL.target(editor.document,choice_id,"next")==old_next,"undo connection")
 editor.focus_block("e2_hospital_1")
 editor.start_preview()
 check(editor.simulator.current_id=="e2_hospital_1","preview starts from selected scene")
 check(editor.simulator.save_path!=root.get_node("Quest").save_path,"preview save isolated")
 editor.simulator.free();editor.simulator=null
 editor.preview.queue_free()
 editor.path="user://graph_editor_draft_test.json"
 if FileAccess.file_exists(editor.path):DirAccess.remove_absolute(editor.path)
 editor.add_block("qte")
 check(editor.save_document(),"unfinished graph saved as draft")
 check(FileAccess.file_exists(editor.path+".draft") and not FileAccess.file_exists(editor.path),"draft does not replace published graph")
 var draft_path:String=editor.path+".draft"
 editor.load_document(draft_path)
 check(editor.document.nodes.size()==302 and editor.path==draft_path.trim_suffix(".draft"),"draft can be reopened for completion")
 for suffix:String in [".draft",".draft.bak"]:
  if FileAccess.file_exists(editor.path+suffix):DirAccess.remove_absolute(editor.path+suffix)
 editor.queue_free()
 await process_frame
 print("PASS: ",checks," story graph checks" if failures==0 else " FAILURES: "+str(failures))
 quit(1 if failures else 0)
