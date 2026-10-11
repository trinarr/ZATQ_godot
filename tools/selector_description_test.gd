extends SceneTree
var failures := 0
func _initialize():call_deferred("run")
func run():
 var ui=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await process_frame
 for locale in ["ru","en"]:
  TranslationServer.set_locale(locale)
  for kind in ["episodes","tests"]:
   ui._show_selector(kind)
   for index in ui._selector_items().size():
    ui.selector_index=index;ui._draw_selector()
    await process_frame;await process_frame
    var label: Label=ui.screen.find_child("SelectorDescription",true,false)
    if label.get_theme_font_size("font_size")!=32:
     failures+=1;push_error("Normal card must keep 32 px: "+label.text)
    var area: Rect2=label.get_meta("optical_area")
    var pixels=label.get_theme_font_size("font_size")
    var paragraph=TextParagraph.new();paragraph.width=area.size.x
    paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
    paragraph.add_string(label.text,ui.BODY_FONT,pixels)
    var first=paragraph.get_line_range(0);var last=paragraph.get_line_range(paragraph.get_line_count()-1)
    var top=label.position.y+ui.BODY_FONT.get_ascent(pixels)+ui.OPTICAL.ink(ui.BODY_FONT,pixels,label.text.substr(first.x,first.y-first.x)).x
    var bottom=label.position.y+label.size.y-ui.BODY_FONT.get_descent(pixels)+ui.OPTICAL.ink(ui.BODY_FONT,pixels,label.text.substr(last.x,last.y-last.x)).y
    if absf(top-area.position.y)>0.1:
     failures+=1;push_error("Description must start at the upper inset")
    if absf(top-408.0)>0.1:
     failures+=1;push_error("Description must keep a 28 px inset below the divider")
    if top<area.position.y-0.1 or bottom>area.end.y+0.1:
     failures+=1;push_error("Card text outside available area: "+label.text)
    if kind=="tests":
     for pair in [["SelectorLastResult",340.0],["SelectorQuestionCount",585.0]]:
      var caption: Label=ui.screen.find_child(pair[0],true,false)
      var ink: Vector2=ui.OPTICAL.ink(ui.BODY_FONT,caption.get_theme_font_size("font_size"),caption.text)
      var middle=caption.position.y+ui.BODY_FONT.get_ascent(caption.get_theme_font_size("font_size"))+(ink.x+ink.y)*0.5
      if absf(middle-pair[1])>0.1:
       failures+=1;push_error("Test statistic must be vertically centered")
 ui.selectors[0].description="Очень длинный текст описания. ".repeat(50)
 ui._show_selector("episodes")
 await process_frame;await process_frame
 var extreme:Label=ui.screen.find_child("SelectorDescription",true,false)
 if extreme.get_theme_font_size("font_size")>=32:failures+=1;push_error("Exceptional text may shrink")
 ui.free()
 await process_frame;await process_frame
 print("Selector descriptions: ",failures," failures")
 quit.call_deferred(1 if failures else 0)
