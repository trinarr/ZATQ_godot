extends SceneTree
const DIALOG := preload("res://scenes/shared/PlayerDialog.tscn")
const PAUSE := preload("res://scenes/shared/PauseMenu.tscn")
const ITEM := preload("res://scenes/shared/ItemPopup.tscn")
const TEXT := preload("res://scripts/ui/shared/torn_text_button.gd")
const ICON := preload("res://scripts/ui/shared/torn_icon_button.gd")
const METAL := preload("res://scripts/ui/shared/dialog_answer_button.gd")
var checks := 0
var failures := 0
var underlying_presses := 0
var choices := 0
func check(value: bool, message: String) -> void:
 checks+=1
 if not value: failures+=1;push_error(message)
func _initialize() -> void: call_deferred("run")
func click(point: Vector2) -> void:
 var motion := InputEventMouseMotion.new();motion.position=point;motion.global_position=point
 root.push_input(motion,true)
 for down: bool in [true,false]:
  var event := InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;event.global_position=point
  root.push_input(event,true)
  await process_frame
func touch(point: Vector2) -> void:
 for down: bool in [true,false]:
  var event := InputEventScreenTouch.new()
  event.index=0;event.position=point;event.pressed=down
  Input.parse_input_event(event)
  await process_frame
func run() -> void:
 root.size=Vector2i(1600,960)
 Input.emulate_mouse_from_touch=true
 var host := Control.new();host.size=Vector2(1600,960);host.mouse_filter=Control.MOUSE_FILTER_IGNORE
 root.add_child(host)
 var underneath := Button.new();underneath.size=Vector2(1600,960)
 underneath.pressed.connect(func(): underlying_presses+=1)
 host.add_child(underneath)
 await process_frame
 await click(Vector2(20,20))
 check(underlying_presses==1,"input test reaches underlying control without a modal")
 await touch(Vector2(20,20))
 check(underlying_presses==2,"touch test reaches underlying control without a modal")
 for scene: PackedScene in [DIALOG,PAUSE,ITEM]:
  var popup: Control = scene.instantiate()
  host.add_child(popup)
  if scene==DIALOG: popup.configure({"text":"Question"},[{"text":"Answer"}])
  elif scene==PAUSE: popup.configure(false)
  else: popup.configure("item_keys","Keys")
  popup.set_cover_rect(Rect2(-200,-80,2000,1120))
  # Controls created after the popup must still stay behind it.
  var late := Button.new();late.size=Vector2(1600,960)
  late.pressed.connect(func(): underlying_presses+=1)
  host.add_child(late)
  await process_frame
  check(popup.get_index()==host.get_child_count()-1,"modal stays above later controls")
  check(popup.dimmer.mouse_filter==Control.MOUSE_FILTER_STOP and not popup.dimmer.mouse_force_pass_scroll_events,"shade blocks click and scroll propagation")
  var before := underlying_presses
  await click(Vector2(20,20));await click(Vector2(1500,900))
  check(underlying_presses==before,"shade consumes input over underlying buttons")
  await touch(Vector2(20,20))
  check(underlying_presses==before,"touch does not trigger underlying controls")
  if scene==DIALOG:
   popup.choice_selected.connect(func(_i: int): choices+=1)
   var answer: Button = popup.choice_buttons[0]
   var local: Rect2 = answer.caption.get_rect()
   await click(answer.get_global_rect().get_center())
   check(choices==1,"modal answer still receives real GUI clicks")
   check(answer.caption.get_parent()==answer,"answer caption belongs to its metal button")
   check(answer.caption.get_rect()==local,"caption does not shift after pressing")
   check(popup.answer_slots.size()==4 and popup.answer_slots[3].disabled,"unused original metal slots are disabled")
   check(popup.answer_slots[3].unavailable_mark!=null,"disabled slots show the original unavailable icon")
   # Stacked popup returns input to the previous modal, never the game.
   var nested: Control = DIALOG.instantiate();host.add_child(nested)
   nested.configure({"style":"confirmation","text":"Confirm"},[{"text":"OK"}])
   await click(answer.get_global_rect().get_center())
   check(choices==1,"top modal blocks the older modal's answers")
   nested.free()
   await click(answer.get_global_rect().get_center())
   check(choices==2,"closing the top modal restores older modal input")
  popup.free();late.free()
 var no_shade: Control = DIALOG.instantiate();host.add_child(no_shade)
 no_shade.configure({"style":"speaker","shade":false,"text":"Body","speaker":"John"},[{"text":"Next"}])
 var before := underlying_presses
 await click(Vector2(20,20))
 check(underlying_presses==before and no_shade.dimmer.color.a==0,"unshaded modal still blocks input")
 no_shade.free();host.free()
 var quest: Node=root.get_node("Quest")
 quest.sound_enabled=false;quest.save_path="user://modal_buttons_test.json";quest.tmp_path="user://modal_buttons_test.tmp";quest.backup_path="user://modal_buttons_test.bak"
 var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await process_frame
 for name: String in ["Эпизоды","Тесты","Справка","Выход"]:
  check(ui.screen.get_node(name).get_script()==TEXT,"main menu uses text component: "+name)
 check(ui.screen.get_node("Звук").get_script()==ICON,"sound uses icon component")
 check(ui.screen.get_node("Звук").icons.size()==1,"sound icon belongs to its button")
 ui._show_help()
 var help_close: Button=ui.screen.get_node("Закрыть справку")
 check(help_close.get_script()==ICON and help_close.icons.size()==1,"help icon sheet is owned by square buttons")
 check(help_close.icons[0].texture is AtlasTexture,"help reuses the original icon sheet without duplicated textures")
 for frame: int in 12:
  ui._reset_screen();var art: Control=ui._art("selector_%d" % frame)
  ui._hit("Start",Rect2(310,351,205,48),func():pass)
  var close: Button=ui._hit("Close",Rect2(635,348,49,49),func():pass)
  check(ui.screen.get_node("Start").get_script()==TEXT,"selector uses text component")
  check(close.get_script()==ICON and close.icons.size()==1,"selector uses icon component")
 for count: int in [2,3,4]:
  var popup: Control=DIALOG.instantiate();root.add_child(popup)
  var options: Array=[]
  for i: int in count: options.append({"text":"Длинный текст ответа для проверки его расположения внутри кнопки " + str(i)})
  popup.configure({"text":"Question"},options)
  for button: Button in popup.choice_buttons:
   check(button.get_script()==METAL and button.size==Vector2(694,128),"metal answer preserves original dimensions")
   var p: Vector2=button.caption.position
   button.button_down.emit();button.button_up.emit()
   check(button.caption.position==p,"hover/press does not move caption")
  check(popup.choice_buttons.size()==count,"active answers preserve choice indices")
  popup.free()
 var speaker: Control=DIALOG.instantiate();root.add_child(speaker)
 speaker.configure({"style":"speaker","art":"e3_dialogue_john","original_ui":true,"shade":false,"text":"Body","speaker":"John"},[{"text":"Answer"}])
 var reply: Button=speaker.choice_buttons[0]
 check(reply.get_script()==TEXT and is_equal_approx(reply.brush_color.r,reply.brush_color.g),"speaker preserves original gray torn answer background")
 var reply_position: Vector2=reply.caption.global_position-reply.global_position
 speaker.set_cover_rect(Rect2(-400,-100,2400,1160))
 check((reply.caption.global_position-reply.global_position).is_equal_approx(reply_position),"speaker caption stays inside its own button on resize")
 speaker.free()
 var text_button: Button=load("res://scenes/shared/TornTextButton.tscn").instantiate()
 root.add_child(text_button)
 text_button.set_caption("Very long localized caption for a standalone reusable component")
 text_button.size=Vector2(280,100)
 check(text_button.caption.get_parent()==text_button and text_button.caption.get_rect().end.x<=text_button.size.x,"standalone text component fits caption on resize")
 var icon_button: Button=load("res://scenes/shared/TornIconButton.tscn").instantiate();root.add_child(icon_button)
 icon_button.icon_texture=load("res://assets/flash_ui/components/stat_tick.png")
 icon_button.size=Vector2(100,100)
 check(icon_button.icons.size()==1 and icon_button.icons[0].position==Vector2(32,32),"standalone icon component keeps icon centered on resize")
 check(text_button.background.material!=icon_button.background.material,"component instances have independent shader states")
 text_button.free();icon_button.free()
 ui.queue_free();await process_frame
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("PASS: %d modal input and shared button checks; failures %d" % [checks,failures])
 quit(1 if failures else 0)
