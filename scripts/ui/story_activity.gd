extends Control
const QTE := preload("res://scripts/core/qte_rules.gd")
# Interactive graph blocks own their state in Quest, so pause/resume and saves
# do not reset the attempt count or grant extra time.
var ui: Control
var node: Dictionary
var state: Dictionary
var meter: Label
var input: LineEdit
var tap: Button
var done := false
var taps: Array[Button] = []
var animation_index := -1
static func draw(owner: Control, data: Dictionary) -> void:
 var activity: Control = load("res://scripts/ui/story_activity.gd").new()
 activity.ui=owner
 activity.node=data
 owner.screen.add_child(activity)
 activity.build()
func build() -> void:
 var path: String="res://assets/flash_ui/"+node.get("art","result_background")+"."+node.get("art_extension","png")
 if ResourceLoader.exists(path):ui._set_backdrop(load(path))
 if not node.get("original_ui",false):
  ui._shade(ui.screen,0.65)
  ui._text(node.get("speaker",""),Rect2(90,40,620,45),26,true)
  ui._text(node.get("text",""),Rect2(90,90,620,145),23)
 if Quest.activity.is_empty():
  Quest.activity={"id":Quest.current_id,"input":"","attempts":int(node.get("attempts",3)),"taps":0,"remaining":float(node.get("seconds",5))}
  Quest.save_game()
 state=Quest.activity
 if node.kind=="activity_dialogue":
  var choices:Array=Quest.available_choices()
  if node.get("original_ui",false):
   ui._text(node.get("speaker",""),Rect2(597,209,155,23),17,false,true)
   var body_size:=23
   while body_size>14 and ui.BODY_FONT.get_multiline_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,465*2,body_size*2).y>137*2:body_size-=1
   ui._text(node.text,Rect2(122,72,465,137),body_size)
   for i:int in choices.size():
    var answer_size:=22
    while answer_size>14 and ui.BODY_FONT.get_multiline_string_size(choices[i].text,HORIZONTAL_ALIGNMENT_LEFT,620*2,answer_size*2).y>55*2:answer_size-=1
    ui._text(choices[i].text,Rect2(110,250+i*66,620,55),answer_size)
    ui._hit(choices[i].text,Rect2(91,244+i*66,657,64),func():finish(i))
  else:
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
  QTE.initialize(state,node)
  Quest.save_game()
  var m:Array=node.get("meter_rect",[150,245,500,40])
  meter=ui._text("",Rect2(m[0],m[1],m[2],m[3]),22,false,true)
  meter.add_theme_color_override("font_shadow_color",Color.BLACK)
  meter.add_theme_constant_override("shadow_offset_x",2)
  meter.add_theme_constant_override("shadow_offset_y",2)
  var targets:Array=node.get("targets",[{"text":"Нажать","rect":node.get("target_rect",[270,315,260,65])}])
  for i:int in targets.size():
   var r:Array=targets[i].rect
   var b:Button=ui._hit(targets[i].get("text","Нажать"),Rect2(r[0],r[1],r[2],r[3]),func():press_target(i))
   taps.append(b)
   if not node.get("original_ui",false):
    b.text=targets[i].get("text","Нажать")
    b.add_theme_font_override("font",ui.BODY_FONT)
    b.add_theme_font_size_override("font_size",44)
    var style:=StyleBoxFlat.new()
    style.bg_color=Color("8b2525");style.set_corner_radius_all(12)
    for key:String in ["normal","hover","pressed"]:b.add_theme_stylebox_override(key,style)
  tap=taps[0]
  if node.get("target_mode","fixed")=="random":move_target()
  update_visuals()
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
func press_target(index:int=0)->void:
 if done or ui.paused:return
 var outcome:=QTE.press(state,node,index)
 if outcome>=0:finish(outcome)
 elif node.get("target_mode","fixed")=="random":move_target()
func update_visuals()->void:
 var frames:Array=node.get("animation_frames",[])
 if not frames.is_empty():
  var frame:=mini(frames.size()-1,int(QTE.elapsed(state,node)*float(node.get("animation_fps",19))))
  if node.get("qte_mode","")=="branch":frame=0
  if frame!=animation_index:
   animation_index=frame
   ui._set_backdrop(load("res://assets/flash_ui/"+str(frames[frame])+".webp"))
 if node.has("target_windows") and is_instance_valid(tap):
  var window:=QTE.window_index(state,node)
  tap.visible=window>=0 and window not in state.hit_windows
  if window>=0:
   var r:Array=node.target_windows[window].rect
   tap.position=Vector2(r[0],r[1])*2;tap.size=Vector2(r[2],r[3])*2
func move_target()->void:
 if is_instance_valid(tap):tap.position=Vector2(randf_range(170,530),randf_range(300,390))*2
func _process(delta:float)->void:
 if done or is_queued_for_deletion() or ui==null or get_parent()!=ui.screen or ui.paused or node.get("kind")!="activity_qte":return
 state.remaining=maxf(0,float(state.remaining)-delta)
 if is_instance_valid(meter):meter.text="%.1f с · Нажатия %d/%d" % [state.remaining,state.taps,int(state.required_taps)]
 update_visuals()
 if state.remaining<=0:finish(QTE.timeout(state,node))
