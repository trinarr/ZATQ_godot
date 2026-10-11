extends "res://scripts/ui/shared/shared_view.gd"
signal choice_selected(index: int)
signal confirmed
signal restart_requested
signal menu_requested
var answers: Array[Button] = []
var next_button: Button
func configure(state: RefCounted) -> void:
	_art("tests_question")
	var rect := Rect2(132.55,58.95,618.4,81.25)
	var question_label := _text(state.question().text,rect)
	question_label.name = "TestQuestion"
	question_label.add_theme_font_override("font",NARRATIVE_FONT)
	var pixels := 41
	var text := LOC.text(state.question().text)
	while pixels > 24:
		var measured := NARRATIVE_FONT.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x*2,pixels)
		var lines := maxi(1,roundi(measured.y/NARRATIVE_FONT.get_height(pixels)))
		if measured.y+get_theme_constant("line_spacing","Label")*(lines-1) <= rect.size.y*2: break
		pixels -= 1
	question_label.add_theme_font_size_override("font_size",pixels)
	OPTICAL.center(question_label,LAYOUT.scaled_rect(rect))
	var count := LOC.text("@loc:tests.ui.question" if state.test_id==1 else "@loc:tests.ui.question_of").format({"number":state.question_id,"total":state.spec().questions.size()})
	_centered_text(count,Rect2(583.95,142,167,26),16,false,true).name = "TestProgress"
	var options: Array = state.question().options
	for index: int in options.size():
		var id := int(options[index].id)
		var column := 0 if id <= 4 else 1
		var row := (id-1)%4
		var wide: bool = state.test_id != 1 and options.size() <= 4
		if options.size() > 4 and id <= 4:
			wide = not options.any(func(option: Dictionary): return int(option.id)==id+4)
		var button := preload("res://scripts/ui/shared/quiz_answer_button.gd").new()
		button.position = Vector2(114 if column==0 else 444,178+row*66)*2
		button.size = Vector2(648 if wide else 318,62)*2
		add_child(button)
		button.configure(LOC.text(options[index].text))
		button.set_selected(state.selected==index)
		button.pressed.connect(func():
			choice_selected.emit(index)
			for i: int in answers.size(): answers[i].set_selected(i==index)
			next_button.disabled = false)
		answers.append(button)
	var menu := _navigation("menu",Rect2(25,48,65,58),func(): menu_requested.emit())
	menu.tooltip_text = LOC.text("@loc:tests.ui.menu")
	var restart := _navigation("restart",Rect2(25,125,65,58),func(): restart_requested.emit())
	restart.tooltip_text = LOC.text("@loc:tests.ui.restart")
	restart.disabled = state.answered == 0
	next_button = _navigation("continue",Rect2(25,364,65,58),func(): confirmed.emit())
	next_button.tooltip_text = LOC.text("@loc:tests.ui.continue")
	next_button.disabled = state.selected < 0
func _navigation(icon: String, area: Rect2, action: Callable) -> Button:
	var button := TORN_ICON.new()
	button.position = area.position*2
	button.size = area.size*2
	button.icon_texture = load("res://assets/flash_ui/tests_"+icon+"_icon.png")
	button.set_palette(Color("353535"))
	button.pressed.connect(action)
	add_child(button)
	return button
