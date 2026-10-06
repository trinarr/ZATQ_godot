extends RefCounted
const QTE_PROMPT := preload("res://scripts/ui/qte_prompt.gd")
# Primitive Flash display-list layers. Coordinates are authored at 800x480.
static func draw(parent: Control, parts: Array, layer: String = "") -> void:
 for part: Dictionary in parts:
  if not layer.is_empty() and part.get("layer","background") != layer: continue
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
  parent.add_child(control)
