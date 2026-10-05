# Run this external script against an exported PCK with locales/*.csv excluded,
# from a directory outside the project. Checks native translation resources.
extends SceneTree
const LOC=preload("res://scripts/core/localization.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 assert(not FileAccess.file_exists("res://locales/ui.csv"),"Test must not rely on raw CSV")
 TranslationServer.set_locale("ru")
 LOC.prepare(true)
 for name:String in LOC.BUILTIN_TABLES:assert(not LOC.tables[name].rows.is_empty(),name)
 assert(LOC.text("@loc:ui.art.adaptive_menu.3")=="Эпизоды")
 var ui:Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await process_frame
 check_labels(ui)
 ui._show_selector("episodes");await process_frame;check_labels(ui)
 ui._show_help();await process_frame;check_labels(ui)
 var quest:Node=root.get_node("Quest")
 for episode:int in [1,2,3]:
  assert(quest.episode_starts.has(episode),"Exported episode is registered")
  ui._start_episode(episode);await process_frame;check_labels(ui)
  assert(not quest.current().is_empty(),"Exported episode starts")
 print("PASS: exported UI and Episodes I-III resolve translations without raw CSV or project files")
 ui.queue_free();await process_frame
 quit(0)
func check_labels(node:Node)->void:
 if node is Label:assert(not node.text.contains("@loc:") and not node.text.begins_with("ui.") and not node.text.begins_with("episode"),node.text)
 for child:Node in node.get_children():check_labels(child)
