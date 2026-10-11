extends "res://scripts/ui/shared/metal_popup.gd"
signal restart_requested
signal menu_requested
signal next_episode_requested
func configure(data: Dictionary, stats: Dictionary, ending_count: int, has_next_episode: bool) -> void:
	add_shade(0.9)
	# The original ResultBad body is bounded, like AddItem; it is not a backdrop.
	draw_metal_body(BODY_RECT)
	var alive: bool = data.kind == "city_ending"
	var artwork := "result_alive" if alive else "result_dead"
	var icon: Dictionary
	for part: Dictionary in episode_components[artwork]:
		if str(part.get("source","")).begins_with("Mov.Rezt.Symb/"): icon = part.duplicate(true)
	var content: Array = episode_components[artwork].filter(func(part: Dictionary): return part.get("source","") not in ["/Symbol 57","Mov.Rezt/Symbol 49"] and part.get("decoration","") != "result_strip" and not str(part.get("source","")).begins_with("Mov.Rezt.Symb/"))
	content = content.duplicate(true)
	for part: Dictionary in content:
		part.rect[0] += 4
		part.rect[1] -= 30
	COMPONENTS.draw(self,content,"background")
	var brush_start := get_child_count()
	_draw_brushes(artwork,self)
	for i: int in range(brush_start,get_child_count()):
		get_child(i).position += Vector2(8,-60)
	COMPONENTS.draw(self,content,"foreground")
	_adopt_button_icons(self)
	var title := draw_metal_header("@loc:ui.art.result_alive.0")
	title.name = "ResultTitle"
	draw_metal_subtitle("@loc:ui.result_screen.1" if alive else "@loc:ui.result_screen.2","ResultOutcome")
	var value := "%d/%d" % [stats.endings.size(),ending_count] if alive else str(stats.losses)
	var bounds := OPTICAL.ink(BODY_FONT,66,value)
	var count_height := (bounds.y-bounds.x)*0.5
	var icon_height: float = icon.rect[3]
	var group_height := icon_height+8+count_height
	# Center the complete visible stack between the subtitle and action row.
	var area_center := (SUBTITLE_RECT.end.y+330)*0.5
	var statistics := Control.new()
	statistics.name = "ResultStatistics"
	statistics.position = Vector2(80,area_center-group_height*0.5)*2
	statistics.size = Vector2(81,group_height)*2
	statistics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(statistics)
	icon.rect = [(81-float(icon.rect[2]))*0.5,0,icon.rect[2],icon_height]
	COMPONENTS.draw(statistics,[icon])
	statistics.get_child(0).name = "ResultIcon"
	var count := _centered_text(value,Rect2(0,icon_height+8,81,count_height),33,false,true,statistics)
	count.name = "ResultCount"
	var font_size := 22
	while font_size > 12 and BODY_FONT.get_multiline_string_size(data.text,HORIZONTAL_ALIGNMENT_LEFT,534.45*2,font_size*2).y > 166*2:
		font_size -= 1
	var body := _text(data.text,Rect2(166.05,144,534.45,166),font_size)
	body.name = "ResultStory"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
	body.justification_flags = TextServer.JUSTIFICATION_WORD_BOUND | TextServer.JUSTIFICATION_SKIP_LAST_LINE
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hit("@loc:ui.result_screen.3",Rect2(597,330,73,70),func(): restart_requested.emit())
	_hit("@loc:ui.result_screen.4",Rect2(672,330,73,70),func(): menu_requested.emit())
	if alive and has_next_episode:
		var next_button := _art("ep2_continue_button")
		next_button.position += Vector2(8,-60)
		_hit("@loc:ui.result_screen.5",Rect2(71,330,73,70),func(): next_episode_requested.emit())
