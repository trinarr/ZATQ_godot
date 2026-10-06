extends TextureRect
# Rasterize stored vector contours once in memory. No per-object PNG resource.
const SHADER := preload("res://shaders/interactive_highlight.gdshader")
const PADDING := 6
static var data: Dictionary = {}
static var cache: Dictionary = {}
var region_id := ""

static func definitions() -> Dictionary:
	if data.is_empty():
		data = JSON.parse_string(FileAccess.get_file_as_string("res://data/episode1_highlights.json"))
	return data

static func has_mask(id: String) -> bool:
	return definitions().masks.has(id)

static func mask_image(id: String) -> Image:
	return build_region(definitions().masks[id]).hit_image

static func build_region(id: String) -> Dictionary:
	if cache.has(id): return cache[id]
	var region: Dictionary = definitions().regions[id]
	var width: int = int(region.size[0])+PADDING*2
	var height: int = int(region.size[1])+PADDING*2
	var paths: PackedStringArray = []
	for contour: Array in region.contours:
		var commands: PackedStringArray = []
		for i: int in range(0,contour.size(),2):
			commands.append("%s%s %s" % ["M" if i==0 else "L",str(float(contour[i])+PADDING),str(float(contour[i+1])+PADDING)])
		paths.append(" ".join(commands)+" Z")
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><path fill="white" fill-rule="evenodd" d="%s"/></svg>' % [width,height," ".join(paths)]
	var image := Image.new()
	var error := image.load_svg_from_string(svg)
	if error!=OK:
		push_error("Cannot rasterize interactive region: "+id)
		return {}
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var c: Array = region.color
	material.set_shader_parameter("glow_color",Color(c[0],c[1],c[2],1))
	material.set_shader_parameter("alpha_min",float(region.alpha_min))
	material.set_shader_parameter("alpha_max",float(region.alpha_max))
	cache[id] = {"texture":ImageTexture.create_from_image(image),"material":material,
		"hit_image":image.get_region(Rect2i(PADDING,PADDING,int(region.size[0]),int(region.size[1])))}
	return cache[id]

func configure(part: Dictionary) -> void:
	region_id = part.region
	var shared: Dictionary = build_region(region_id)
	texture = shared.texture
	material = shared.material
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect: Array = part.rect
	position = Vector2(rect[0],rect[1])*2-Vector2.ONE*PADDING
	size = Vector2(rect[2],rect[3])*2+Vector2.ONE*PADDING*2
	set_meta("interactive_highlight",true)
