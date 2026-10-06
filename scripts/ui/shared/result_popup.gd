extends "res://scripts/ui/shared/metal_popup.gd"
signal restart_requested
signal menu_requested
signal next_episode_requested
func configure(data: Dictionary, stats: Dictionary, ending_count: int, has_next_episode: bool) -> void:
	add_shade(0.9)
	# The original ResultBad body is bounded, like AddItem; it is not a backdrop.
	draw_metal_body(Rect2(36,60,729,394))
	var alive: bool = data.kind == "city_ending"
	var artwork := "result_alive" if alive else "result_dead"
	var content: Array = episode_components[artwork].filter(func(part: Dictionary): return part.get("source","") != "/Symbol 57")
	COMPONENTS.draw(self,content,"background")
	_draw_brushes(artwork,self)
	COMPONENTS.draw(self,content,"foreground")
	_adopt_button_icons(self)
	var title := draw_metal_header("@loc:ui.art.result_alive.0",Rect2(40.9,17,716.15,29.2),true,36)
	title.name = "ResultTitle"
	var outcome := _text("@loc:ui.result_screen.1" if alive else "@loc:ui.result_screen.2",Rect2(73.05,75,652.95,28.2),25,false,true)
	outcome.name = "ResultOutcome"
	var count := _text("%d/%d" % [stats.endings.size(),ending_count] if alive else str(stats.losses),Rect2(76,219,81,36.8),33,false,true)
	count.name = "ResultCount"
	var font_size := 22
	while font_size > 12 and BODY_FONT.get_multiline_string_size(data.text,HORIZONTAL_ALIGNMENT_LEFT,548.95*2,font_size*2).y > 230*2:
		font_size -= 1
	var body := _text(data.text,Rect2(162.05,112,548.95,230),font_size)
	body.name = "ResultStory"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
	body.justification_flags = TextServer.JUSTIFICATION_WORD_BOUND | TextServer.JUSTIFICATION_SKIP_LAST_LINE
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hit("@loc:ui.result_screen.3",Rect2(593,360,73,70),func(): restart_requested.emit())
	_hit("@loc:ui.result_screen.4",Rect2(668,360,73,70),func(): menu_requested.emit())
	if alive and has_next_episode:
		_art("ep2_continue_button")
		_hit("@loc:ui.result_screen.5",Rect2(67,360,73,70),func(): next_episode_requested.emit())
