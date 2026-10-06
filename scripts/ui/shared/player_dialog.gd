extends "res://scripts/ui/shared/modal_view.gd"
signal choice_selected(index: int)
signal dismissed
const METAL_ANSWER := preload("res://scripts/ui/shared/dialog_answer_button.gd")
var choice_buttons: Array[Button] = []
var answer_slots: Array[Button] = []
var backdrop: Control

# Decision, confirmation and speaker layouts share one component and API.
# choices contain text; the caller owns conditions, routes and save state.
func configure(data: Dictionary, choices: Array) -> void:
	var style: String = data.get("style","decision")
	if data.get("shade",true): add_shade(float(data.get("shade_alpha",0.9)))
	if style == "speaker":
		build_speaker(data,choices)
		return
	_art(data.get("art","decision"))
	var text: String = data.get("text","")
	var font_size: int = int(data.get("font_size",24))
	if data.get("fit_body",false):
		while font_size > 16 and BODY_FONT.get_multiline_string_size(LOC.text(text),HORIZONTAL_ALIGNMENT_LEFT,280,font_size).y > 235:
			font_size -= 1
	var body := _text(text,Rect2(430,72,280,235),font_size)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
	body.justification_flags = TextServer.JUSTIFICATION_WORD_BOUND | TextServer.JUSTIFICATION_SKIP_LAST_LINE
	body.add_theme_color_override("font_color",Color("c8c8c8"))
	for i: int in (choices.size() if style == "confirmation" else maxi(4,choices.size())):
		var index := i
		var available := i<choices.size()
		var caption: String = choices[i].get("text","") if available else ""
		if style == "confirmation":
			var rect := Rect2(65,65+i*65,335,50)
			choice_buttons.append(_torn_text_button(caption,rect,func(): choice_selected.emit(index)))
		else:
			var button := METAL_ANSWER.new()
			add_child(button)
			button.position = Vector2(61,54+i*65)*2
			button.configure(caption,available,int(data.get("answer_size",24)))
			answer_slots.append(button)
			if available:
				button.pressed.connect(func(): choice_selected.emit(index))
				choice_buttons.append(button)
	if data.get("dismissable",false):
		dimmer.gui_input.connect(_dismiss_on_shade)

func _dismiss_on_shade(event: InputEvent) -> void:
	dismiss_on_shade_release(event,dismissed.emit)

func build_speaker(data: Dictionary, choices: Array) -> void:
	var artwork: String = data.get("art","")
	if not artwork.is_empty():
		backdrop = _art(artwork)
		# Speaker answers are interactive UI, never part of a scaled backdrop.
		for child: Node in backdrop.get_children():
			if child.has_meta("torn_button"):
				backdrop.remove_child(child)
				child.queue_free()
		move_child(backdrop,0)
		set_cover_rect(cover_rect)
	if data.get("original_ui",false):
		_text(data.get("speaker",""),Rect2(597,209,155,23),17,false,true)
		var body_size := 23
		var text: String = data.get("text","")
		while body_size > 14 and BODY_FONT.get_multiline_string_size(LOC.text(text),HORIZONTAL_ALIGNMENT_LEFT,465*2,body_size*2).y > 137*2: body_size -= 1
		_text(text,Rect2(122,72,465,137),body_size)
		for i: int in choices.size():
			var index := i
			var caption: String = choices[i].get("text","")
			var answer_size := 22
			while answer_size > 14 and BODY_FONT.get_multiline_string_size(LOC.text(caption),HORIZONTAL_ALIGNMENT_LEFT,620*2,answer_size*2).y > 55*2: answer_size -= 1
			var button := _torn_text_button(caption,Rect2(91,244+i*66,657,64),func(): choice_selected.emit(index),null,BODY_FONT,answer_size)
			var original_brushes: Array = art_brushes.get(artwork,art_brushes.get("e3_dialogue_john",[]))
			for b: int in original_brushes.size():
				var record: Dictionary = original_brushes[b]
				if str(record.get("path","")).ends_with("Dlg%d" % (i+1)):
					var c: Array = record.color
					button.set_palette(Color(c[0],c[1],c[2],c[3]),float(b+1))
			choice_buttons.append(button)
	else:
		_text(data.get("speaker",""),Rect2(90,40,620,45),26,true)
		_text(data.get("text",""),Rect2(90,90,620,145),23)
		for i: int in choices.size():
			var index := i
			var caption: String = choices[i].get("text","@loc:ui.story_activity.1")
			var rect := Rect2(90,245+i*55,620,48)
			choice_buttons.append(_torn_text_button(caption,rect,func(): choice_selected.emit(index)))

func set_cover_rect(rect: Rect2) -> void:
	super.set_cover_rect(rect)
	if is_instance_valid(backdrop):
		var cover := maxf(rect.size.x/LAYOUT.BASE_SIZE.x,rect.size.y/LAYOUT.BASE_SIZE.y)
		backdrop.scale = Vector2.ONE * cover
		backdrop.position = rect.position+(rect.size-LAYOUT.BASE_SIZE*cover)*0.5
