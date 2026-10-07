extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures += 1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(2048,920)
 var quest: Node=root.get_node("Quest")
 quest.save_path="user://john_episode_test.json"
 quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate()
 root.add_child(ui)
 await process_frame
 var entries: Array=ui._selector_items()
 check(entries.filter(func(e: Dictionary):return int(e.get("episode",0))==101).size()==1,"exactly one John entry")
 var john: Dictionary=entries[3]
 check(john.episode==101 and john.available and int(john.frame)==5,"original John selector slot launches the unified story")
 check(john.art=="selector_5","original gas-mask preview is reused")
 check(quest.LOC.text(john.description).begins_with("Монстр? Палач? Психопат?"),"original John description is preserved")
 check(not ui.episode_components.has("john_selector_101"),"duplicate John selector components are removed")
 ui.selector_index=3
 ui._draw_selector()
 var had_progress: bool=quest.has_progress
 quest.has_progress=false
 ui._selector_start()
 check(quest.episode==101 and quest.current_id=="john1_1","original Start button launches the web story")
 quest.has_progress=had_progress
 ui._start_episode(101)
 check(quest.episode_starts.get(101)=="john1_1","unified web episode starts with the prologue")
 check(not quest.episode_starts.has(102),"second source part is not a separate menu entry")
 check(quest.LOC.text(quest.episode_metadata[101].title)=="ВЕБ-ЭПИЗОД 1. ДЖОН","requested selector title")
 var scenes := 0
 var unfinished := 0
 var disabled := 0
 for id: String in quest.nodes:
  var data: Dictionary=quest.current(id)
  if int(data.get("episode",0)) !=101:continue
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
  for block: Dictionary in data.get("blocks",[]):
   check(not block.text.begins_with("episode101."),"narrative is translated: "+id)
  check(ui.screen!=null,"each web scene draws")
 check(scenes==38,"all 38 authored story/modal states are imported")
 check(unfinished==8,"eight original unfinished choice branches remain unchanged")
 check(disabled==3,"three original disabled dialogue answers stay disabled")
 for id: String in ["john2_1","john2_9"]:
  quest._enter(id);await process_frame
  var masked: Node2D=ui.viewport_canvas.episode_timeline
  check(masked.spec.parts.values().all(func(p: Dictionary):return p.get("source","")!="Mov/Symbol 10183"),"Flash mask is not painted white: "+id)
  check(masked.spec.caption_mask.intro.size()==10,"all original caption-mask keys are preserved")
  check(not masked.captions.is_empty(),"masked native caption is bound")
  var label: Label=masked.captions[0].label
  for frame: int in [0,4,9]:
   masked.seek_frame(frame)
   var area: Array=masked.spec.caption_mask.intro[frame]
   var bounds: Rect2=masked.get_global_transform()*Rect2(float(area[0])*2,float(area[1])*2,float(area[2])*2,float(area[3])*2)
   var expected := Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y)
   check(label.material.get_shader_parameter("clip_rect").is_equal_approx(expected),"foreground follows original moving mask")
   check(label.shadow_pass.material.get_shader_parameter("clip_rect").is_equal_approx(expected),"shader shadow follows the same mask")
 quest._enter("john2_2");await process_frame
 for entry: Dictionary in ui.viewport_canvas.episode_timeline.captions:
  if entry.label is Label:
   check(entry.label.material==null,"pooled narrative label clears previous clip")
   check(not entry.label.shadow_pass.material.get_shader_parameter("clip_enabled"),"pooled shadow clears previous clip")
 for point: Vector2 in [Vector2(387,366),Vector2(256,227),Vector2(366,348),Vector2(210,190)]:
  quest._enter("john2_3");await process_frame
  var interactive: Node2D=ui.viewport_canvas.episode_timeline
  check(not interactive.has_outro(),"red pulse is not an exit animation")
  var position: Vector2=ui.world_layer.get_global_transform()*(point*2)
  for down: bool in [true,false]:
   var event := InputEventMouseButton.new()
   event.button_index=MOUSE_BUTTON_LEFT;event.position=position;event.pressed=down
   Input.parse_input_event(event);await process_frame
  check(quest.current_id=="john2_pickup_laser","one tap responds immediately at red door/bag: "+str(point))
  check(not ui.screen.get_meta("episode_animation_block",false),"tap never waits for the red blinking cycle")
 quest._enter("john1_11")
 await process_frame
 var eyes: Node2D=ui.viewport_canvas.episode_timeline
 check(eyes.eye_closure!=null and eyes.eye_closure.get_script()==preload("res://scripts/ui/eye_closure.gd"),"John uses the common EyeClosure component")
 check(int(eyes.spec.eye_blur.frames[0])==0 and int(eyes.spec.eye_blur.frames[1])==14 and not eyes.spec.eye_blur.closing,"original opening interval is preserved")
 var backgrounds: Array=[]
 for key: String in eyes.spec.parts:
  var part: Dictionary=eyes.spec.parts[key]
  if part.has("eye_lid"):
   check(part.texture=="shared_components/eye_lid.png","shared eyelid texture, no duplicate")
  if part.has("blur"):
   backgrounds.append(key)
   check(part.texture=="episode101_components/part_5918ae90a2a2e7aba839.png","blur samples the sharp ceiling")
 check(backgrounds.size()==2,"both original background slots share the blur cache")
 var last_strength := 1.0
 for frame: int in range(15):
  eyes.seek_frame(frame,0.5 if frame<14 else 0.0)
  for key: String in backgrounds:
   var strength: float=eyes.sprites[key].get_child(0).material.get_shader_parameter("blur_strength")
   check(strength<=last_strength and strength>=0.0,"blur decreases during eye opening")
  last_strength=eyes.sprites[backgrounds[0]].get_child(0).material.get_shader_parameter("blur_strength")
 check(is_zero_approx(last_strength),"blur is fully removed at the end of eye motion")
 check(eyes.sprites[backgrounds[0]].get_child(0).material.get_shader_parameter("blur_texture")==eyes.sprites[backgrounds[1]].get_child(0).material.get_shader_parameter("blur_texture"),"one baked blur texture is reused across the background swap")
 eyes.seek_frame(15)
 check(not eyes.eye_closure.lids.upper.visible and not eyes.eye_closure.lids.lower.visible,"final source frame removes eyelids")
 quest._enter("john2_6")
 await process_frame
 var timeline: Node2D=ui.viewport_canvas.episode_timeline
 check(ui.world_layer.get_meta("episode_animation_block",false),"wait for original End before accepting clicks")
 timeline.seek_frame(6)
 check(not ui.world_layer.get_meta("episode_animation_block",false),"background loop does not block clicks after original End")
 check(timeline.playing,"background blinking continues after input becomes available")
 check(quest.ending_count(101)==1,"unified episode has exactly the original surviving ending")
 check(not quest.episode_metadata.has(102),"only one John graph is published")
 quest.new_game(101)
 for id: String in ["john2_3","john2_pickup_laser","john2_4","john2_4_choice","john2_5","john2_6","john2_7","john2_7_choice","john2_8","john2_8_departure","john2_9","john2_10","john2_10_choice","john2_11","john2_11_choice","john2_12","john2_13","john2_14","john2_15","john2_16","john2_result"]:
  check(quest.nodes.has(id),"implemented escape path: "+id)
 quest.new_game(101)
 for target: String in ["john1_2","john1_3","john1_4","john1_5","john1_6","john1_7","john1_7_choice","john1_8","john1_alex_0","john1_alex_1","john1_pickup_note","john1_9","john1_10","john1_11","john2_1","john2_2","john2_3","john2_pickup_laser","john2_4","john2_4_choice","john2_5","john2_6","john2_7","john2_7_choice","john2_8","john2_8_departure","john2_9","john2_10","john2_10_choice","john2_11","john2_11_choice","john2_12","john2_13","john2_14","john2_15","john2_16","john2_result"]:
  var choices: Array=quest.available_choices()
  var found := false
  for i: int in choices.size():
   if choices[i].next==target and not choices[i].get("disabled",false):
    quest.choose(i);found=true;break
  check(found and quest.current_id==target,"continuous John route: "+target)
 check(quest.current_id=="john2_result","authored escape choices reach the original ending")
 check(quest.stats_for(101).wins>=1,"original result is survival")
 check(quest.current().text.contains("Джон Доннатон"),"ending text belongs to web story")
 var legacy: Dictionary=quest._snapshot().duplicate(true)
 legacy.episode=102
 legacy.extra_stats={"101":{"wins":1,"losses":0,"endings":[]},"102":{"wins":2,"losses":1,"endings":[1],"last_ending":1}}
 legacy=quest._migrate_episode_aliases(legacy)
 check(quest._valid(legacy),"legacy part-two save remains valid")
 check(legacy.episode==101 and not legacy.extra_stats.has("102"),"legacy episode ID migrates")
 check(legacy.extra_stats["101"].wins==3 and legacy.extra_stats["101"].losses==1 and legacy.extra_stats["101"].endings==[1],"legacy statistics are merged")
 print("John web episode: %d scenes, %d checks, %d failures" % [scenes,checks,failures])
 ui.free()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(quest.save_path))
 DirAccess.remove_absolute(ProjectSettings.globalize_path(quest.save_path+".bak"))
 quit(1 if failures else 0)
