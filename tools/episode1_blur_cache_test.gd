extends SceneTree
const CACHE := preload("res://scripts/ui/blur_texture_cache.gd")
const DISPLAY_SHADER := preload("res://shaders/flash_color_transform.gdshader")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:
  failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func capture(sharp: Texture2D, blurred: Texture2D, amount: float) -> Image:
 var viewport:=SubViewport.new();viewport.size=Vector2i(128,64)
 viewport.world_2d=World2D.new();viewport.transparent_bg=true
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var image:=TextureRect.new();image.texture=sharp;image.size=Vector2(128,64)
 image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 var paint:=ShaderMaterial.new();paint.shader=DISPLAY_SHADER
 paint.set_shader_parameter("has_blur",true);paint.set_shader_parameter("blur_texture",blurred)
 paint.set_shader_parameter("blur_strength",amount)
 image.material=paint;viewport.add_child(image)
 viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
 await RenderingServer.frame_post_draw
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 var result: Image=viewport.get_texture().get_image()
 viewport.queue_free();await process_frame
 return result
func run() -> void:
 if DisplayServer.get_name()=="headless":
  print("SKIP: blur cache pixel test requires a graphics renderer")
  quit();return
 var source:=Image.create(128,64,false,Image.FORMAT_RGBA8);source.fill(Color.BLACK)
 for y in 64:source.set_pixel(64,y,Color.WHITE)
 var sharp:=ImageTexture.create_from_image(source)
 var paint:=ShaderMaterial.new();paint.shader=DISPLAY_SHADER
 var entry=CACHE.bind(paint,sharp,{"sigma":[6.2,0.35],"angle":0.0})
 var repeat=CACHE.request(sharp,Vector2(12.4,0.7),0.0)
 check(entry==repeat,"same source/parameters reuse one job")
 check(paint.get_shader_parameter("blur_texture")==sharp,"pending job uses sharp fallback")
 for i in 120:
  if entry.complete:break
  await process_frame
 check(entry.complete,"one-shot render completes")
 if not entry.complete:
  quit(1);return
 check(entry.renders==1,"blur rendered once")
 check(entry.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"cached viewport stops rendering")
 check(entry.viewport.get_child_count()==0,"bake scene releases sharp image/material")
 check(entry.texture.get_size()==Vector2(64,32),"cache uses half-resolution target")
 check(paint.get_shader_parameter("blur_texture")==entry.texture,"material receives cached image")
 var baked: Image=entry.texture.get_image()
 check(baked!=null and not baked.is_empty(),"cached pixels exist")
 var center: float=baked.get_pixel(32,16).r
 check(center>0.001 and center<0.2,"blur contains visible smooth art")
 check(baked.get_pixel(36,16).r>0.001,"blur spreads to neighbouring pixels")
 var snapshot: PackedByteArray=baked.get_data()
 for i in 12:await process_frame
 check(entry.texture.get_image().get_data()==snapshot,"cache remains valid after input scene removal")
 check(entry.renders==1,"idle frames do not rebake")
 var full: Image=await capture(sharp,entry.texture,1.0)
 var halfway: Image=await capture(sharp,entry.texture,0.5)
 var clean: Image=await capture(sharp,entry.texture,0.0)
 check(clean.get_data()==source.get_data(),"fade endpoint exactly matches sharp image")
 var full_value: float=full.get_pixel(64,32).r
 check(absf(halfway.get_pixel(64,32).r-(full_value+1.0)*0.5)<0.02,"alpha fade mixes cached and sharp pixels")
 var reused=CACHE.request(sharp,Vector2(12.4,0.7),0.0)
 check(reused==entry and reused.complete and reused.renders==1,"reopening uses existing cached target")
 var changed=CACHE.request(sharp,Vector2(8.0,0.7),0.0)
 check(changed!=entry,"different radius gets its own one-shot cache")
 for i in 120:
  if changed.complete:break
  await process_frame
 check(changed.complete and changed.renders==1,"second variant also renders only once")
 print("Blur cache pixels: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
