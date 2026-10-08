extends SceneTree
const TIMELINE := preload("res://scripts/ui/episode_timeline.gd")
const GLOW := preload("res://scripts/ui/interactive_highlight.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1600,960)
 var count := 0
 var vignettes := 0
 for art: String in ["layout_bg_lift_button","e5_hide_6_v1","e5_hide_6_v2","e5_plane_15_v1","e5_plane_15_v2","e5_plane_20_v1","e3_opening_8_anim_0","e3_opening_11_anim_0","e3_john_6_anim_0","e3_john_18_anim_0","e3_john_23_anim_0","e3_john_28","e3_kill_6_anim_0"]:
  var player := TIMELINE.new();root.add_child(player);player.configure(art)
  var cached: Dictionary={}
  for key: String in player.spec.parts:
   var part: Dictionary=player.spec.parts[key]
   if part.type=="soft_vignette":
    vignettes+=1
    var frame: Control=player.sprites[key].get_child(0)
    check(frame.get_script()==preload("res://scripts/ui/soft_vignette.gd"),"QTE uses the shared procedural vignette")
    check(frame.material.shader==preload("res://shaders/soft_vignette.gdshader") and frame.mouse_filter==Control.MOUSE_FILTER_IGNORE,"smooth procedural shader leaves input untouched")
    check(not part.has("texture"),"QTE vignette has no full-screen PNG")
   if part.type!="highlight":continue
   count+=1
   var glow: Control=player.sprites[key].get_child(0)
   check(glow.mouse_filter==Control.MOUSE_FILTER_IGNORE,"glow leaves input to the original QTE/hotspot")
   check(glow.position==Vector2(part.rect[0],part.rect[1])*2-Vector2.ONE*6,"soft-edge padding preserves placement")
   check(glow.material.get_shader_parameter("alpha_min")==1.0 and glow.material.get_shader_parameter("alpha_max")==1.0,"authored blink has no second shader pulse")
   check(not part.has("texture"),"no red PNG dependency")
   cached[key]=glow.texture
  for phase: String in ["intro","outro"]:
   player.play(phase);player.playing=false
   for index: int in player.frames.size():
    player.seek_frame(index)
    for record: Array in player.frames[index]:
     var key: String=record[0]
     if not cached.has(key):continue
     var glow: Control=player.sprites[key].get_child(0)
     check(is_equal_approx(glow.modulate.a,float(record[2][3])*float(player.spec.parts[key].opacity)),"source bitmap alpha combines with authored opacity")
     check(glow.texture==cached[key],"seeking frames reuses cached contour")
  player.free()
 check(count==13,"twelve Episode III glows and lift indicator replaced")
 check(vignettes==5,"all five Episode V QTE instances use one component")
 var regions: Dictionary=GLOW.definitions()
 for mask: String in ["e2_main_1_controls_hit_1","e2_main_1_controls_hit_2","e2_hospital_16_controls_hit_1","e2_hospital_16_controls_hit_2"]:
  check(GLOW.has_mask(mask),"Episode II hit mask is dynamic")
  check(not FileAccess.file_exists("res://assets/flash_ui/"+mask+".png"),"old hit PNG removed")
  var image: Image=GLOW.mask_image(mask)
  check(image==GLOW.mask_image(mask) and image.get_used_rect().has_area(),"hit contour rasterized once")
  check(image.get_size()==Vector2i(regions.regions[regions.masks[mask]].size[0],regions.regions[regions.masks[mask]].size[1]),"hit mask excludes visual padding")
 var quest: Node=root.get_node("Quest")
 quest.save_path="user://e23_glow_test.json";quest.tmp_path="user://e23_glow_test.tmp";quest.backup_path="user://e23_glow_test.bak";quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await process_frame
 ui._start_episode(2)
 for scene: String in ["e2_main_1","e2_hospital_16"]:
  for choice_index: int in range(2):
   quest.flags={"TakenKey":true,"Auto":0,"BulletsNumber":12,"LinkedFr":true}
   quest._enter(scene);await process_frame
   var buttons: Array=[]
   for button: Node in ui.world_layer.find_children("*","Button",true,false):
    if button.get_script()==preload("res://scripts/ui/alpha_hotspot.gd"):buttons.append(button)
   check(buttons.size()==2,"two native alpha hotspots retained")
   if buttons.size()!=2:continue
   var button: Button=buttons[choice_index]
   var image: Image=button.hit_image
   var pixel:=Vector2.ZERO
   var nearest:=INF
   for y: int in range(0,image.get_height(),3):
    for x: int in range(0,image.get_width(),3):
     if image.get_pixel(x,y).a<0.9:continue
     var point:=Vector2(x+0.5,y+0.5)
     var distance: float=point.distance_squared_to(Vector2(image.get_size())*0.5)
     if distance<nearest:nearest=distance;pixel=point
   var local_point: Vector2=pixel/Vector2(image.get_size())*button.size
   check(button._has_point(local_point),"visible contour accepts a tap")
   check(not button._has_point(Vector2(-1,-1)),"outside contour rejects a tap")
   var position: Vector2=button.get_global_transform()*local_point
   for down: bool in [true,false]:
    var event:=InputEventMouseButton.new()
    event.button_index=MOUSE_BUTTON_LEFT;event.position=position;event.pressed=down
    Input.parse_input_event(event);await process_frame
   if quest.current_id==scene and ui.screen.get_meta("episode_animation_block",false):
    var exit_player: Node2D=ui.viewport_canvas.episode_timeline
    if is_instance_valid(exit_player):exit_player.seek_frame(exit_player.frames.size()-1)
   check(quest.current_id!=scene,"physical tap activates the original story choice")
 ui.free();await process_frame
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("PASS: %d dynamic highlight checks; failures %d" % [checks,failures])
 quit(1 if failures else 0)
