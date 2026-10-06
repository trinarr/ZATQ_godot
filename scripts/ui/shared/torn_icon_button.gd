extends "res://scripts/ui/shared/torn_button.gd"
# Square backing; original icons are children, never separate hotspots.
var icons: Array[TextureRect] = []
var custom_icon: TextureRect
@export var icon_texture: Texture2D:
 set(value):
  icon_texture = value
  if not is_instance_valid(custom_icon):
   custom_icon = TextureRect.new()
   custom_icon.name = "Icon"
   custom_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
   custom_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
   custom_icon.set_meta("icon_bounds",Rect2(0.32,0.32,0.36,0.36))
   add_child(custom_icon)
   icons.append(custom_icon)
  custom_icon.texture = value
  _layout_content()
func add_icon(image: TextureRect) -> void:
 var local_position := get_global_transform().affine_inverse()*image.global_position
 image.reparent(self)
 image.position = local_position
 image.mouse_filter = Control.MOUSE_FILTER_IGNORE
 image.set_meta("icon_bounds",Rect2(image.position/size,image.size/size))
 icons.append(image)

func _layout_content() -> void:
 super()
 for image: TextureRect in icons:
  var bounds: Rect2 = image.get_meta("icon_bounds")
  image.position = bounds.position*size
  image.size = bounds.size*size
