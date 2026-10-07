extends Node
# Render each texture/radius/direction once. Retain only the small render target;
# sharp inputs and bake materials are released when the job finishes.
const BAKE_SHADER := preload("res://shaders/flash_blur_bake.gdshader")
const CACHE_SCALE := 0.5
class Entry extends RefCounted:
 signal baked
 var texture: Texture2D
 var sigma: Vector2
 var angle: float
 var complete := false
 var viewport: SubViewport
 var renders := 0
static var _entries: Dictionary = {}
static var _host: Node
var pending: Array[Entry] = []
var busy := false
var bakes_started := 0
static func request(sharp: Texture2D, sigma: Vector2, angle: float) -> Entry:
 var source: String=sharp.resource_path
 if source.is_empty():source=str(sharp.get_rid().get_id())
 var key: String="%s:%.4f:%.4f:%.4f" % [source,sigma.x,sigma.y,angle]
 if _entries.has(key):return _entries[key]
 var entry:=Entry.new();entry.texture=sharp;entry.sigma=sigma;entry.angle=angle
 _entries[key]=entry
 # The dummy headless renderer cannot produce render-target pixels.
 if DisplayServer.get_name()=="headless":
  entry.complete=true
  return entry
 if not is_instance_valid(_host):
  _host=load("res://scripts/ui/blur_texture_cache.gd").new()
  _host.name="BlurTextureCache"
  var tree:=Engine.get_main_loop() as SceneTree
  tree.root.add_child.call_deferred(_host)
 _host.pending.append(entry)
 _host._begin.call_deferred()
 return entry
static func bind(paint: ShaderMaterial, sharp: Texture2D, blur: Dictionary) -> Entry:
 var entry:=request(sharp,Vector2(blur.sigma[0],blur.sigma[1])*2,float(blur.angle))
 # Until the target is ready use the sharp image, never a blank/default sampler.
 paint.set_shader_parameter("blur_texture",entry.texture)
 paint.set_shader_parameter("has_blur",true)
 if not entry.complete:
  entry.baked.connect(func():paint.set_shader_parameter("blur_texture",entry.texture),CONNECT_ONE_SHOT)
 return entry
static func prewarm(artworks: Dictionary) -> void:
 for artwork: Dictionary in artworks.values():
  for part: Dictionary in artwork.parts.values():
   if not part.has("blur") or not part.has("texture"):continue
   var sharp: Texture2D=load("res://assets/flash_ui/"+part.texture)
   if sharp!=null:request(sharp,Vector2(part.blur.sigma[0],part.blur.sigma[1])*2,float(part.blur.angle))
func _begin() -> void:
 if busy or pending.is_empty() or not is_inside_tree():return
 busy=true
 var entry: Entry=pending.pop_front()
 var source: Texture2D=entry.texture
 var viewport:=SubViewport.new();entry.viewport=viewport
 viewport.name="BlurBake"
 viewport.world_2d=World2D.new()
 viewport.transparent_bg=true
 viewport.size=Vector2i(maxi(1,ceili(source.get_width()*CACHE_SCALE)),maxi(1,ceili(source.get_height()*CACHE_SCALE)))
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 add_child(viewport)
 var image:=TextureRect.new();image.texture=source
 image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 image.size=Vector2(viewport.size);image.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var paint:=ShaderMaterial.new();paint.shader=BAKE_SHADER
 paint.set_shader_parameter("blur_texture",source)
 paint.set_shader_parameter("blur_sigma",entry.sigma)
 paint.set_shader_parameter("blur_angle",entry.angle)
 image.material=paint;viewport.add_child(image)
 entry.renders+=1;bakes_started+=1
 viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
 await RenderingServer.frame_post_draw
 if not is_instance_valid(viewport):return
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_NEVER
 entry.texture=viewport.get_texture();entry.complete=true
 # Disabled target preserves its pixels while the source scene is discarded.
 image.free()
 entry.baked.emit()
 busy=false
 _begin.call_deferred()
func _exit_tree() -> void:
 for entry: Entry in _entries.values():
  for connection: Dictionary in entry.baked.get_connections():
   entry.baked.disconnect(connection.callable)
 _entries.clear();_host=null
