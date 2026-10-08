extends TextureRect
# Original contours and feathered alpha bands, rasterized only once per shape.
# Subsequent popup instances share the texture; no blur or generation each frame.
static var definitions: Dictionary = {}
static var textures: Dictionary = {}

static func texture_for(id: String) -> Texture2D:
 if textures.has(id): return textures[id]
 if definitions.is_empty():
  definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_decorations.json"))
 var spec: Dictionary = definitions[id]
 var paths: PackedStringArray = []
 for layer: Dictionary in spec.layers:
  var rings: PackedStringArray = []
  for contour: Array in layer.contours:
   var commands: PackedStringArray = []
   for i: int in range(0,contour.size(),2):
    commands.append("%s%s %s" % ["M" if i==0 else "L",str(contour[i]),str(contour[i+1])])
   rings.append(" ".join(commands)+" Z")
  paths.append('<path fill="white" fill-rule="evenodd" opacity="%s" d="%s"/>' % [str(layer.opacity)," ".join(rings)])
 var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">%s</svg>' % [int(spec.size[0]),int(spec.size[1]),"".join(paths)]
 var image := Image.new()
 var error := image.load_svg_from_string(svg)
 if error != OK:
  push_error("Cannot rasterize UI decoration: "+id)
  return null
 textures[id] = ImageTexture.create_from_image(image)
 return textures[id]

func configure(part: Dictionary) -> void:
 texture = texture_for(part.decoration)
 var c: Array = definitions[part.decoration].color
 self_modulate = Color(c[0],c[1],c[2],1)
 expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
 mouse_filter = Control.MOUSE_FILTER_IGNORE
