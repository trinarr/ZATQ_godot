extends SceneTree
const BRUSH=preload("res://scripts/ui/torn_brush.gd")
const LOC=preload("res://scripts/core/localization.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func captions(node:Node)->void:
 if node is Label and node.has_meta("button_caption"):
  check(node.autowrap_mode==TextServer.AUTOWRAP_OFF and node.get_line_count()==1,"single-line caption: "+node.text)
  var font:Font=node.get_theme_font("font")
  var size:int=node.get_theme_font_size("font_size")
  check(font.get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=node.size.x+0.1,"caption fits width: "+node.text)
  check(font.get_height(size)<=node.size.y+0.1,"caption fits height: "+node.text)
 if node.get_script()==BRUSH:
  check(node.material is ShaderMaterial,"shader material")
  check(node.material.get_shader_parameter("button_size")==node.size,"shader knows physical size")
 for child:Node in node.get_children():captions(child)
func settle()->void:
 await process_frame
 await process_frame
func run()->void:
 TranslationServer.set_locale("ru")
 var quest:Node=root.get_node("Quest")
 quest.sound_enabled=false;quest.save_path="user://shader_test.json";quest.tmp_path="user://shader_test.tmp";quest.backup_path="user://shader_test.bak"
 var ui:Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await settle();captions(ui)
 for kind:String in ["episodes","tests"]:
  ui._show_selector(kind)
  for i:int in ui._selector_items().size():
   ui.selector_index=i;ui._draw_selector();await settle();captions(ui)
 ui._show_help();await settle();captions(ui)
 ui._start_episode(1);ui._show_pause();await settle();captions(ui)
 ui._message("Title","Body",func():pass);await settle();captions(ui)
 ui._close_overlay();ui.paused=false
 for artwork:String in ["decision","city_decision_3","ep2_decision_4","ep2_item_glock","ep2_item_mark23"]:
  var art:Control=ui._art(artwork)
  await settle();captions(art);art.queue_free()
 # Exercise every button string in all three episodes using its actual content width.
 for id:String in quest.nodes:
  var n:Dictionary=LOC.resolve_tree(quest.nodes[id],true)
  if n.get("kind","")=="city_decision":
   for choice:Dictionary in n.choices:
    var label:Label=ui._button_text(choice.text,Rect2(66,66,337,50),22)
    await settle();captions(label);label.queue_free()
  elif n.get("kind","")=="activity_dialogue":
   for choice:Dictionary in n.choices:
    var label:Label=ui._button_text(choice.text,Rect2(110,250,620,55),22)
    await settle();captions(label);label.queue_free()
 quest.new_game(3);quest._enter("e3_dialogue_0");await settle();captions(ui)
 quest._enter("e3_pickup_knife");await settle();captions(ui)
 ui._message("Title","Body",func():pass,"Очень длинная проверочная подпись для кнопки подтверждения операции",true)
 await settle();captions(ui)
 # Shrinking respects translated strings rather than the length of translation keys.
 var english:=Translation.new();english.locale="en";english.add_message("ui.art.adaptive_selector_0.0","Start the selected episode")
 TranslationServer.add_translation(english);TranslationServer.set_locale("en")
 ui._show_selector("episodes");await settle();captions(ui)
 TranslationServer.remove_translation(english)
 ui.queue_free();await settle()
 for p:String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(p):DirAccess.remove_absolute(p)
 print("PASS: %d shader/button caption checks" % checks if failures==0 else "FAIL: %d" % failures)
 quit(1 if failures else 0)
