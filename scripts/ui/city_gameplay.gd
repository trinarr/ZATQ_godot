extends RefCounted
const LOC := preload("res://scripts/core/localization.gd")
const RESULT := preload("res://scripts/ui/result_screen.gd")
# Coordinates use the original Flash frame; Main applies the uniform 2x scale.
static func draw(ui: Control, node: Dictionary) -> void:
	var artwork: String = node.get("art", "")
	var story_text: String = node.get("text", "")
	var choices: Array = Quest.available_choices()
	if Quest.flags.Auto == 0: artwork = node.get("art_on_foot", artwork)
	if Quest.flags.Auto == 0: story_text = node.get("text_on_foot", story_text)
	if node.kind in ["city_death", "city_ending"]:
		RESULT.draw(ui,node)
		return
	if node.kind == "city_pickup":
		if not ui._component_backdrop(node.background_art):
			ui._set_backdrop(load("res://assets/flash_ui/"+node.background_art+".png"))
		ui._shade(ui.screen,0.65)
		ui._art(artwork)
		ui._text(node.text,Rect2(102,71,594,31),24,false,true)
		ui._hit(LOC.text("@loc:ui.city_gameplay.1"),Rect2(656,326,65,58),func(): ui._choose(0))
		return
	if not ui._component_backdrop(artwork):
		ui._set_backdrop(load("res://assets/flash_ui/" + artwork + "."+node.get("art_extension","png")), not node.get("clean_background",false))
	if Quest.current_id == "metro_junction":
		ui._component_backdrop("adaptive_metro_background")
		ui._art("adaptive_metro_controls")
	if node.has("controls_art"):
		ui._art(node.controls_art)
	var kind: String = node.kind
	if kind == "city_decision":
		ui._shade(ui.screen, 0.6)
		ui._art(node.get("decision_art", "city_decision_3" if choices.size() == 3 else "decision"))
		var body_size: int = 24
		while body_size > 16 and ui.BODY_FONT.get_multiline_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, 280, body_size).y > 235:
			body_size -= 1
		ui._text(node.text, Rect2(430,72,280,235),body_size)
		for i in choices.size():
			var index: int = i
			ui._button_text(choices[i].text, Rect2(66,66+i*65,337,50),22)
			ui._hit(choices[i].text, Rect2(60,54+i*65,349,64),func(): ui._choose(index))
		for rect in [Rect2(0,0,800,35),Rect2(0,35,45,310),Rect2(730,35,70,310),Rect2(0,345,800,135)]:
			ui._hit(LOC.text("@loc:ui.city_gameplay.2"),rect,func(): Quest._enter(node.back))
	elif kind == "city_cutscene":
		var duration: float = node.auto_seconds
		ui.cutscene.start(duration)
		ui.cutscene_tween = ui.create_tween().bind_node(ui.screen)
		ui.cutscene_tween.tween_property(ui.screen,"modulate:a",0.0,duration)
		ui.cutscene_tween.parallel().tween_property(ui.viewport_canvas.background,"modulate:a",0.0,duration)
	else:
		for block: Dictionary in node.get("blocks",[]):
			var b: Array = block.rect.duplicate()
			if "Hist" in block.get("path", ""):
				var band := ColorRect.new()
				band.position = Vector2(-ui.screen.position.x/ui.screen.scale.x, maxf(0,b[1]-6)*2)
				band.size = Vector2(ui.viewport_canvas.safe_layer.size.x/ui.screen.scale.x,(b[3]+12)*2)
				band.color = Color.BLACK
				band.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ui.screen.add_child(band)
			if b[1] < 128 and b[0] < 70:
				b[2] -= 70 - b[0]
				b[0] = 70
			var block_font: Font = ui.BODY_FONT
			if block.font in ["SegoeScript", "Segoe Script"]:
				block_font = load("res://fonts/flash/font_2508.ttf")
			elif block.font == "B52 Regular":
				block_font = load("res://fonts/flash/font_2511.ttf")
			var block_size: int = block.size
			while block_size > 14 and block_font.get_multiline_string_size(block.text,HORIZONTAL_ALIGNMENT_LEFT,b[2]*2,block_size*2).y > b[3]*2-4:
				block_size -= 1
			var label: Label = ui._text(block.text,Rect2(b[0],b[1],b[2],b[3]),block_size)
			label.add_theme_font_override("font",block_font)
			label.add_theme_constant_override("line_spacing",0)
		if node.has("text_rect"):
			var panel: Array = node.panel_rect
			if Quest.flags.Auto == 0: panel = node.get("panel_rect_on_foot",panel)
			var shade := ColorRect.new()
			var rect: Rect2 = ui.LAYOUT.scaled_rect(Rect2(panel[0],panel[1],panel[2],panel[3]))
			shade.position = Vector2(-ui.screen.position.x/ui.screen.scale.x,rect.position.y)
			shade.size = Vector2(ui.viewport_canvas.safe_layer.size.x/ui.screen.scale.x,rect.size.y)
			shade.color = Color.BLACK
			shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ui.screen.add_child(shade)
			var box: Array = node.text_rect.duplicate()
			if Quest.flags.Auto == 0: box = node.get("text_rect_on_foot",box).duplicate()
			if box[1] < 128 and box[0] < 70:
				box[2] -= 70 - box[0]
				box[0] = 70
			var font_size: int = 24
			while font_size > 15 and ui.BODY_FONT.get_multiline_string_size(story_text,HORIZONTAL_ALIGNMENT_LEFT,box[2],font_size).y > box[3]:
				font_size -= 1
			ui._text(story_text,Rect2(box[0],box[1],box[2],box[3]),font_size)
		for i in choices.size():
			var index: int = i
			var r: Array = choices[i].get("rect",[70,0,730,480])
			ui._hit(choices[i].text,Rect2(r[0],r[1],r[2],r[3]),func(): ui._choose(index),null,choices[i].get("mask",""))
	if kind not in ["city_decision", "city_death", "city_ending"]:
		ui._edge_tab(LOC.text("@loc:ui.city_gameplay.3"),ui._show_pause)
