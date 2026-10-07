extends SceneTree
const DIALOG := preload("res://scenes/shared/PlayerDialog.tscn")
const ANSWER := preload("res://scripts/ui/shared/dialog_answer_button.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures += 1; push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var quest: Node=root.get_node("Quest")
 var dialogs := 0
 for id: String in quest.nodes:
  var node: Dictionary=quest.current(id)
  if node.get("kind","")!="activity_dialogue" or not node.get("original_ui",false):continue
  dialogs += 1
  node=node.duplicate(true)
  node.style="speaker"
  for cover: Rect2 in [Rect2(0,0,1600,960),Rect2(-350,0,2300,960)]:
   var panel: Control=DIALOG.instantiate()
   root.add_child(panel)
   panel.configure(node,node.choices)
   panel.set_cover_rect(cover)
   await process_frame
   check(panel.backdrop.scale==Vector2.ONE and panel.backdrop.position==Vector2.ZERO,"dialogue art stays aligned with native controls: "+id)
   for button: Button in panel.choice_buttons:
    check(button.get_script()==ANSWER,"speaker uses original metal answer button")
    check(button.background.texture!=null,"answer texture loads")
    check(button.caption.horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT,"answer text is left aligned")
    check(Rect2(Vector2.ZERO,button.size).encloses(Rect2(button.caption.position,button.caption.size)),"caption stays inside its own plate")
    var font: Font=button.caption.get_theme_font("font")
    var measured: Vector2=font.get_multiline_string_size(button.caption.text,HORIZONTAL_ALIGNMENT_LEFT,button.caption.size.x,button.caption.get_theme_font_size("font_size"))
    check(measured.y<=button.caption.size.y,"full answer fits: "+id)
    var origin: Vector2=button.caption.position
    button.button_down.emit();button.button_up.emit()
    check(button.caption.position==origin,"press does not displace answer text")
   panel.free()
 check(dialogs>20,"shared component covers dialogue casts across episodes")
 print("Speaker dialogues: %d dialogs, %d checks, %d failures" % [dialogs,checks,failures])
 quit(1 if failures else 0)
