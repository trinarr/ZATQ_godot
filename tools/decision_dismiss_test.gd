extends SceneTree
const TEST_CLOCK := preload("res://tools/flash_test_clock.gd")
const DIALOG := preload("res://scripts/ui/shared/player_dialog.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1600,960)
 var quest: Node=root.get_node("Quest")
 quest.save_path="user://decision_dismiss_test.json";quest.tmp_path="user://decision_dismiss_test.tmp";quest.backup_path="user://decision_dismiss_test.bak";quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui);await process_frame
 var decisions := 0
 var animated := 0
 for id: String in quest.nodes:
  var node: Dictionary=quest.nodes[id]
  if node.get("kind","")!="city_decision":continue
  var origin: String=node.back
  quest.flags={"TakenKey":true,"Auto":0,"BulletsNumber":12,"LinkedFr":true,"TakenKnife":true,"JohnVariant":1,"code":"1234"}
  quest.episode=int(node.get("episode",1));quest.activity={};quest.current_id=origin
  ui.playing=true;ui.paused=false;ui._show_story();await process_frame
  var source_children: Array=ui.world_layer.get_children()
  var screen: Control=ui.screen
  var timeline: Node2D=ui.viewport_canvas.episode_timeline
  var saved_frame := -1
  if is_instance_valid(timeline):
   animated+=1
   saved_frame=mini(10,timeline.frames.size()-1)
   timeline.seek_frame(saved_frame)
   timeline.playing=true
  ui.screen.remove_meta("episode_animation_block")
  ui.world_layer.remove_meta("episode_animation_block")
  var entry := -1
  var choices: Array=quest.available_choices()
  for index: int in choices.size():
   if choices[index].get("next","")==id:entry=index;break
  if entry>=0:ui._choose(entry)
  else:quest._enter(id)
  check(quest.current_id==id,"decision opens immediately without replaying the scene exit: "+id)
  check(ui.decision_scene_origin==origin and is_instance_valid(ui.decision_dialog),"decision retains original scene: "+id)
  check(ui.world_layer.get_children()==source_children,"world controls retained under modal")
  var panel: Control=ui.decision_dialog
  if not is_instance_valid(panel):continue
  if is_instance_valid(timeline):
   check(ui.viewport_canvas.episode_timeline==timeline and timeline.current_frame==saved_frame and not timeline.playing,"popup preserves current animation frame")
  for pressed: bool in [true,false]:
   var event:=InputEventMouseButton.new()
   event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
   panel._dismiss_on_shade(event)
  await process_frame
  check(quest.current_id==origin and ui.screen==screen,"shade dismisses without replacing scene")
  check(ui.decision_dialog==null and ui.world_layer.get_children()==source_children,"only popup removed; original hotspots survive")
  if is_instance_valid(timeline):
   check(ui.viewport_canvas.episode_timeline==timeline and timeline.current_frame==saved_frame,"same timeline/frame after dismissal")
   TEST_CLOCK.step(timeline,2.0)
   check(timeline.current_frame==saved_frame and not timeline.playing,"scene stays static after dismissal")
  # Reopening the decision and pausing must not discard the lower dialog.
  quest._enter(id)
  var reopened: Control=ui.decision_dialog
  check(is_instance_valid(reopened),"decision can reopen")
  if ui._can_pause():
   ui._show_pause();ui._resume()
   check(ui.decision_dialog==reopened and is_instance_valid(reopened),"pause/resume retains decision popup")
  if is_instance_valid(ui.decision_dialog):
   ui.decision_dialog.dismissed.emit()
   if is_instance_valid(timeline):check(not timeline.playing,"resume cannot restart the retained scene")
  quest._enter(id)
  var answer_panel: Control=ui.decision_dialog
  var available: Array=quest.available_choices()
  if is_instance_valid(answer_panel) and not available.is_empty():
   answer_panel.choice_buttons[0].pressed.emit()
   if quest.current_id==id and ui.screen.get_meta("episode_animation_block",false):
    var exit_player: Node2D=ui.viewport_canvas.episode_timeline
    if is_instance_valid(exit_player):exit_player.seek_frame(exit_player.frames.size()-1)
   check(quest.current_id!=id,"answer selection still advances the story: "+id)
  decisions+=1
 check(decisions>20 and animated>10,"coverage across main and web episodes")
 # A real click over the underlying pause tab is consumed by the shade.
 quest.flags={"TakenKey":true,"Auto":0,"BulletsNumber":12,"LinkedFr":true}
 quest.current_id="e2_hospital_5";quest.episode=2;ui.paused=false;ui._show_story()
 var physical_timeline: Node2D=ui.viewport_canvas.episode_timeline
 physical_timeline.seek_frame(mini(10,physical_timeline.frames.size()-1))
 var physical_frame: int=physical_timeline.current_frame
 quest._enter("e2_hospital_5_choice_11")
 await process_frame
 var click_position: Vector2=ui.screen.get_global_transform()*Vector2(20,550)
 for pressed: bool in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT;event.position=click_position;event.pressed=pressed
  Input.parse_input_event(event);await process_frame
 await process_frame
 check(quest.current_id=="e2_hospital_5" and not ui.paused and ui.decision_dialog==null,"physical shade click closes only the dialog")
 check(ui.viewport_canvas.episode_timeline==physical_timeline and physical_timeline.current_frame==physical_frame,"physical shade click preserves the original frame")
 # Direct save/load on a decision has no retained control tree. Its fallback
 # returns to a fully visible static scene rather than playing the intro.
 quest.current_id="e2_hospital_5_choice_11";quest.episode=2;ui.previous_node="";ui._show_story()
 check(ui.decision_scene_origin.is_empty() and is_instance_valid(ui.decision_dialog),"direct decision load uses fallback")
 ui.decision_dialog.dismissed.emit()
 var restored: Node2D=ui.viewport_canvas.episode_timeline
 check(quest.current_id=="e2_hospital_5" and is_instance_valid(restored) and not restored.playing,"direct decision dismissal returns to static origin")
 if is_instance_valid(restored):check(restored.current_frame==restored.frames.size()-1,"fallback shows settled scene")
 ui.free();await process_frame
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("Decision dismissal: %d decisions, %d animated scenes, %d checks; %d failures" % [decisions,animated,checks,failures])
 quit(1 if failures else 0)
