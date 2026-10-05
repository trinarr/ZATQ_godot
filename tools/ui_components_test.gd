extends SceneTree
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var quest: Node = root.get_node("Quest")
 quest.save_path="user://components_test.json"
 quest.tmp_path="user://components_test.tmp"
 quest.backup_path="user://components_test.bak"
 quest.sound_enabled=false
 var ui: Control = load("res://scenes/Main.tscn").instantiate()
 root.add_child(ui)
 await process_frame
 var shared: Dictionary = {}
 for name: String in ui.art_components:
  ui._reset_screen()
  var container: Control = ui._art(name)
  check(not container is TextureRect,"screen is a composition: " + name)
  var expected: Array = ui.art_components[name]
  var textures: Array[TextureRect] = []
  var last_brush := -1
  for i: int in container.get_child_count():
   var child: Node = container.get_child(i)
   if child is TextureRect: textures.append(child)
   elif child.get_script()==ui.BRUSH: last_brush=i
  check(textures.size()==expected.size(),"every component instantiated: "+name)
  var index := 0
  for layer: String in ["background","foreground"]:
   for part: Dictionary in expected:
    if part.layer!=layer:continue
    var node: TextureRect = textures[index]
    index+=1
    var r: Array=part.rect
    check(node.texture!=null,"texture loaded")
    check(node.position==Vector2(r[0],r[1])*2 and node.size==Vector2(r[2],r[3])*2,"authored component geometry")
    check(node.mouse_filter==Control.MOUSE_FILTER_IGNORE,"component does not intercept buttons")
    if layer=="foreground":check(node.get_index()>last_brush,"icons above shader buttons")
    if shared.has(part.texture):check(shared[part.texture]==node.texture,"same texture resource reused")
    shared[part.texture]=node.texture
 ui.queue_free()
 await process_frame
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("PASS: %d composition checks; failures %d" % [checks,failures])
 quit(1 if failures else 0)
