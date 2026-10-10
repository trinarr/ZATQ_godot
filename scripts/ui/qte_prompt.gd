extends Control
# Decorative QTE badge. StoryActivity retains the original interactive hotspot.
const LOC := preload("res://scripts/core/localization.gd")
const FONT: Font = preload("res://fonts/oswald/Oswald-Medium.ttf")
var text_key := "@loc:ui.qte.press"
var caption := preload("res://scripts/ui/shared/shader_text.gd").new()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(224,224)
	caption.distressed = true
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.position = Vector2(30,66)
	caption.size = Vector2(164,92)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font",FONT)
	caption.add_theme_color_override("font_color",Color("c6c6c6"))
	add_child(caption)
	refresh_text()

func refresh_text() -> void:
	caption.text = LOC.text(text_key).to_upper()
	var font_size := 62
	while font_size > 16 and FONT.get_string_size(caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > caption.size.x:
		font_size -= 1
	caption.add_theme_font_size_override("font_size",font_size)

func _draw() -> void:
	var center := Vector2(112,112)
	draw_circle(center+Vector2(2,3),99,Color(0.06,0.035,0.035,0.65))
	draw_circle(center,94,Color("803c3c"))
	draw_arc(center,96,0,TAU,128,Color("c6c6c6"),5,true)
	for angle: float in [0.0,PI*0.5,PI,PI*1.5]:
		var direction := Vector2.from_angle(angle)
		draw_line(center+direction*96,center+direction*105,Color("c6c6c6"),6,true)
