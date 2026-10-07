extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 TranslationServer.set_locale("ru")
 var quest: Node=root.get_node("Quest")
 quest.save_path="user://mainstreet_text_test.json";quest.tmp_path="user://mainstreet_text_test.tmp";quest.backup_path="user://mainstreet_text_test.bak";quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await process_frame
 ui.playing=true;quest.new_game(1)
 for extent: Vector2i in [Vector2i(1600,960),Vector2i(2048,920),Vector2i(2400,1080)]:
  root.size=extent;ui.viewport_canvas.safe_override=Rect2(108,0,extent.x-108,extent.y)
  await process_frame
  ui._fit_stage()
  for id: String in ["mainstreet_choice","mainstreet_boundary"]:
   quest.current_id=id;ui.playing=true;ui._show_story()
   if is_instance_valid(ui.viewport_canvas.episode_timeline):ui.viewport_canvas.episode_timeline.seek_frame(ui.viewport_canvas.episode_timeline.frames.size()-1)
   await process_frame
   var choices: Array=quest.available_choices()
   check(choices.size()==4,"four street choices")
   for choice: Dictionary in choices:
    var button: Button=ui.world_layer.find_child(ui.LOC.text(choice.text),true,false)
    check(button!=null,"choice button exists")
    var caption: Label=null
    for child: Node in button.get_children():
     if child is Label:caption=child;break
    check(caption!=null and caption.text==ui.LOC.text(choice.text),"localized caption inside button")
    check(caption.mouse_filter==Control.MOUSE_FILTER_IGNORE,"caption passes input to button")
    check(button.get_global_rect().encloses(caption.get_global_rect()),"caption fits its button")
   var intro: Label=null
   for child: Node in ui.screen.get_children():
    if child is Label and child.text==ui.LOC.text("@loc:episode1.ui.mainstreet_intro"):intro=child;break
   check(intro!=null and intro.is_visible_in_tree(),"street introduction visible")
   check(ui.viewport_canvas.safe_layer.get_global_rect().encloses(intro.get_global_rect()),"intro stays inside safe viewport")
   check(intro.get_theme_font("font")==ui.BODY_FONT,"intro uses shared story font")
   check(intro.get_visible_line_count()==intro.get_line_count(),"all description lines fit")
   var shade: ColorRect=null
   for child: Node in ui.screen.get_children():
    if child is ColorRect:shade=child;break
   check(shade!=null and shade.color==Color.BLACK,"intro uses shared black description band")
   check(intro.get_global_rect().end.y<ui.world_layer.find_child(ui.LOC.text(choices[0].text),true,false).get_global_rect().position.y,"description stays above choices")
 ui.free()
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("Mainstreet text: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
