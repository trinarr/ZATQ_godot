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
  for child: Node in container.get_children():
   if child is TextureRect: textures.append(child)
   elif child.get_script()==ui.TORN_ICON:
    for icon: TextureRect in child.icons: textures.append(icon)
  check(textures.size()==expected.size(),"every component instantiated: "+name)
  for layer: String in ["background","foreground"]:
   for part: Dictionary in expected:
    if part.layer!=layer:continue
    var r: Array=part.rect
    var node: TextureRect
    for candidate: TextureRect in textures:
     if candidate.texture.resource_path.ends_with(part.texture) and (container.get_global_transform().affine_inverse()*candidate.global_position).is_equal_approx(Vector2(r[0],r[1])*2): node=candidate;break
    check(node!=null,"authored texture and position: "+part.texture)
    if node==null:continue
    check(node.texture!=null,"texture loaded")
    check(node.size==Vector2(r[2],r[3])*2,"authored component size")
    check(node.mouse_filter==Control.MOUSE_FILTER_IGNORE,"component does not intercept buttons")
    if node.get_parent().get_script()==ui.TORN_ICON:
     check(node.get_index()>node.get_parent().background.get_index(),"icons above their own shader background")
    if shared.has(part.texture):check(shared[part.texture]==node.texture,"same texture resource reused")
    shared[part.texture]=node.texture
 ui.queue_free()
 await process_frame
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("PASS: %d composition checks; failures %d" % [checks,failures])
 quit(1 if failures else 0)
