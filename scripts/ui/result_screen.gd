extends RefCounted
# ResultBad / Symbol 59, final animation frame. Coordinates are Flash pixels.
static func draw(ui: Control, node: Dictionary) -> void:
 var alive: bool = node.kind == "city_ending"
 var stats: Dictionary = Quest.stats_for(node.get("episode",1))
 ui._set_backdrop(load("res://assets/flash_ui/result_background.png"))
 ui._art("result_alive" if alive else "result_dead")
 var outcome: Label = ui._text("Итог: жив" if alive else "Итог: мертв",Rect2(73.05,75,652.95,28.2),25,false,true)
 outcome.name = "ResultOutcome"
 var count: Label = ui._text("%d/%d" % [stats.endings.size(),Quest.ending_count(node.get("episode",1))] if alive else str(stats.losses),Rect2(76,219,81,36.8),33,false,true)
 count.name = "ResultCount"
 var font_size := 22
 while font_size > 12 and ui.BODY_FONT.get_multiline_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,548.95,font_size).y > 230:
  font_size -= 1
 var body: Label = ui._text(node.text,Rect2(162.05,112,548.95,230),font_size)
 body.name = "ResultStory"
 body.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
 body.justification_flags = TextServer.JUSTIFICATION_KASHIDA | TextServer.JUSTIFICATION_WORD_BOUND | TextServer.JUSTIFICATION_SKIP_LAST_LINE
 body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 for label: Label in [outcome,count,body]:
  label.add_theme_color_override("font_shadow_color",Color.BLACK)
  label.add_theme_constant_override("shadow_offset_x",2)
  label.add_theme_constant_override("shadow_offset_y",2)
 ui._hit("Начать заново",Rect2(593,360,73,70),ui._start)
 ui._hit("В меню",Rect2(668,360,73,70),ui._show_menu)
 if alive and Quest.episode_starts.has(int(node.get("episode",1))+1):
  ui._art("ep2_continue_button")
  ui._hit("Следующий эпизод",Rect2(67,360,73,70),func(): ui._start_episode(int(node.get("episode",1))+1))
