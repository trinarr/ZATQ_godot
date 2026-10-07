extends SceneTree
const TIMELINE := preload("res://scripts/ui/episode_timeline.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var quest: Node = root.get_node("Quest")
 quest.save_path="user://weapon_visibility_test.json"
 quest.tmp_path="user://weapon_visibility_test.tmp"
 quest.backup_path="user://weapon_visibility_test.bak"
 quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate()
 root.add_child(ui)
 await process_frame
 ui._start_episode(2)
 for bullets: int in [-1,0,1,3,5,12]:
  quest.flags.BulletsNumber=bullets
  for id: String in ["e2_first_3","e2_first_3_choice_15","e2_first_3_choice_19","e2_first_locked"]:
   quest.current_id=id
   quest.popup_origin="e2_first_3"
   ui._stop_cutscene()
   ui.playing=true
   ui.paused=false
   ui._show_story()
   var player: Node2D=ui.viewport_canvas.episode_timeline
   check(is_instance_valid(player),"door timeline: "+id)
   if not is_instance_valid(player): continue
   var armed: bool=false
   for part: Dictionary in player.spec.parts.values():
    if part.source=="Mov/Symbol 2169":armed=true
    if part.source=="Mov/Symbol 2170":
     var expected: String="part_76518f9f34a286c5650c.png" if bullets==-1 else "part_727e105da01a17236ccc.png"
     check(part.texture.get_file()==expected,"background focus follows weapon ownership")
     check(not part.has("blur"),"door background has no additional shader blur")
   check(armed==(bullets>=0),"weapon ownership, including empty gun: %s/%d" % [id,bullets])
   check(player.art_name==("e2_first_3_unarmed" if bullets==-1 else "e2_first_3"),"resolved scene variant")
   for phase: String in ["intro","outro"]:
    player.play(phase)
    player.playing=false
    for frame: int in player.frames.size():
     player.seek_frame(frame)
     for key: String in player.sprites:
      check(bullets>=0 or player.spec.parts[key].source!="Mov/Symbol 2169","no weapon appears during animation")
  quest.current_id="e2_first_3"
  check(quest.available_choices()[0].next==("e2_first_3_choice_15" if bullets>0 else "e2_first_3_choice_19"),"shooting requires ammunition")
 # The unarmed variant reuses the existing sharp doors and preserves timing.
 var art: Dictionary=TIMELINE.catalog().art
 check(art.e2_first_3.intro.size()==art.e2_first_3_unarmed.intro.size(),"authored frame count preserved")
 for part: Dictionary in art.e2_first_3_unarmed.parts.values():
  check(part.texture=="episode2_components/part_76518f9f34a286c5650c.png","reuse existing sharp background texture")
 # Resume must resolve the scene from the restored weapon flag too.
 for bullets: int in [-1,0]:
  quest.flags.BulletsNumber=bullets
  quest.current_id="e2_first_3"
  check(quest.save_game(),"save weapon ownership")
  quest.flags.BulletsNumber=12
  quest._load_save()
  check(quest.flags.BulletsNumber==bullets,"restore exact weapon flag")
  check(quest.current().art==("e2_first_3_unarmed" if bullets==-1 else "e2_first_3"),"restored art uses weapon ownership")
 ui.free()
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("Episode II weapon visibility: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
