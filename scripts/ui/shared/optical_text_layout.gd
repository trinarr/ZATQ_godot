extends RefCounted
# Center visible outlines rather than the font's padded line box.
static var glyph_bounds: Dictionary = {}
static func ink(font: Font, pixels: int, text: String) -> Vector2:
 var server:=TextServerManager.get_primary_interface()
 var rid: RID=font.get_rids()[0]
 var top:=INF
 var bottom:=-INF
 for character: String in text:
  var glyph:=server.font_get_glyph_index(rid,pixels,character.unicode_at(0),0)
  var key:=str(rid)+":"+str(pixels)+":"+str(glyph)
  if not glyph_bounds.has(key):
   var bounds:=Vector2(INF,-INF)
   for point: Vector3 in server.font_get_glyph_contours(rid,pixels,glyph).get("points",PackedVector3Array()):
    bounds.x=minf(bounds.x,point.y);bounds.y=maxf(bounds.y,point.y)
   glyph_bounds[key]=bounds
  var bounds: Vector2=glyph_bounds[key]
  top=minf(top,bounds.x);bottom=maxf(bottom,bounds.y)
 return Vector2(top,bottom) if is_finite(top) else Vector2(-font.get_ascent(pixels),font.get_descent(pixels))
static func center(label: Label, area: Rect2) -> void:
 _align(label,area,false)
static func top(label: Label, area: Rect2) -> void:
 _align(label,area,true)
static func _align(label: Label, area: Rect2, align_top: bool) -> void:
 var font:=label.get_theme_font("font")
 var pixels:=label.get_theme_font_size("font_size")
 var text:=label.text.to_upper() if label.uppercase else label.text
 var paragraph:=TextParagraph.new()
 paragraph.width=area.size.x if label.autowrap_mode!=TextServer.AUTOWRAP_OFF else -1
 paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
 paragraph.add_string(text,font,pixels,label.language)
 var count:=paragraph.get_line_count()
 if count==0:return
 var first:=paragraph.get_line_range(0)
 var last:=paragraph.get_line_range(count-1)
 var spacing:=label.get_theme_constant("line_spacing")
 var top:=paragraph.get_line_ascent(0)+ink(font,pixels,text.substr(first.x,first.y-first.x)).x
 var baseline:=paragraph.get_line_ascent(count-1)
 for i: int in count-1:baseline+=paragraph.get_line_size(i).y+spacing
 var bottom:=baseline+ink(font,pixels,text.substr(last.x,last.y-last.x)).y
 label.vertical_alignment=VERTICAL_ALIGNMENT_TOP
 label.position=Vector2(area.position.x,area.position.y-top if align_top else area.get_center().y-(top+bottom)*0.5)
 label.size=Vector2(area.size.x,paragraph.get_size().y+spacing*maxi(0,count-1))
 label.set_deferred("size",label.size)
 label.set_meta("optical_area",area)
 if label.has_method("request_shadow_sync"):label.request_shadow_sync()
