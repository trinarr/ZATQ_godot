extends SceneTree
const TIMELINE := preload("res://scripts/ui/episode_timeline.gd")
const EYE := preload("res://scripts/ui/eye_closure.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:
  failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var found: Array[String]=[]
 var textures: Dictionary={}
 for art: String in TIMELINE.catalog().art:
  var spec: Dictionary=TIMELINE.catalog().art[art]
  if not spec.parts.values().any(func(p):return p.has("eye_lid")):continue
  found.append(art)
  var player:=TIMELINE.new();root.add_child(player);player.configure(art);player.playing=false
  check(player.eye_closure!=null and player.eye_closure.lids.size()==2,art+": shared pair instantiated")
  for key: String in spec.parts:
   var part: Dictionary=spec.parts[key]
   if not part.has("eye_lid"):continue
   var visual: TextureRect=player.sprites[key].get_child(0)
   textures[visual.texture.get_rid()]=true
   check(visual.flip_v==(part.eye_lid=="lower"),art+": original bitmap orientation")
   check(part.rect[3]==433.0,art+": complete eyelid retained")
  for frame in spec.intro.size():
   player.seek_frame(frame)
   for key: String in spec.parts:
    var part: Dictionary=spec.parts[key]
    if not part.has("eye_lid") or not player.sprites[key].visible:continue
    var visual: TextureRect=player.sprites[key].get_child(0)
    var pos: Vector2=player.sprites[key].position+visual.position
    check(pos.x<=0.1 and pos.x+visual.size.x>=1599.9,art+": horizontal screen edges covered")
    check(pos.y<=0.1 if part.eye_lid=="upper" else pos.y+visual.size.y>=959.9,art+": viewport edge covered")
  if spec.has("eye_blur"):
   var interval: Array=spec.eye_blur.frames
   for i in 41:
    var t: float=lerpf(float(interval[0]),float(interval[1]),float(i)/40.0)
    player.seek_frame(int(floor(t)),fposmod(t,1.0))
    var expected: float=float(i)/40.0 if spec.eye_blur.closing else 1.0-float(i)/40.0
    for key: String in spec.parts:
     if spec.parts[key].has("blur"):
      var actual: float=player.sprites[key].get_child(0).material.get_shader_parameter("blur_strength")
      check(is_equal_approx(actual,expected),art+": continuous blur synchronized across background replacement")
   player.play("outro")
   for key: String in spec.parts:
    if spec.parts[key].has("blur"):
     check(float(player.sprites[key].get_child(0).material.get_shader_parameter("blur_strength"))==(1.0 if spec.eye_blur.closing else 0.0),art+": final blur retained")
  player.free()
 check(found.size()==5,"all five active source eye clips use the component")
 check(textures.size()==1,"all eyelids reuse one texture")
 var standalone:=EYE.new();root.add_child(standalone);standalone.configure_default()
 standalone.set_closure(0.0)
 check(standalone.lids.upper.position.y<standalone.lids.lower.position.y,"standalone open pose")
 standalone.set_closure(1.0)
 check(standalone.lids.upper.position.y>standalone.lids.lower.position.y,"standalone closed pose")
 standalone.animate_closure(0.0,0.05)
 await standalone.finished
 check(standalone.closure==0.0,"standalone component can animate without MovieClip data")
 await process_frame
 standalone.free()
 print("Shared eye closure: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
