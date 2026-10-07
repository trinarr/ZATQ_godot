extends Control
const LOC := preload("res://scripts/core/localization.gd")
const DEFAULT_BACKGROUND := preload("res://assets/flash_ui/result_background.png")
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
var keypad: Control
static func draw(owner: Control, data: Dictionary) -> void:
 var activity: Control = load("res://scripts/ui/story_activity.gd").new()
 activity.ui=owner
 activity.node=data
 owner.screen.add_child(activity)
 activity.build()
func build() -> void:
 var path: String="res://assets/flash_ui/"+node.get("art","result_background")+"."+node.get("art_extension","png")
 if node.kind=="activity_dialogue":ui._set_backdrop(null)
 elif not ui._component_backdrop(node.get("art","result_background")) and ResourceLoader.exists(path):ui._set_backdrop(DEFAULT_BACKGROUND if not node.has("art") else load(path))
 if not node.get("original_ui",false) and node.kind!="activity_dialogue":
  ui._shade(ui.screen,0.65)
  ui._narrative_text(node.get("speaker",""),Rect2(90,40,620,45),26,{"font":ui.TITLE_FONT})
  ui._narrative_text(node.get("text",""),Rect2(90,90,620,145),23)
 if Quest.activity.is_empty():
  Quest.activity={"id":Quest.current_id,"input":"","attempts":int(node.get("attempts",3)),"taps":0,"remaining":float(node.get("seconds",5))}
 state=Quest.activity
 if node.kind=="activity_dialogue":
  ui._show_player_dialog({"style":"speaker","text":node.get("text",""),"speaker":node.get("speaker",""),"art":node.get("art","result_background"),"original_ui":node.get("original_ui",false),"shade":not node.get("original_ui",false),"shade_alpha":0.65},Quest.available_choices(),finish)
 elif node.kind=="activity_code" and node.get("keypad",false):
  keypad=preload("res://scripts/ui/shared/code_keypad.gd").new();add_child(keypad)
  keypad.finished.connect(finish);keypad.sound_requested.connect(ui._play_sound);keypad.state_changed.connect(Quest.save_game)
  keypad.indicator_changed.connect(func(frame: int):
   var timeline: Node2D=ui.viewport_canvas.episode_timeline
   if is_instance_valid(timeline):timeline.apply_variable_frame(node.get("indicator_variable","light"),frame))
  keypad.configure(ui,node,state,str(Quest.flags.get(node.get("code_variable","code"),"")),func():return ui.paused or done)
 elif node.kind=="activity_code":
  input=LineEdit.new();input.position=Vector2(200,230)*2;input.size=Vector2(400,45)*2
  input.text=state.get("input","");input.add_theme_font_size_override("font_size",40)
  ui.screen.add_child(input)
  input.text_changed.connect(func(v):state.input=v)
  input.text_submitted.connect(func(_v):check_code())
  ui._brush_button(LOC.text("@loc:ui.story_activity.2"),Rect2(250,340,300,55),check_code)
  meter=ui._text("",Rect2(150,290,500,35),22,false,true)
  meter.text=LOC.text("@loc:ui.story_activity.3")+str(state.attempts)
 elif node.kind=="activity_qte":
  QTE.initialize(state,node)
  var m:Array=node.get("meter_rect",[150,245,500,40])
  meter=ui._text("",Rect2(m[0],m[1],m[2],m[3]),22,false,true)
  var targets:Array=node.get("targets",[{"text":LOC.text("@loc:ui.story_activity.4"),"rect":node.get("target_rect",[270,315,260,65])}])
  for i:int in targets.size():
   var r:Array=targets[i].rect
   var b:Button=ui._hit(targets[i].get("text",LOC.text("@loc:ui.story_activity.5")),Rect2(r[0],r[1],r[2],r[3]),func():press_target(i))
   taps.append(b)
   if not node.get("original_ui",false):
    b.text=targets[i].get("text",LOC.text("@loc:ui.story_activity.6"))
    b.add_theme_font_override("font",ui.BODY_FONT)
    b.add_theme_font_size_override("font_size",44)
    var style:=StyleBoxFlat.new()
    style.bg_color=Color("8b2525");style.set_corner_radius_all(12)
    for key:String in ["normal","hover","pressed"]:b.add_theme_stylebox_override(key,style)
   if node.get("native_prompt",false):b.add_child(preload("res://scripts/ui/qte_prompt.gd").new())
  tap=taps[0]
  if node.get("target_mode","fixed")=="random":move_target()
  update_visuals()
 ui._edge_tab(LOC.text("@loc:ui.story_activity.7"),ui._show_pause)
 Quest.save_game()

func finish(index:int)->void:
 if done:return
 done=true
 var timeline: Node2D=ui.viewport_canvas.episode_timeline
 if index==int(node.get("failure_animation_choice",-1)) and is_instance_valid(timeline) and timeline.spec.intro.size()>1:
  # Flash freezes the branch at frame zero, then plays its fatal tail on timeout.
  # Keep that tail unpausable; the activity clock no longer drives its frames.
  ui._lock_pause()
  for button: Button in taps:button.hide();button.disabled=true
  if is_instance_valid(meter):meter.hide()
  var origin: String=Quest.current_id
  timeline.finished.connect(func():
   if Quest.current_id==origin:Quest.choose(index),CONNECT_ONE_SHOT)
  timeline.play("intro")
  timeline.elapsed=1.0/float(timeline.catalog().fps)
  timeline.seek_frame(1)
  return
 Quest.choose(index)
func check_code()->void:
 if done or ui.paused:return
 var correct:String=str(Quest.flags.get(node.get("code_variable","code"),node.get("code","")))
 if not correct.is_empty() and input.text==correct:finish(0)
 else:
  state.attempts-=1;state.input="";input.clear()
  Quest.save_game()
  if state.attempts<=0:finish(1)
  else:meter.text=LOC.text("@loc:ui.story_activity.8")+str(state.attempts)
func press_target(index:int=0)->void:
 if done or ui.paused:return
 var outcome:=QTE.press(state,node,index)
 Quest.save_game()
 update_visuals()
 if outcome>=0:finish(outcome)
 elif node.get("target_mode","fixed")=="random":move_target()
func update_visuals()->void:
 var timeline: Node2D=ui.viewport_canvas.episode_timeline
 if is_instance_valid(timeline) and timeline.spec.get("qte",false):
  timeline.playing=false
  var authored_frame: int=int(QTE.elapsed(state,node)*float(node.get("animation_fps",19)))
  if node.get("qte_mode","")=="branch":authored_frame=0
  timeline.seek_frame(authored_frame)
  if node.get("qte_mode","")=="ratchet":timeline.apply_variable_frame(node.ratchet_variable,int(state.lock_frame))
 var frames:Array=[] if is_instance_valid(timeline) and timeline.spec.get("qte",false) else node.get("animation_frames",[])
 if not frames.is_empty():
  var frame:=mini(frames.size()-1,int(QTE.elapsed(state,node)*float(node.get("animation_fps",19))))
  if node.get("qte_mode","")=="branch":frame=0
  if frame!=animation_index:
   animation_index=frame
   if not ui._component_backdrop(str(frames[frame])):
    ui._set_backdrop(load("res://assets/flash_ui/"+str(frames[frame])+".png"))
 if not QTE.windows(state,node).is_empty() and is_instance_valid(tap):
  var window:=QTE.window_index(state,node)
  tap.visible=window>=0 and window not in state.hit_windows
  if window>=0:
   var r:Array=QTE.windows(state,node)[window].rect
   tap.position=Vector2(r[0],r[1])*2;tap.size=Vector2(r[2],r[3])*2
   var offsets: Array=node.get("prompt_offsets",[])
   if not offsets.is_empty():
    var phase: float=QTE.elapsed(state,node)-float(QTE.windows(state,node)[window].start)
    var offset: Array=offsets[clampi(int(phase*19),0,offsets.size()-1)]
    tap.position+=Vector2(offset[0],offset[1])*2
func move_target()->void:
 if is_instance_valid(tap):tap.position=Vector2(randf_range(170,530),randf_range(300,390))*2
func _process(delta:float)->void:
 if done or is_queued_for_deletion() or ui==null or get_parent()!=ui.screen or ui.paused or node.get("kind")!="activity_qte":return
 QTE.advance(state,node,delta)
 state.remaining=maxf(0,float(state.remaining)-delta)
 if is_instance_valid(meter):
  if node.get("meter_mode","")=="remaining_taps":
   meter.visible=node.get("qte_mode","")!="ratchet"
   meter.text=str(maxi(0,int(state.required_taps)-int(state.taps)))
  else:meter.text=LOC.text("@loc:ui.story_activity.9") % [state.remaining,state.taps,int(state.required_taps)]
 update_visuals()
 if state.remaining<=0:finish(QTE.timeout(state,node))
