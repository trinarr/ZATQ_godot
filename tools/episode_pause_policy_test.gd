extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:
  failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func enter(ui: Control, quest: Node, id: String) -> void:
 ui.playing=true;ui.paused=false;ui.section="story"
 quest.current_id=id;quest.activity={}
 ui._show_story()
func run() -> void:
 var quest: Node=root.get_node("Quest")
 quest.save_path="user://pause_policy_test.json";quest.tmp_path="user://pause_policy_test.tmp";quest.backup_path="user://pause_policy_test.bak"
 quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await process_frame
 var count:=0
 for episode in [1,2,3]:
  quest.new_game(episode)
  for id: String in quest.nodes:
   var spec: Dictionary=quest.nodes[id]
   if int(spec.get("episode",1))!=episode or spec.get("pause_allowed",true):continue
   count+=1;enter(ui,quest,id)
   check(not ui._can_pause(),id+": pause unavailable on entry")
   check(not is_instance_valid(ui.edge_hit) or not ui.edge_hit.visible,id+": pause hotspot hidden")
   var timeline: Node2D=ui.viewport_canvas.episode_timeline
   var suspended: bool=timeline.suspended if is_instance_valid(timeline) else false
   var running: bool=not ui.cutscene.is_stopped()
   ui._show_pause()
   check(not ui.paused and ui.overlay==null,id+": direct pause cannot open a popup")
   if is_instance_valid(timeline):check(timeline.suspended==suspended,id+": death timeline not suspended")
   check((not ui.cutscene.is_stopped())==running,id+": death timer not stopped")
   var event:=InputEventAction.new();event.action="ui_cancel";event.pressed=true
   ui._unhandled_key_input(event)
   check(not ui.paused and ui.overlay==null,id+": Back/Escape cannot open pause")
   ui._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
   check(not ui.paused,id+": background notification cannot add pause popup")
   if is_instance_valid(timeline) and timeline.playing:
    timeline.seek_frame(timeline.frames.size()-1)
    check(quest.current_id!=id,id+": fatal animation still advances to its outcome")
 check(count==23,"all 23 committed fatal animations audited")
 quest.new_game(2)
 for bullets in [0,1]:
  quest.flags.BulletsNumber=bullets;enter(ui,quest,"e2_roof_8")
  check(ui._can_pause()==(bullets>0),"roof conditional fatality follows current ammunition")
  ui._show_pause();check(ui.paused==(bullets>0),"roof pause button uses conditional policy")
  if ui.paused:ui._resume()
 # Successful/ordinary sequences must remain pausable, including the John
 # branch before its authored End event determines the knife outcome.
 for sample in [[1,"bite_transition"],[2,"e2_roof_4"],[3,"e3_john_13"],[3,"e3_opening_11"]]:
  quest.new_game(sample[0]);enter(ui,quest,sample[1])
  check(ui._can_pause(),sample[1]+": nonfatal/undecided scene remains pausable")
  ui._show_pause();check(ui.paused,sample[1]+": ordinary pause still opens")
  ui._resume()
 # A timed-out branch runs the original fatal MovieClip tail before the result.
 quest.new_game(3);enter(ui,quest,"e3_opening_11")
 var activity: Control
 for child: Node in ui.screen.get_children():
  if child.has_method("press_target"):activity=child;break
 var dying: Node2D=ui.viewport_canvas.episode_timeline
 activity.state.remaining=0.0;activity._process(0.01)
 check(quest.current_id=="e3_opening_11" and dying.playing,"branch timeout starts fatal tail before result")
 check(not ui._can_pause(),"branch timeout disables pause immediately")
 ui._show_pause();check(not ui.paused and not dying.suspended,"branch fatal tail cannot be paused")
 var frame: int=dying.current_frame;activity._process(1.0)
 check(dying.current_frame==frame,"finished activity does not seek over fatal tail")
 dying.seek_frame(dying.frames.size()-1)
 check(quest.current_id=="e3_result_51","fatal tail ends at original result 51")
 # Lock starts at the player's fatal choice, before the previous scene outro.
 quest.new_game(1);enter(ui,quest,"mainstreet_choice")
 var timeline: Node2D=ui.viewport_canvas.episode_timeline
 if is_instance_valid(timeline):timeline.seek_frame(timeline.frames.size()-1)
 ui._choose(0)
 check(not ui._can_pause(),"fatal choice locks pause before the outgoing animation finishes")
 ui._show_pause();check(not ui.paused,"outgoing fatal animation cannot be paused")
 enter(ui,quest,"shop_window")
 check(ui._can_pause(),"transient transition lock does not leak to another scene")
 # Terminal result windows cannot be bypassed through the keyboard pause path.
 enter(ui,quest,"death_1")
 ui._show_pause();check(not ui.paused,"result cannot open pause")
 ui.free();await process_frame
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("Episode pause policy: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
