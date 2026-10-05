extends Control
# Interactive graph blocks own their state in Quest, so pause/resume and saves
# do not reset the attempt count or grant extra time.
var ui: Control
var node: Dictionary
var state: Dictionary
var meter: Label
var input: LineEdit
var tap: Button
var done := false
static func draw(owner: Control, data: Dictionary) -> void:
 var activity: Control = load("res://scripts/ui/story_activity.gd").new()
 activity.ui=owner
 activity.node=data
 owner.screen.add_child(activity)
 activity.build()
func build() -> void:
 var path: String="res://assets/flash_ui/"+node.get("art","result_background")+"."+node.get("art_extension","png")
 if ResourceLoader.exists(path):ui._set_backdrop(load(path))
 ui._shade(ui.screen,0.65)
 ui._text(node.get("speaker",""),Rect2(90,40,620,45),26,true)
 ui._text(node.get("text",""),Rect2(90,90,620,145),23)
 if Quest.activity.is_empty():
  Quest.activity={"id":Quest.current_id,"input":"","attempts":int(node.get("attempts",3)),"taps":0,"remaining":float(node.get("seconds",5))}
  Quest.save_game()
 state=Quest.activity
 if node.kind=="activity_dialogue":
  var choices:Array=Quest.available_choices()
  for i:int in choices.size():
   ui._brush_button(choices[i].get("text","Далее"),Rect2(90,245+i*55,620,48),func():finish(i))
 elif node.kind=="activity_code":
  input=LineEdit.new();input.position=Vector2(200,230)*2;input.size=Vector2(400,45)*2
  input.text=state.get("input","");input.add_theme_font_size_override("font_size",40)
  ui.screen.add_child(input)
  input.text_changed.connect(func(v):state.input=v)
  input.text_submitted.connect(func(_v):check_code())
  ui._brush_button("Проверить",Rect2(250,340,300,55),check_code)
  meter=ui._text("",Rect2(150,290,500,35),22,false,true)
  meter.text="Осталось попыток: "+str(state.attempts)
 elif node.kind=="activity_qte":
  meter=ui._text("",Rect2(150,245,500,40),22,false,true)
  tap=ui._hit("Нажать",Rect2(270,315,260,65),press_target)
  tap.text="Нажать"
  tap.add_theme_font_override("font",ui.BODY_FONT)
  tap.add_theme_font_size_override("font_size",44)
  var style:=StyleBoxFlat.new()
  style.bg_color=Color("8b2525")
  style.set_corner_radius_all(12)
  for key:String in ["normal","hover","pressed"]:tap.add_theme_stylebox_override(key,style)
  if node.get("target_mode","fixed")=="random":move_target()
 ui._edge_tab("Пауза",ui._show_pause)
func finish(index:int)->void:
 if done:return
 done=true
 Quest.choose(index)
func check_code()->void:
 if done or ui.paused:return
 var correct:String=str(Quest.flags.get(node.get("code_variable","code"),node.get("code","")))
 if not correct.is_empty() and input.text==correct:finish(0)
 else:
  state.attempts-=1;state.input="";input.clear()
  Quest.save_game()
  if state.attempts<=0:finish(1)
  else:meter.text="Неверный код. Осталось попыток: "+str(state.attempts)
func press_target()->void:
 if done or ui.paused:return
 state.taps+=1
 if state.taps>=int(node.get("taps",10)):finish(0)
 elif node.get("target_mode","fixed")=="random":move_target()
func move_target()->void:
 if is_instance_valid(tap):tap.position=Vector2(randf_range(170,530),randf_range(300,390))*2
func _process(delta:float)->void:
 if done or is_queued_for_deletion() or ui==null or get_parent()!=ui.screen or ui.paused or node.get("kind")!="activity_qte":return
 state.remaining=maxf(0,float(state.remaining)-delta)
 if is_instance_valid(meter):meter.text="%.1f с · Нажатия %d/%d" % [state.remaining,state.taps,int(node.get("taps",10))]
 if state.remaining<=0:finish(1)
