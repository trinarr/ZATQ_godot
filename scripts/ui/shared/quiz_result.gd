extends "res://scripts/ui/shared/metal_popup.gd"
signal restart_requested
signal menu_requested
func configure(result: Dictionary) -> void:
	add_shade(0.9)
	draw_metal_body(BODY_RECT)
	draw_metal_header("@loc:tests.ui.result").name = "TestResultTitle"
	var value := LOC.text(result.label)
	draw_metal_subtitle(LOC.text("@loc:tests.ui.outcome").format({"value":value}),"TestResultOutcome")
	var symbol := "result_alive" if int(result.result_id) in [18,22,25,27,29,30,31,32] else "result_dead"
	var numeric: bool = int(result.result_id) in [50,100,150]
	if numeric:
		_centered_text(value,Rect2(68,180,124,90),30,false,true).name = "TestResultValue"
	else:
		for part: Dictionary in episode_components[symbol]:
			if str(part.get("source","")).begins_with("Mov.Rezt.Symb/"):
				var copy := part.duplicate(true)
				copy.rect = [120-float(part.rect[2])*0.5,205,part.rect[2],part.rect[3]]
				COMPONENTS.draw(self,[copy])
	var text := LOC.text(result.text)
	var story := _text(text,Rect2(205,123,490,99))
	story.name = "TestResultStory"
	story.add_theme_font_override("font",NARRATIVE_FONT)
	_fit_text(story,Rect2(205,123,490,99))
	var advice_title := "@loc:tests.ui.analog" if result.get("analog",false) else "@loc:tests.ui.advice"
	_centered_text(advice_title,Rect2(205,226,490,26),18).name = "TestAdviceTitle"
	var advice := _text(result.advice,Rect2(205,259,490,64))
	advice.name = "TestAdvice"
	advice.add_theme_font_override("font",NARRATIVE_FONT)
	_fit_text(advice,Rect2(205,259,490,64))
	# The same action positions and art as the episode result panel.
	var actions: Array = episode_components.result_dead.filter(func(part: Dictionary): return part.get("source","") in ["Mov/Symbol 10","Mov/Symbol 14"])
	for part: Dictionary in actions:
		part = part.duplicate(true)
		part.rect[0] += 4
		part.rect[1] -= 30
		COMPONENTS.draw(self,[part])
	var brush_start := get_child_count()
	_draw_brushes("result_dead",self)
	for i: int in range(brush_start,get_child_count()): get_child(i).position += Vector2(8,-60)
	_adopt_button_icons(self)
	_hit("@loc:tests.ui.restart",Rect2(597,330,73,70),func(): restart_requested.emit())
	_hit("@loc:tests.ui.menu",Rect2(672,330,73,70),func(): menu_requested.emit())
func _fit_text(label: Label, area: Rect2) -> void:
	var pixels := 41
	while pixels > 24:
		var measured := NARRATIVE_FONT.get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,area.size.x*2,pixels)
		var lines := maxi(1,roundi(measured.y/NARRATIVE_FONT.get_height(pixels)))
		if measured.y+get_theme_constant("line_spacing","Label")*(lines-1) <= area.size.y*2: break
		pixels -= 1
	label.add_theme_font_size_override("font_size",pixels)
	OPTICAL.center(label,LAYOUT.scaled_rect(area))
