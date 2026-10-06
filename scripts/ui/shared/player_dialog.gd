extends "res://scripts/ui/shared/modal_view.gd"
signal choice_selected(index: int)
signal dismissed
var choice_buttons: Array[Button] = []
var backdrop: Control

# Decision, confirmation and speaker layouts share one component and API.
# choices contain text; the caller owns conditions, routes and save state.
func configure(data: Dictionary, choices: Array) -> void:
	var style: String = data.get("style","decision")
	if data.get("shade",true): add_shade(float(data.get("shade_alpha",0.6)))
	if style == "speaker":
		build_speaker(data,choices)
		return
	_art(data.get("art","decision"))
	var text: String = data.get("text","")
	var font_size: int = int(data.get("font_size",24))
	if data.get("fit_body",false):
		while font_size > 16 and BODY_FONT.get_multiline_string_size(LOC.text(text),HORIZONTAL_ALIGNMENT_LEFT,280,font_size).y > 235:
			font_size -= 1
	_text(text,Rect2(430,72,280,235),font_size)
	for i: int in choices.size():
		var index := i
		var caption: String = choices[i].get("text","")
		if style == "confirmation":
			var rect := Rect2(65,65+i*65,335,50)
			_brush(rect)
			_button_text(caption,rect.grow_individual(-12,-5,-12,-5),20,null,TITLE_FONT)
			choice_buttons.append(_hit(caption,rect,func(): choice_selected.emit(index)))
		else:
			_button_text(caption,Rect2(66,66+i*65,337,50),int(data.get("answer_size",22)))
			choice_buttons.append(_hit(caption,Rect2(60,54+i*65,349,64),func(): choice_selected.emit(index)))
	if data.get("dismissable",false):
		for rect: Rect2 in [Rect2(0,0,800,35),Rect2(0,35,45,310),Rect2(730,35,70,310),Rect2(0,345,800,135)]:
			_hit("@loc:ui.city_gameplay.2",rect,func(): dismissed.emit())

func build_speaker(data: Dictionary, choices: Array) -> void:
	var artwork: String = data.get("art","")
	if not artwork.is_empty():
		backdrop = _art(artwork)
		move_child(backdrop,0)
		set_cover_rect(cover_rect)
	if data.get("original_ui",false):
		_text(data.get("speaker",""),Rect2(597,209,155,23),17,false,true)
		var body_size := 23
		var text: String = data.get("text","")
		while body_size > 14 and BODY_FONT.get_multiline_string_size(LOC.text(text),HORIZONTAL_ALIGNMENT_LEFT,465*2,body_size*2).y > 137*2: body_size -= 1
		_text(text,Rect2(122,72,465,137),body_size)
		_draw_brushes(data.get("art",""),self)
		for i: int in choices.size():
			var index := i
			var caption: String = choices[i].get("text","")
			var answer_size := 22
			while answer_size > 14 and BODY_FONT.get_multiline_string_size(LOC.text(caption),HORIZONTAL_ALIGNMENT_LEFT,620*2,answer_size*2).y > 55*2: answer_size -= 1
			_button_text(caption,Rect2(110,250+i*66,620,55),answer_size)
			choice_buttons.append(_hit(caption,Rect2(91,244+i*66,657,64),func(): choice_selected.emit(index)))
	else:
		_text(data.get("speaker",""),Rect2(90,40,620,45),26,true)
		_text(data.get("text",""),Rect2(90,90,620,145),23)
		for i: int in choices.size():
			var index := i
			var caption: String = choices[i].get("text","@loc:ui.story_activity.1")
			var rect := Rect2(90,245+i*55,620,48)
			_brush(rect)
			_button_text(caption,rect.grow_individual(-12,-5,-12,-5),20,null,TITLE_FONT)
			choice_buttons.append(_hit(caption,rect,func(): choice_selected.emit(index)))

func set_cover_rect(rect: Rect2) -> void:
	super.set_cover_rect(rect)
	if is_instance_valid(backdrop):
		var cover := maxf(rect.size.x/LAYOUT.BASE_SIZE.x,rect.size.y/LAYOUT.BASE_SIZE.y)
		backdrop.scale = Vector2.ONE * cover
		backdrop.position = rect.position+(rect.size-LAYOUT.BASE_SIZE*cover)*0.5
