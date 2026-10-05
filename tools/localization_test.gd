extends SceneTree
const LOC := preload("res://scripts/core/localization.gd")
const MODEL := preload("res://addons/story_graph/graph.gd")
var failures := 0
var checks := 0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var original_locale:=TranslationServer.get_locale()
 TranslationServer.set_locale("ru")
 LOC.prepare(true)
 check(LOC.text("@loc:ui.main.5")=="Справка","UI source loaded")
 for table_name:String in LOC.BUILTIN_TABLES:
  var native:Dictionary=LOC.imported_table("res://locales/"+table_name+".csv")
  check(not native.rows.is_empty(),"native imported table: "+table_name)
  for key:String in native.rows:
   if native.rows[key].has("ru"):
    check(LOC.source("@loc:"+key)==native.rows[key].ru,"native fallback resolves source: "+key)
 var quest:Node=root.get_node("Quest")
 quest.save_path="user://locales_test.json";quest.tmp_path="user://locales_test.tmp";quest.backup_path="user://locales_test.bak";quest.sound_enabled=false
 quest.new_game(3)
 var source:Dictionary=quest.current()
 var graph:=MODEL.load_graph("res://data/story_graphs/episode3.json")
 var key:String=graph.nodes[graph.start].data.text.trim_prefix("@loc:")
 var english:=Translation.new();english.locale="en"
 english.add_message(key,"English episode text")
 english.add_message("ui.art.adaptive_menu.3","Episodes")
 english.add_message("ui.art.adaptive_menu_off.3","Episodes")
 TranslationServer.add_translation(english)
 TranslationServer.set_locale("en")
 check(quest.current().text=="English episode text","story resolves active language")
 check(quest.current_id==graph.start,"language does not change route")
 check(LOC.text("@loc:ui.main.5")=="Справка","empty English cell falls back to Russian")
 check(LOC.resolve_tree(graph,true).nodes[graph.start].data.text==source.text,"editor always resolves source text")
 var ui:Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await process_frame
 var found:=false
 for image:Node in ui.screen.get_children():
  for label:Node in image.get_children():
   if label is Label and label.text=="Episodes":found=true
 check(found,"image caption uses native translated label")
 ui._start_episode(3)
 quest.activity={"remaining":1.25,"taps":2,"required_taps":4}
 quest._enter("e3_opening_8")
 # Pause locale refresh must preserve the activity state and route.
 ui._show_pause()
 var before:Dictionary=quest.activity.duplicate(true)
 TranslationServer.set_locale("ru")
 await process_frame
 await process_frame
 check(ui.paused and quest.current_id=="e3_opening_8","locale redraw preserves pause and scene")
 check(quest.activity==before,"locale redraw preserves QTE state")
 ui.queue_free();await process_frame
 TranslationServer.remove_translation(english)
 # CSV quoting/newlines and extra language columns survive editor extraction.
 var table:Dictionary={"headers":["key","ru","en","de"],"rows":{"episode99.nodes.scene.data.text":{"ru":"старый","en":"English","de":"Deutsch"}}}
 var doc:Dictionary={"episode":99,"nodes":{"scene":{"data":{"text":"Новый, \"текст\"\nстрока 2","speaker":"Имя"}}}}
 var extracted:Dictionary=LOC.extract(doc,"episode99",table)
 check(extracted.nodes.scene.data.text=="@loc:episode99.nodes.scene.data.text","editor stores key in graph")
 check(table.rows["episode99.nodes.scene.data.text"].en=="English" and table.rows["episode99.nodes.scene.data.text"].de=="Deutsch","editor preserves translations")
 var temp:="user://locales_roundtrip.csv"
 check(LOC.write_table(temp,table)==OK,"CSV saved atomically")
 check(LOC.read_table(temp)==table,"CSV multiline/quotes roundtrip")
 DirAccess.remove_absolute(temp)
 var published:="user://locales_published.json"
 var csv_path:="res://locales/episode99.csv"
 check(not FileAccess.file_exists(csv_path),"test namespace is unused")
 check(LOC.publish(published,doc)==OK,"publish graph and source table")
 check(MODEL.load_graph(published).nodes.scene.data.text==extracted.nodes.scene.data.text,"published graph contains key")
 var authored:=LOC.read_table(csv_path)
 authored.rows["episode99.nodes.scene.data.text"].en="Authored translation"
 check(LOC.write_table(csv_path,authored)==OK,"author translation")
 doc.nodes.scene.data.text="Отредактировано"
 check(LOC.publish(published,doc)==OK,"publish updated Russian source")
 check(LOC.read_table(csv_path).rows["episode99.nodes.scene.data.text"].en=="Authored translation","publish preserves authored translation")
 var csv_before:=FileAccess.get_file_as_string(csv_path)
 check(LOC.publish("user://absent_locales_directory/graph.json",doc)!=OK,"invalid graph path rejects save")
 check(FileAccess.get_file_as_string(csv_path)==csv_before,"failed graph save rolls back CSV")
 for path:String in [published,published+".bak",csv_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 LOC.prepare(true)
 for path:String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 TranslationServer.set_locale(original_locale)
 print("PASS: %d localization checks" % checks if failures==0 else "FAIL: %d localization checks" % failures)
 quit(1 if failures else 0)
