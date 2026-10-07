extends RefCounted
const BLUR_CACHE := preload("res://scripts/ui/blur_texture_cache.gd")
const HIGHLIGHT := preload("res://scripts/ui/interactive_highlight.gd")
const QTE_PROMPT := preload("res://scripts/ui/qte_prompt.gd")
# Primitive Flash display-list layers. Coordinates are authored at 800x480.
static func draw(parent: Control, parts: Array, layer: String = "") -> void:
 for part: Dictionary in parts:
  if not layer.is_empty() and part.get("layer","background") != layer: continue
  if part.type == "polygon":
   var polygon := Polygon2D.new()
   var points := PackedVector2Array()
   for point: Array in part.points: points.append(Vector2(point[0],point[1])*2)
   polygon.polygon = points
   var color: Array = part.color
   polygon.color = Color(color[0],color[1],color[2],color[3])
   parent.add_child(polygon)
   continue
  if part.type == "highlight":
   var glow := HIGHLIGHT.new()
   glow.configure(part)
   parent.add_child(glow)
   continue
  var control: Control
  if part.type == "qte_prompt":
   var prompt := QTE_PROMPT.new()
   var m: Array = part.transform
   var basis := Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5])*2)
   prompt.position = basis.origin
   prompt.rotation = basis.get_rotation()
   prompt.scale = basis.get_scale()
   prompt.text_key = part.get("text",prompt.text_key)
   prompt.refresh_text()
   prompt.modulate.a = float(part.get("opacity",1.0))
   parent.add_child(prompt)
   continue
  if part.type == "panel":
   var panel := ColorRect.new()
   var c: Array = part.color
   panel.color = Color(c[0],c[1],c[2],c[3])
   control = panel
  else:
   var image := TextureRect.new()
   image.texture = load("res://assets/flash_ui/" + part.texture)
   image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
   control = image
  var r: Array = part.rect
  control.position = Vector2(r[0],r[1]) * 2
  control.size = Vector2(r[2],r[3]) * 2
  control.mouse_filter = Control.MOUSE_FILTER_IGNORE
  if part.has("blur"):
   control.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
   var paint:=ShaderMaterial.new()
   paint.shader=preload("res://shaders/flash_color_transform.gdshader")
   if control is TextureRect:BLUR_CACHE.bind(paint,control.texture,part.blur)
   control.material=paint
  parent.add_child(control)
