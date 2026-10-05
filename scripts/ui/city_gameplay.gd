extends RefCounted
# Coordinates use the original Flash frame; Main applies the uniform 2x scale.
static func draw(ui: Control, node: Dictionary) -> void:
	var artwork: String = node.get("art", "")
	if Quest.flags.Auto == 0: artwork = node.get("art_on_foot", artwork)
	ui._art(artwork)
	var kind: String = node.kind
	if kind == "city_decision":
		ui._shade(ui.screen, 0.6)
		ui._art("city_decision_3" if node.choices.size() == 3 else "decision")
		var body_size: int = 24
		while body_size > 16 and ui.BODY_FONT.get_multiline_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, 280, body_size).y > 235:
			body_size -= 1
		ui._text(node.text, Rect2(430,72,280,235),body_size)
		for i in node.choices.size():
			var index: int = i
			ui._text(node.choices[i].text, Rect2(66,66+i*65,337,50),22,false,true)
			ui._hit(node.choices[i].text, Rect2(60,54+i*65,349,64),func(): ui._choose(index))
		for rect in [Rect2(0,0,800,35),Rect2(0,35,45,310),Rect2(730,35,70,310),Rect2(0,345,800,135)]:
			ui._hit("Закрыть выбор",rect,func(): Quest._enter(node.back))
	elif kind == "city_death":
		ui._text("Итог: погиб",Rect2(73,75,652,30),24,true)
		ui._text(node.text,Rect2(162,112,549,230),24)
		ui._hit("Начать заново",Rect2(590,355,73,70),ui._start)
		ui._hit("В меню",Rect2(665,355,73,70),ui._show_menu)
		ui._text("Сначала",Rect2(566,431,120,27),18,false,true)
		ui._text("В меню",Rect2(674,431,100,27),18,false,true)
	elif kind == "city_cutscene":
		var duration: float = node.auto_seconds
		ui.cutscene.start(duration)
		ui.cutscene_tween = ui.create_tween().bind_node(ui.screen)
		ui.cutscene_tween.tween_property(ui.screen,"modulate:a",0.0,duration)
	else:
		if node.has("text_rect"):
			var panel: Array = node.panel_rect
			var shade := ColorRect.new()
			var rect: Rect2 = ui.LAYOUT.scaled_rect(Rect2(panel[0],panel[1],panel[2],panel[3]))
			shade.position = rect.position
			shade.size = rect.size
			shade.color = Color.BLACK
			shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ui.screen.add_child(shade)
			var box: Array = node.text_rect
			var font_size: int = 24
			while font_size > 15 and ui.BODY_FONT.get_multiline_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,box[2],font_size).y > box[3]:
				font_size -= 1
			ui._text(node.text,Rect2(box[0],box[1],box[2],box[3]),font_size)
		for i in node.choices.size():
			var index: int = i
			var r: Array = node.choices[i].get("rect",[70,0,730,480])
			ui._hit(node.choices[i].text,Rect2(r[0],r[1],r[2],r[3]),func(): ui._choose(index))
	if kind not in ["city_decision", "city_death"]: ui._hit("Пауза",Rect2(0,5,60,123),ui._show_pause)
