extends SceneTree
const TEST_CLOCK := preload("res://tools/flash_test_clock.gd")
const TIMELINE := preload("res://scripts/ui/episode_timeline.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:
  failures+=1
  push_error(message)
func _initialize() -> void:call_deferred("run")
func strength(player: Node2D) -> float:
 for key: String in player.spec.parts:
  if player.spec.parts[key].has("blur"):
   var paint: ShaderMaterial=player.sprites[key].get_child(0).material
   return float(paint.get_shader_parameter("blur_strength"))
 return -1.0
func run() -> void:
 # Use real timing/layers and a generated sharp texture to verify sampler
 # binding without relying on external PNG import or Android decoding.
 var image:=Image.create(4,4,false,Image.FORMAT_RGBA8)
 image.fill(Color(0.25,0.5,0.75,1.0))
 var texture:=ImageTexture.create_from_image(image)
 DirAccess.make_dir_recursive_absolute("res://assets/flash_ui")
 var sample_name: String="_blur_fade_test_%s.tres" % get_instance_id()
 var sample_path: String="res://assets/flash_ui/"+sample_name
 check(ResourceSaver.save(texture,sample_path)==OK,"test sharp texture saved")
 var data: Dictionary=TIMELINE.catalog().duplicate(true)
 for art: String in ["ep1_mainstreet_choice","city_office_threat"]:
  for part: Dictionary in data.art[art].parts.values():
   part.type="texture";part.texture=sample_name;part.erase("color")
 data.art={"ep1_mainstreet_choice":data.art.ep1_mainstreet_choice,"city_office_threat":data.art.city_office_threat}
 TIMELINE.data=data
 var player:=TIMELINE.new();root.add_child(player);player.configure("ep1_mainstreet_choice")
 for key: String in player.spec.parts:
  if player.spec.parts[key].has("blur"):
   var visual: TextureRect=player.sprites[key].get_child(0)
   var paint: ShaderMaterial=visual.material
   check(visual.texture!=null,"sharp image loaded")
   check(paint.get_shader_parameter("blur_texture")==visual.texture,"blur sampler bound to sharp image")
 check(is_equal_approx(strength(player),1.0),"wall reveal starts fully blurred")
 TEST_CLOCK.step(player,0.5/float(data.fps))
 check(player.current_frame==0 and strength(player)<1.0,"blur changes between authored frames")
 var last: float=1.0
 for i in range(1,45):
  var t: float=float(i)*float(player.frames.size()-1)/44.0
  player.seek_frame(int(floor(t)),fposmod(t,1.0))
  var current: float=strength(player)
  check(current>=0.0 and current<=last,"reveal blur decreases monotonically")
  last=current
 check(strength(player)==0.0,"last reveal frame has exactly zero blur")
 player.play("intro");TEST_CLOCK.step(player,0.25)
 var saved: float=strength(player);var frame: int=player.current_frame
 player.suspended=true;TEST_CLOCK.step(player,1.0)
 check(strength(player)==saved and player.current_frame==frame,"pause preserves blur and frame")
 player.suspended=false;TEST_CLOCK.step(player,0.01)
 check(strength(player)<saved,"resume continues continuous blur fade")
 player.play("outro")
 check(strength(player)==0.0,"retreat starts sharp without blur jump")
 TEST_CLOCK.step(player,0.01)
 check(strength(player)>0.0,"retreat increases blur between frames")
 player.seek_frame(player.frames.size()-1)
 check(strength(player)==1.0,"retreat finishes at original blur strength")
 var other:=TIMELINE.new();root.add_child(other);other.configure("city_office_threat")
 for key: String in other.spec.parts:
  if other.spec.parts[key].has("blur"):
   var material: ShaderMaterial=other.sprites[key].get_child(0).material
   var value=material.get_shader_parameter("blur_strength")
   check(value==null or float(value)==1.0,"wall fade does not affect office blur")
 for i in 16:await process_frame
 player.free();other.free()
 await process_frame
 DirAccess.remove_absolute(sample_path)
 print("Blur fade: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
