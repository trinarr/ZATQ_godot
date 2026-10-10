extends Control
# Reusable Flash view primitives; no dependency on Main or Quest.
const LOC := preload("res://scripts/core/localization.gd")
const TORN_TEXT := preload("res://scripts/ui/shared/torn_text_button.gd")
const TORN_ICON := preload("res://scripts/ui/shared/torn_icon_button.gd")
const ALPHA_HOTSPOT := preload("res://scripts/ui/alpha_hotspot.gd")
const LAYOUT := preload("res://scripts/ui/landscape_stage_layout.gd")
const STATISTIC_ICON := preload("res://scripts/ui/statistic_icon.gd")
const COMPONENTS := preload("res://scripts/ui/flash_components.gd")

const TITLE_FONT: Font = preload("res://fonts/oswald/Oswald-Medium.ttf")

const BODY_FONT: Font = preload("res://fonts/oswald/Oswald-Medium.ttf")
const NARRATIVE_FONT: Font = preload("res://fonts/oswald/Oswald-Light.ttf")

static var catalog: Dictionary = {}
static var raster_masks: Dictionary = {}
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
		for filename: String in DirAccess.get_files_at("res://data"):
			if not filename.begins_with("episode") or not filename.ends_with("_components.json"): continue
			catalog.episodes.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/"+filename)),true)
			var brushes_path: String = "res://data/"+filename.replace("_components.json","_brushes.json")
			if FileAccess.file_exists(brushes_path):catalog.brushes.merge(JSON.parse_string(FileAccess.get_file_as_string(brushes_path)),true)

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
		icons.set_meta("button_icon_sheet",true)
		image.add_child(icons)
	for block: Dictionary in art_text.get(filename,[]):
		var r: Array = block.rect
		var original_rect := Rect2(r[0],r[1],r[2],r[3])
		var translated := LOC.text(block.text).replace("{version}",str(ProjectSettings.get_setting("application/config/version","")))
		if int(block.font)==1: translated=translated.to_upper()
		var font: Font = preload("res://fonts/caveat/Caveat-Medium.ttf") if int(block.font) in [2508,2511] else TITLE_FONT if int(block.font)==1 else BODY_FONT if int(block.font)==2 else preload("res://fonts/dseg/DSEG7Classic-Regular.ttf") if int(block.font)==2836 else load("res://fonts/flash/font_%d.ttf" % int(block.font))
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
		label.distressed = int(block.font)==1
		label.rotation = float(block.get("rotation",0))
		label.add_theme_font_override("font",font)
		label.add_theme_color_override("font_color",Color(block.color))
		if not label.has_meta("button_caption"):label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if block.alignment=="center" else HORIZONTAL_ALIGNMENT_RIGHT if block.alignment=="right" else HORIZONTAL_ALIGNMENT_LEFT
	_adopt_button_icons(image)
	return image

func _text(text: String, rect: Rect2, font_size: int = 24, title: bool = false, center: bool = false, parent: Control = null) -> Label:
	rect = LAYOUT.scaled_rect(rect)
	font_size = LAYOUT.scaled_font_size(font_size)
	var label := preload("res://scripts/ui/shared/shader_text.gd").new()
	label.distressed = title
	label.text = LOC.text(text).to_upper() if title else LOC.text(text)
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
	var host: Control = parent if parent != null else _default_parent()
	var painted: Button = _find_painted_button(host,rect)
	if painted != null:
		if painted.get_parent()!=host: painted.reparent(host,true)
		painted.name = LOC.text(name)
		painted.tooltip_text = LOC.text(name)
		painted.mouse_filter = Control.MOUSE_FILTER_STOP
		painted.focus_mode = Control.FOCUS_ALL
		painted.set_meta("bound_action",true)
		painted.pressed.connect(func(): _dispatch_action(painted,action))
		return painted
	var button: Button = Button.new() if mask.is_empty() else ALPHA_HOTSPOT.new()
	if not mask.is_empty():
		if COMPONENTS.HIGHLIGHT.has_mask(mask):
			button.hit_image = COMPONENTS.HIGHLIGHT.mask_image(mask)
		else:
			if not raster_masks.has(mask):
				var image: Image = load("res://assets/flash_ui/" + mask + ".png").get_image()
				if image.is_compressed(): image.decompress()
				raster_masks[mask] = image
			button.hit_image = raster_masks[mask]
	name = LOC.text(name)
	button.name = name
	button.position = rect.position
	button.size = rect.size
	button.flat = true
	button.tooltip_text = name
	var empty := StyleBoxEmpty.new()
	for style in ["normal","hover","pressed","focus","disabled"]:
		button.add_theme_stylebox_override(style,empty)
	button.pressed.connect(func(): _dispatch_action(button,action))
	(parent if parent != null else _default_parent()).add_child(button)
	return button

func _dispatch_action(button: Control, action: Callable) -> void:
	if _interaction_allowed(button): action.call()

func _interaction_allowed(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_inside_tree(): return false
	var ancestor: Node = control
	while ancestor != null:
		if ancestor.is_queued_for_deletion() or ancestor.get_meta("episode_animation_block",false): return false
		var top: Control
		for sibling: Node in ancestor.get_children():
			if sibling is Control and sibling.has_meta("modal_view") and sibling.is_visible_in_tree() and not sibling.is_queued_for_deletion(): top = sibling
		if top != null and top != control and not top.is_ancestor_of(control): return false
		ancestor = ancestor.get_parent()
	return true

func _draw_brushes(filename:String,parent:Control,behind:bool=false)->void:
	var index:=0
	for record:Dictionary in art_brushes.get(filename,[]):
		var r:Array=record.rect
		var c:Array=record.color
		var brush: Button = TORN_ICON.new() if absf(float(r[2])-float(r[3]))<1 else TORN_TEXT.new()
		brush.position = Vector2(r[0],r[1])*2
		brush.size = Vector2(r[2],r[3])*2
		brush.mouse_filter = Control.MOUSE_FILTER_IGNORE
		brush.focus_mode = Control.FOCUS_NONE
		brush.set_palette(Color(c[0],c[1],c[2],c[3]),float(index+1))
		parent.add_child(brush)
		brush.rotation=float(record.get("rotation",0))
		if behind:brush.show_behind_parent=true
		index+=1

func _button_text(value:String,rect:Rect2,font_size:int=22,parent:Control=null,font:Font=null)->Label:
	var host: Control = parent if parent != null else _default_parent()
	var painted: Button = _find_painted_button(host,LAYOUT.scaled_rect(rect))
	if painted != null and painted.get_script()==TORN_TEXT:
		painted.caption.uppercase=false
		painted.set_caption(value,font if font!=null else BODY_FONT,font_size*2)
		return painted.caption
	var text:=" ".join(LOC.text(value).replace("\r"," ").replace("\n"," ").split(" ",false))
	if font==null:font=BODY_FONT
	while font_size>1 and (font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size*2).x>rect.size.x*2 or font.get_height(font_size*2)>rect.size.y*2):font_size-=1
	var label:=_text(text,rect,font_size,false,true,parent)
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",maxi(1,roundi(font_size*2*0.85)))
	label.autowrap_mode=TextServer.AUTOWRAP_OFF
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.clip_text=true
	label.set_meta("button_caption",true)
	return label

func _torn_text_button(value: String, rect: Rect2, action: Callable, parent: Control = null, font: Font = TITLE_FONT, font_size: int = 20) -> Button:
	var button := TORN_TEXT.new()
	button.position = rect.position*2
	button.size = rect.size*2
	button.name = LOC.text(value)
	button.tooltip_text = LOC.text(value)
	button.set_meta("bound_action",true)
	button.set_caption(value,font,font_size*2)
	button.pressed.connect(func(): _dispatch_action(button,action))
	(parent if parent!=null else _default_parent()).add_child(button)
	return button

func _find_painted_button(parent: Control, rect: Rect2) -> Button:
	var point := parent.get_global_transform()*rect.get_center()
	return _find_painted_at(parent,point,rect.size*parent.get_global_transform().get_scale().abs())

func _find_painted_at(parent: Control, point: Vector2, requested: Vector2) -> Button:
	for child: Node in parent.get_children():
		if child is Button and child.has_meta("torn_button") and not child.get_meta("bound_action",false):
			var area: Rect2 = child.get_global_rect()
			if area.has_point(point) and requested.x<=area.size.x*1.5 and requested.y<=area.size.y*1.5: return child
		elif child is Control and not child is Button and not child.has_meta("modal_view"):
			var found := _find_painted_at(child,point,requested)
			if found != null: return found
	return null

func _adopt_button_icons(parent: Control) -> void:
	for image: Node in parent.get_children():
		if not image is TextureRect: continue
		if image.has_meta("button_icon_sheet"):
			# Legacy help icons share one transparent sheet. Atlas regions reuse it
			# without copying pixels or leaving a second overlay above the buttons.
			for button: Node in parent.get_children():
				if button.get_script()!=TORN_ICON: continue
				var atlas := AtlasTexture.new()
				atlas.atlas = image.texture
				atlas.region = Rect2((button.position-image.position)/image.size*image.texture.get_size(),button.size/image.size*image.texture.get_size())
				var icon := TextureRect.new()
				icon.texture = atlas
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.position = button.position
				icon.size = button.size
				parent.add_child(icon)
				button.add_icon(icon)
			parent.remove_child(image)
			image.queue_free()
			continue
		for button: Node in parent.get_children():
			if button.get_script()==TORN_ICON and button.get_rect().encloses(image.get_rect()):
				button.add_icon(image)
				break

func _draw_components(filename: String, parent: Control, layer: String) -> void:
	for part: Dictionary in art_components[filename]:
		if part.layer != layer: continue
		if part.get("type","texture") != "texture":
			COMPONENTS.draw(parent,[part],layer)
			continue
		var component: TextureRect = STATISTIC_ICON.new() if part.get("style","")=="statistics_icon" else TextureRect.new()
		component.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		component.texture = load("res://assets/flash_ui/" + part.texture)
		component.set_meta("flash_source",part.source)
		var r: Array = part.rect
		component.position = Vector2(r[0], r[1]) * 2
		component.size = Vector2(r[2], r[3]) * 2
		component.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(component)
