extends SceneTree
const COMPONENTS := preload("res://scripts/ui/flash_components.gd")
const PROMPT := preload("res://scripts/ui/qte_prompt.gd")
const LOC := preload("res://scripts/core/localization.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var old_locale := TranslationServer.get_locale()
 var parts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/episode3_components.json"))
 var count := 0
 for frame: int in 41:
  var key := "e3_john_23_anim_%d" % frame
  var holder := Control.new()
  root.add_child(holder)
  COMPONENTS.draw(holder,parts[key])
  var prompts := 0
  for child: Node in holder.get_children():
   if child.get_script()!=PROMPT: continue
   prompts += 1
   count += 1
   var record: Dictionary
   for part: Dictionary in parts[key]:
    if part.type=="qte_prompt":record=part
   var m: Array = record.transform
   var expected := Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5])*2)
   check(child.get_transform().is_equal_approx(expected),"original transform: "+key)
   check(child.mouse_filter==Control.MOUSE_FILTER_IGNORE and child.caption.mouse_filter==Control.MOUSE_FILTER_IGNORE,"prompt leaves input to hotspot")
   for language: String in ["ru","en"]:
    TranslationServer.set_locale(language)
    child.refresh_text()
    check(child.caption.text==("ЖМИ!" if language=="ru" else "PRESS!"),"translated caption: "+language)
    var font_size: int = child.caption.get_theme_font_size("font_size")
    check(PROMPT.FONT.get_string_size(child.caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=child.caption.size.x,"caption fits: "+language)
  check(prompts==(1 if frame>=2 and frame<=37 else 0),"original visibility: "+key)
  holder.queue_free()
  await process_frame
 check(count==36,"all 36 baked frames replaced")
 TranslationServer.set_locale(old_locale)
 var quest: Node = root.get_node("Quest")
 quest.save_path="user://qte_prompt_test.json";quest.tmp_path="user://qte_prompt_test.tmp";quest.backup_path="user://qte_prompt_test.bak"
 quest.sound_enabled=false
 var ui: Control = load("res://scenes/Main.tscn").instantiate()
 root.add_child(ui)
 quest.new_game(3);quest._enter("e3_john_23")
 ui.playing=true;ui._show_story();ui.paused=true
 var controller: Control
 for child: Node in ui.screen.get_children():
  if child.get_script()==load("res://scripts/ui/story_activity.gd"):controller=child
 check(controller!=null,"live QTE controller")
 for index: int in 4:
  var window: Dictionary = quest.current().target_windows[index]
  controller.state.remaining=float(controller.node.seconds)-(float(window.start)+0.01)
  controller.update_visuals()
  var r: Array = window.rect
  check(controller.tap.position==Vector2(r[0],r[1])*2 and controller.tap.size==Vector2(r[2],r[3])*2,"original target bounds")
  var before: int = controller.state.taps
  controller.tap.pressed.emit()
  check(controller.state.taps==before,"pause blocks QTE input")
  ui.paused=false
  controller.tap.pressed.emit()
  ui.paused=true
  check(controller.state.taps==before+1,"target accepts one press")
 controller.update_visuals()
 check(not controller.tap.visible,"completed window hides hotspot")
 ui.queue_free();await process_frame
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("PASS: %d native QTE prompt checks; failures %d" % [checks,failures])
 quit(1 if failures else 0)
