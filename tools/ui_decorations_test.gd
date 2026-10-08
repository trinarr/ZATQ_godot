extends SceneTree
const DECORATION := preload("res://scripts/ui/vector_decoration.gd")
const COMPONENTS := preload("res://scripts/ui/flash_components.gd")
const VIGNETTE := preload("res://scripts/ui/soft_vignette.gd")
const TIMELINE := preload("res://scripts/ui/episode_timeline.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  push_error(message)
  failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_decorations.json"))
 for id: String in definitions:
  if not definitions[id].has("layers"): continue
  var texture := DECORATION.texture_for(id)
  check(texture != null,"Missing decoration: "+id)
  check(texture == DECORATION.texture_for(id),"Cache misses: "+id)
  var image := texture.get_image()
  check(image.get_size() == Vector2i(definitions[id].size[0],definitions[id].size[1]),"Size: "+id)
  check(not image.is_invisible(),"Blank decoration: "+id)
 var host := Control.new();root.add_child(host)
 for id: String in ["e3_opening_8","e3_kill_6"]:
  COMPONENTS.draw(host,[{"type":"soft_vignette","rect":[0,0,800,480],"vignette":definitions[id]}])
  check(host.get_child(-1) is VIGNETTE,"Static vignette: "+id)
  check(host.get_child(-1).mouse_filter==Control.MOUSE_FILTER_IGNORE,"Decorations must not intercept input")
 for art: String in ["e3_opening_8_anim_0","e3_kill_6_anim_0","e6_prison_3_v1"]:
  var timeline := TIMELINE.new();host.add_child(timeline)
  timeline.configure(art)
  check(not timeline.sprites.is_empty(),"Timeline: "+art)
  timeline.seek_frame(0)
  timeline.queue_free()
 print("PASS: %d decoration/cache/vignette checks" % checks)
 quit(1 if failures else 0)
