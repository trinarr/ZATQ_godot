extends SceneTree
# Build a minimal export containing imported translations, never source CSV.
# Run the resulting pack from outside the checkout to exercise device lookup.
func _initialize() -> void:
 var args := OS.get_cmdline_user_args()
 if args.size()!=1:
  push_error("Usage: --script res://tools/john_export_localization_test.gd -- /tmp/john_locale.pck")
  quit(1);return
 var pack := PCKPacker.new()
 assert(pack.pck_start(args[0])==OK)
 var config := "[application]\nconfig/name=\"John localization export test\"\nrun/main_scene=\"res://check.tscn\"\n"
 var scene := "[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"res://check.gd\" id=\"1\"]\n[node name=\"Check\" type=\"Node\"]\nscript=ExtResource(\"1\")\n"
 var script := '''extends Node
const LOC=preload("res://scripts/core/localization.gd")
var translated_keys=0
func verify(value):
 if value is Dictionary:
  for child in value.values():verify(child)
 elif value is Array:
  for child in value:verify(child)
 elif value is String and value.begins_with("@loc:"):
  var text=LOC.text(value)
  assert(not text.is_empty() and text!=value.trim_prefix("@loc:"))
  translated_keys+=1
func _ready():
 assert(not FileAccess.file_exists("res://locales/episode101.csv"))
 LOC.prepare()
 var graph=JSON.parse_string(FileAccess.get_file_as_string("res://data/story_graphs/episode101.json"))
 verify(graph)
 var checks=0
 for node in graph.nodes.values():
  for block in node.get("data",{}).get("blocks",[]):
   var text=LOC.text(block.text)
   assert(not text.begins_with("episode101.") and not text.is_empty())
   checks+=1
 assert(LOC.text(graph.title)=="ВЕБ-ЭПИЗОД 1. ДЖОН")
 assert(LOC.text(graph.nodes.john1_7.data.blocks[0].text).contains("Спустя"))
 print("John packaged localization without CSV: ",checks," narrative blocks, ",translated_keys," text references passed")
 get_tree().quit()
'''
 for entry: Array in [["project.godot",config],["check.tscn",scene],["check.gd",script]]:
  var temp := "user://john_pack_"+str(entry[0])
  var file := FileAccess.open(temp,FileAccess.WRITE)
  file.store_string(entry[1]);file.close()
  assert(pack.add_file("res://"+entry[0],temp)==OK)
  DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
 assert(pack.add_file("res://scripts/core/localization.gd","res://scripts/core/localization.gd")==OK)
 assert(pack.add_file("res://data/story_graphs/episode101.json","res://data/story_graphs/episode101.json")==OK)
 for filename: String in DirAccess.get_files_at("res://locales"):
  if filename.ends_with(".translation"):
   assert(pack.add_file("res://locales/"+filename,"res://locales/"+filename)==OK)
 assert(pack.flush()==OK)
 print("Created CSV-free localization pack: ",args[0])
 quit()
