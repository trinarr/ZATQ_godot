extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures += 1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var quest: Node=root.get_node("Quest")
 quest.save_path="user://john_episode_test.json"
 quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate()
 root.add_child(ui)
 await process_frame
 ui._start_episode(101)
 check(quest.episode_starts.get(101)=="john1_1","web prologue starts independently")
 check(quest.episode_starts.get(102)=="john2_1","web escape starts independently")
 var scenes := 0
 var unfinished := 0
 var disabled := 0
 for id: String in quest.nodes:
  var data: Dictionary=quest.current(id)
  if int(data.get("episode",0)) not in [101,102]:continue
  scenes += 1
  quest._enter(id)
  await process_frame
  var choices: Array=quest.available_choices()
  for index: int in choices.size():
   var choice: Dictionary=choices[index]
   check(quest.nodes.has(choice.next),"web choice target exists: "+id)
   if choice.get("unfinished",false):
    unfinished += 1
    var before: Dictionary=quest.stats_for(quest.episode).duplicate(true)
    quest.choose(index)
    check(quest.current_id==choice.next,"unfinished choice returns to its original scene")
    check(quest.stats_for(quest.episode)==before,"unfinished choice is never a win/death")
    quest._enter(id)
   if choice.get("disabled",false):
    disabled += 1
    quest.choose(index)
    check(quest.current_id==id,"original disabled dialogue response cannot route")
  if data.kind=="activity_dialogue":
   var panel: Control
   for child: Node in ui.screen.get_children():
    if child.get_script()==preload("res://scripts/ui/shared/player_dialog.gd"):panel=child
   check(panel.choice_buttons.size()==choices.size(),"all original answer slots remain visible")
   for i: int in choices.size():check(panel.choice_buttons[i].disabled==choices[i].get("disabled",false),"original response enable state")
  if data.kind=="city_pickup":
   var item_parts: Array=ui.episode_components.get(data.art,[])
   check(item_parts.any(func(part: Dictionary): return part.get("source","").begins_with("Weapons/")),"each web pickup contains its actual item sprite")
  check(ui.screen!=null,"each web scene draws")
 check(scenes==38,"all 38 authored story/modal states are imported")
 check(unfinished==8,"eight original unfinished choice branches remain unchanged")
 check(disabled==3,"three original disabled dialogue answers stay disabled")
 quest._enter("john2_6")
 await process_frame
 var timeline: Node2D=ui.viewport_canvas.episode_timeline
 check(ui.world_layer.get_meta("episode_animation_block",false),"wait for original End before accepting clicks")
 timeline.seek_frame(6)
 check(not ui.world_layer.get_meta("episode_animation_block",false),"background loop does not block clicks after original End")
 check(timeline.playing,"background blinking continues after input becomes available")
 check(quest.ending_count(101)==0,"prologue does not invent an ending")
 check(quest.ending_count(102)==1,"escape has exactly the original surviving ending")
 quest.new_game(102)
 for id: String in ["john2_3","john2_pickup_laser","john2_4","john2_4_choice","john2_5","john2_6","john2_7","john2_7_choice","john2_8","john2_8_departure","john2_9","john2_10","john2_10_choice","john2_11","john2_11_choice","john2_12","john2_13","john2_14","john2_15","john2_16","john2_result"]:
  check(quest.nodes.has(id),"implemented escape path: "+id)
 quest.new_game(102)
 for index: int in [0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0]:
  if quest.current_id=="john2_result":break
  quest.choose(index)
 check(quest.current_id=="john2_result","authored escape choices reach the original ending")
 check(quest.stats_for(102).wins>=1,"original result is survival")
 check(quest.current().text.contains("Джон Доннатон"),"ending text belongs to web story")
 print("John web episode: %d scenes, %d checks, %d failures" % [scenes,checks,failures])
 ui.free()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(quest.save_path))
 DirAccess.remove_absolute(ProjectSettings.globalize_path(quest.save_path+".bak"))
 quit(1 if failures else 0)
