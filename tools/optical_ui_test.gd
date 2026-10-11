extends SceneTree
const OPTICAL=preload("res://scripts/ui/shared/optical_text_layout.gd")
const BUTTON=preload("res://scripts/ui/shared/torn_text_button.gd")
const ANSWER=preload("res://scripts/ui/shared/dialog_answer_button.gd")
var checks:=0
var failures:=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func centered(label: Label) -> void:
 check(label.has_meta("optical_area"),"optical layout enabled: "+label.text)
 if not label.has_meta("optical_area"):return
 var area: Rect2=label.get_meta("optical_area")
 if label.get_line_count()==1:
  var font:=label.get_theme_font("font")
  var px:=label.get_theme_font_size("font_size")
  var text:=label.text.to_upper() if label.uppercase else label.text
  var bounds:=OPTICAL.ink(font,px,text)
  var middle:=label.position.y+font.get_ascent(px)+(bounds.x+bounds.y)*0.5
  check(absf(middle-area.get_center().y)<0.02,"visible text centered: "+label.text)
 check(label.shadow_pass.position==label.shadow_offset,"shadow follows foreground")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await process_frame
 var q=root.get_node("Quest")
 q.sound_enabled=false
 for locale: String in ["ru","en"]:
  TranslationServer.set_locale(locale)
  ui._show_selector("episodes")
  await process_frame;await process_frame
  var counters:=0
  for child: Node in ui.screen.get_children():
   if child is Label and child.text.begins_with(": "):
    centered(child);counters+=1
  check(counters==2,"both selector counters checked")
  for value: String in ["НАЧАТЬ","Продолжить","Settings"]:
   var button:=BUTTON.new();root.add_child(button)
   button.size=Vector2(500,100);button.set_caption(value)
   await process_frame;await process_frame
   centered(button.caption)
   var position:=button.caption.position
   button._layout_content();button._layout_content()
   await process_frame
   check(button.caption.position.is_equal_approx(position),"repeated layout does not drift")
   button.size=Vector2(700,130)
   await process_frame;await process_frame
   centered(button.caption);button.free()
  var answer:=ANSWER.new();root.add_child(answer)
  answer.configure("Это длинный ответ, который должен занимать несколько строк без потери текста.\nЭто вторая строка ответа.",true,24,true)
  await process_frame;await process_frame
  check(answer.caption.has_meta("optical_area"),"multiline answer uses optical layout")
  check(answer.caption.get_line_count()>1,"answer genuinely wraps")
  check(answer.caption.get_minimum_size().y<=answer.caption.size.y+0.01,"all answer lines fit")
  answer.free()
 ui.free()
 await process_frame
 print("Optical UI: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
