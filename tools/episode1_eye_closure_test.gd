extends SceneTree
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
   return float(player.sprites[key].get_child(0).material.get_shader_parameter("blur_strength"))
 return -1.0
func run() -> void:
 var player:=TIMELINE.new();root.add_child(player);player.configure("ep1_mainstreet_attack")
 var lids: Dictionary={}
 for key: String in player.spec.parts:
  var part: Dictionary=player.spec.parts[key]
  if part.source.ends_with("/Symbol 327"):lids.upper=key
  if part.source.ends_with("/Symbol 325"):lids.lower=key
 check(lids.size()==2,"both original soft eyelids present")
 var upper: Array=player.spec.parts[lids.upper].rect
 var lower: Array=player.spec.parts[lids.lower].rect
 check(upper[1]<-210.0 and upper[3]>=432.0,"upper eyelid retains off-stage pixels")
 check(lower[0]<=-1.0 and lower[3]>=432.0,"lower eyelid retains off-stage pixels")
 player.seek_frame(18);check(strength(player)==0.0,"background starts sharp")
 player.seek_frame(19);check(strength(player)==0.0,"bitmap swap does not introduce blur jump")
 var previous: float=0.0
 for i in range(1,57):
  var t: float=19.0+float(i)/4.0
  player.seek_frame(int(floor(t)),fposmod(t,1.0))
  var current: float=strength(player)
  check(current>previous and is_equal_approx(current,(t-19.0)/14.0),"blur follows eye closure continuously")
  previous=current
  var top: float=upper[1]+player.sprites[lids.upper].position.y/2.0
  var bottom: float=lower[1]+lower[3]+player.sprites[lids.lower].position.y/2.0
  check(top<=0.0 and bottom>=480.0,"moving eyelids keep screen edges covered")
 check(strength(player)==1.0,"closed eye reaches full blur")
 player.play("intro");player._process(25.5/19.0)
 var saved: float=strength(player)
 player.suspended=true;player._process(1.0)
 check(strength(player)==saved,"pause preserves blur")
 player.suspended=false;player._process(0.01)
 check(strength(player)>saved,"resume continues closure")
 player.play("outro");check(strength(player)==1.0,"held closed pose keeps full blur")
 player.free()
 print("Eye closure: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
