extends Control
# Reusable Flash view primitives; no dependency on Main or Quest.
const LOC := preload("res://scripts/core/localization.gd")
const BRUSH := preload("res://scripts/ui/torn_brush.gd")
const ALPHA_HOTSPOT := preload("res://scripts/ui/alpha_hotspot.gd")
const LAYOUT := preload("res://scripts/ui/landscape_stage_layout.gd")
const COMPONENTS := preload("res://scripts/ui/flash_components.gd")

const TITLE_FONT: Font = preload("res://fonts/flash/font_1.ttf")

const BODY_FONT: Font = preload("res://fonts/flash/font_2.ttf")

static var catalog: Dictionary = {}
var art_text: Dictionary
var art_brushes: Dictionary
var art_components: Dictionary
var episode_components: Dictionary

func _init() -> void:
	if catalog.is_empty():
		catalog.text = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_text_layout.json"))
		catalog.components = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_components.json"))
		catalog.brushes = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_brush_layout.json"))
		catalog.episodes = {}
		for number: int in range(1,4):
			catalog.episodes.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/episode%d_components.json" % number)),true)
			catalog.brushes.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/episode%d_brushes.json" % number)),true)
	art_text = catalog.text
	art_components = catalog.components
	art_brushes = catalog.brushes
	episode_components = catalog.episodes

func _default_parent() -> Control:
	return self

func _art(filename: String, parent: Control = null, rect: Rect2 = Rect2(0,0,800,480)) -> Control:
	if filename in ["menu", "menu_off", "help"] or filename.begins_with("selector_"):
		filename = "adaptive_" + filename
	rect = LAYOUT.scaled_rect(rect)
	var composed: bool = art_components.has(filename) or episode_components.has(filename)
	var image: Control = Control.new() if composed else TextureRect.new()
	if not composed:
		(image as TextureRect).texture = load("res://assets/flash_ui/" + filename + ".png")
		(image as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.position = rect.position
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else _default_parent()).add_child(image)
	image.set_deferred("size",rect.size)
	if art_components.has(filename): _draw_components(filename,image,"background")
	elif episode_components.has(filename): COMPONENTS.draw(image,episode_components[filename],"background")
	_draw_brushes(filename,image)
	if art_components.has(filename): _draw_components(filename,image,"foreground")
	elif episode_components.has(filename): COMPONENTS.draw(image,episode_components[filename],"foreground")
	var icons_path:="res://assets/flash_ui/"+filename+"_icons.png"
	if not composed and ResourceLoader.exists(icons_path):
		var icons:=TextureRect.new()
		icons.texture=load(icons_path)
		icons.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icons.size=rect.size
		icons.mouse_filter=Control.MOUSE_FILTER_IGNORE
		image.add_child(icons)
	for block: Dictionary in art_text.get(filename,[]):
		var r: Array = block.rect
		var original_rect := Rect2(r[0],r[1],r[2],r[3])
		var translated := LOC.text(block.text).replace("{version}",str(ProjectSettings.get_setting("application/config/version","")))
		var font: Font = load("res://fonts/flash/font_%d.ttf" % int(block.font))
		var brush_rect := Rect2()
		for brush:Dictionary in art_brushes.get(filename,[]):
			var b:Array=brush.rect
			var area:=Rect2(b[0],b[1],b[2],b[3])
			if area.has_point(original_rect.get_center()):brush_rect=area;break
		var label:Label
		if brush_rect.has_area():
			label=_button_text(translated,brush_rect.grow_individual(-10,-4,-10,-4),roundi(block.size),image,font)
		else:
			var font_size:=roundi(block.size)
			while font_size>12 and font.get_multiline_string_size(translated,HORIZONTAL_ALIGNMENT_LEFT,original_rect.size.x*2,font_size*2).y>original_rect.size.y*2+4:font_size-=1
			label=_text(translated,original_rect,font_size,false,false,image)
		label.rotation = float(block.get("rotation",0))
		label.add_theme_font_override("font",font)
		label.add_theme_color_override("font_color",Color(block.color))
		if not label.has_meta("button_caption"):label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if block.alignment=="center" else HORIZONTAL_ALIGNMENT_RIGHT if block.alignment=="right" else HORIZONTAL_ALIGNMENT_LEFT
	return image

func _text(text: String, rect: Rect2, font_size: int = 24, title: bool = false, center: bool = false, parent: Control = null) -> Label:
	rect = LAYOUT.scaled_rect(rect)
	font_size = LAYOUT.scaled_font_size(font_size)
	var label := Label.new()
	label.text = LOC.text(text)
	label.position = rect.position
	label.add_theme_font_override("font", TITLE_FONT if title else BODY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e1e1e1"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else _default_parent()).add_child(label)
	label.set_deferred("size",rect.size)
	return label

func _hit(name: String, rect: Rect2, action: Callable, parent: Control = null, mask: String = "") -> Button:
	rect = LAYOUT.scaled_rect(rect)
	var button: Button = Button.new() if mask.is_empty() else ALPHA_HOTSPOT.new()
	if not mask.is_empty():
		button.hit_image = load("res://assets/flash_ui/" + mask + ".png").get_image()
		if button.hit_image.is_compressed(): button.hit_image.decompress()
	name = LOC.text(name)
	button.name = name
	button.position = rect.position
	button.size = rect.size
	button.flat = true
	button.tooltip_text = name
	var empty := StyleBoxEmpty.new()
	for style in ["normal","hover","pressed","focus","disabled"]:
		button.add_theme_stylebox_override(style,empty)
	button.pressed.connect(action)
	(parent if parent != null else _default_parent()).add_child(button)
	return button

func _brush(rect:Rect2,parent:Control=null,color:Color=Color("803c3c"),seed_value:float=1.0)->Control:
	var brush:=BRUSH.new()
	brush.position=rect.position*2
	brush.size=rect.size*2
	brush.brush_color=color
	brush.brush_seed=seed_value
	(parent if parent!=null else _default_parent()).add_child(brush)
	return brush

func _draw_brushes(filename:String,parent:Control,behind:bool=false)->void:
	var index:=0
	for record:Dictionary in art_brushes.get(filename,[]):
		var r:Array=record.rect
		var c:Array=record.color
		var brush:=_brush(Rect2(r[0],r[1],r[2],r[3]),parent,Color(c[0],c[1],c[2],c[3]),float(index+1))
		brush.rotation=float(record.get("rotation",0))
		if behind:brush.show_behind_parent=true
		index+=1

func _button_text(value:String,rect:Rect2,font_size:int=22,parent:Control=null,font:Font=null)->Label:
	var text:=" ".join(LOC.text(value).replace("\r"," ").replace("\n"," ").split(" ",false))
	if font==null:font=BODY_FONT
	while font_size>1 and (font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size*2).x>rect.size.x*2 or font.get_height(font_size*2)>rect.size.y*2):font_size-=1
	var label:=_text(text,rect,font_size,false,true,parent)
	label.add_theme_font_override("font",font)
	label.autowrap_mode=TextServer.AUTOWRAP_OFF
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.clip_text=true
	label.set_meta("button_caption",true)
	return label

func _draw_components(filename: String, parent: Control, layer: String) -> void:
	for part: Dictionary in art_components[filename]:
		if part.layer != layer: continue
		var component := TextureRect.new()
		component.texture = load("res://assets/flash_ui/" + part.texture)
		var r: Array = part.rect
		component.position = Vector2(r[0], r[1]) * 2
		component.size = Vector2(r[2], r[3]) * 2
		component.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(component)
