extends SceneTree
const TEST_CLOCK := preload("res://tools/flash_test_clock.gd")
const TIMELINE := preload("res://scripts/ui/episode_timeline.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var data: Dictionary=TIMELINE.catalog()
 check(data.fps==19,"original Flash fps")
 check(data.art.size()>40,"all Episode I animated scenery covered")
 for art: String in data.art:
  var player:=TIMELINE.new();root.add_child(player);player.configure(art)
  for phase: String in ["intro","outro"]:
   player.play(phase)
   for index: int in data.art[art][phase].size():
    player.seek_frame(index)
    check(player.current_frame==index,"authored frame selected: "+art)
    for pivot: Node2D in player.sprites.values():
     var image: Control=pivot.get_child(0)
     if image is TextureRect:check(image.texture!=null,"component resource loaded")
     check(is_finite(pivot.transform.origin.x),"finite world transform")
   player.play(phase);player.suspended=true
   var frame: int=player.current_frame;TEST_CLOCK.step(player,0.25)
   check(player.current_frame==frame,"pause freezes timeline")
   player.suspended=false;TEST_CLOCK.step(player,0.25)
   check(player.current_frame==mini(4+int(data.fps*0),player.frames.size()-1),"playback resumes")
  player.free()
 var quest: Node=root.get_node("Quest")
 quest.save_path="user://animation_test.json";quest.tmp_path="user://animation_test.tmp";quest.backup_path="user://animation_test.bak";quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await process_frame
 ui.playing=true;quest.new_game(1)
 for id: String in ["wake","lift","lift_button","tv","car_fatal","office_fatal","bite_transition","door_explosion","door_blast","door_blast_inner","roof_explosion","explosion_flash","farm_chase","mainstreet_attack"]:
  quest.current_id=id;ui.playing=true;ui.paused=false;ui._show_story();ui.television.stop()
  var player: Node2D=ui.viewport_canvas.episode_timeline
  check(is_instance_valid(player),"animated scene player: "+id)
  check(ui.viewport_canvas.component_background_active,"world interaction keeps same coordinate space")
  if is_instance_valid(player):player.seek_frame(player.frames.size()-1)
 quest.current_id="lift";ui.playing=true;ui.paused=false;ui._show_story()
 var lift: Node2D=ui.viewport_canvas.episode_timeline
 ui._choose(0)
 check(quest.current_id=="lift" and lift.phase=="outro","lift waits for authored exit")
 ui._choose(0)
 check(quest.current_id=="lift","duplicate gesture does not bypass exit")
 ui._show_pause();var frame: int=lift.current_frame;TEST_CLOCK.step(lift,1)
 check(lift.current_frame==frame,"pause freezes pending exit")
 ui._resume()
 check(ui.viewport_canvas.episode_timeline==lift and not lift.suspended,"resume keeps exact player")
 lift.seek_frame(lift.frames.size()-1)
 check(quest.current_id=="lift_button","exit completes once")
 quest.current_id="farm_noise";ui.playing=true;ui._show_story()
 var noise: Node2D=ui.viewport_canvas.episode_timeline
 check(not noise.captions.is_empty(),"original moving description remains native text")
 var caption: Label=noise.captions[0].label
 check(caption.modulate.a==0,"description starts transparent like Flash")
 noise.seek_frame(noise.frames.size()-1)
 check(caption.modulate.a==1,"description reaches original visible stop")
 quest.current_id="keys";ui.playing=true;ui._show_story()
 var popup: Control=ui.overlay
 var title: Label=popup.find_child("ItemTitle",true,false)
 var description: Label=popup.find_child("ItemDescription",true,false)
 check(title.position.y==34,"item header stays fixed during entrance")
 check(description.position.y<0,"item content starts above viewport")
 for child: Node in popup.get_children():
  if child.has_method("configure_targets"):child.seek_frame(100)
 check(description.position.y==142,"item content ends at exact original position")

 ui.free()
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("Episode I animations: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
