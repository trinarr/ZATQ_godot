extends RefCounted
# Own the two original siblings so Flash caption transforms retain their origin.
const TEXT := preload("res://scripts/ui/shared/shader_text.gd")
const LOC := preload("res://scripts/core/localization.gd")
const LAYOUT := preload("res://scripts/ui/landscape_stage_layout.gd")
const BAND_ALPHA := 0.68
const PANEL_SHADER := preload("res://shaders/narrative_panel.gdshader")
const SCREEN_MARGIN := Vector2(48,12)
const TEXT_INSET := Vector2(48,28.8)
const NARRATIVE_FONT_SIZE := 20.5 # 41 px: 48 px reduced by 15%, rounded.
const BOTTOM_TO_TOP_RATIO := 0.8
static var ink_cache: Dictionary = {}
var label: Label = TEXT.new()
var band := ColorRect.new()

func _init() -> void:
 var paint := ShaderMaterial.new()
 paint.shader=PANEL_SHADER
 band.material=paint
 band.resized.connect(func():paint.set_shader_parameter("panel_size",band.size))

func park(host: Control) -> void:
 for item: Control in [band,label]:
  if item.get_parent()!=null:item.get_parent().remove_child(item)
  host.add_child(item)
  item.hide()

static func _ink_bounds(font: Font, pixels: int, text: String) -> Vector2:
 var server := TextServerManager.get_primary_interface()
 var font_rids := font.get_rids()
 if font_rids.is_empty():return Vector2(-font.get_ascent(pixels),font.get_descent(pixels))
 var top := INF
 var bottom := -INF
 for i: int in text.length():
  var glyph: int=server.font_get_glyph_index(font_rids[0],pixels,text.unicode_at(i),0)
  var key: String="%s:%d:%d" % [font_rids[0].get_id(),pixels,glyph]
  if not ink_cache.has(key):
   var bounds:=Vector2(INF,-INF)
   var outline: Dictionary=server.font_get_glyph_contours(font_rids[0],pixels,glyph)
   for point: Vector3 in outline.get("points",[]):
    bounds.x=minf(bounds.x,point.y)
    bounds.y=maxf(bounds.y,point.y)
   ink_cache[key]=bounds
  var ink: Vector2=ink_cache[key]
  top=minf(top,ink.x)
  bottom=maxf(bottom,ink.y)
 return Vector2(top,bottom) if is_finite(top) else Vector2.ZERO

static func _bottom_inset(font: Font, pixels: int, text: String, width: float, wrap: bool) -> float:
 var paragraph := TextParagraph.new()
 paragraph.width=width if wrap else -1
 paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
 paragraph.add_string(text,font,pixels)
 var count: int=paragraph.get_line_count()
 if count==0:return TEXT_INSET.y
 var first: Vector2i=paragraph.get_line_range(0)
 var last: Vector2i=paragraph.get_line_range(count-1)
 var first_ink:=_ink_bounds(font,pixels,text.substr(first.x,first.y-first.x))
 var last_ink:=_ink_bounds(font,pixels,text.substr(last.x,last.y-last.x))
 # Compare visible letters, compensating for the font's empty ascender/descender space.
 var top_gap: float=TEXT_INSET.y+maxf(0,font.get_ascent(pixels)+first_ink.x)
 var bottom_empty: float=maxf(0,font.get_descent(pixels)-last_ink.y)
 return maxf(0,top_gap*BOTTOM_TO_TOP_RATIO-bottom_empty)

func configure(host: Control, value: String, rect: Rect2, font: Font, font_size: int, options: Dictionary = {}) -> Label:
 var translated: String=LOC.text(value)
 if options.get("distressed",false):translated=translated.to_upper()
 var geometry: Rect2=LAYOUT.scaled_rect(rect)
 # Story narration has one size; terminal labels and headings opt out.
 var fixed_size: bool=bool(options.get("fixed_size",not options.get("distressed",false)))
 var requested_size: float=NARRATIVE_FONT_SIZE if fixed_size else font_size
 var pixels: int=roundi(requested_size*2)
 var padding: float=float(options.get("padding",0))
 var band_area: Rect2=options.get("band_rect",Rect2())
 var panel: bool=options.has("band_rect") or options.get("story_panel",false)
 var grows_up: bool=(band_area.get_center().y if options.has("band_rect") else geometry.get_center().y)>=LAYOUT.BASE_SIZE.y*0.5
 if panel:
  var bounds:=Rect2(SCREEN_MARGIN,LAYOUT.BASE_SIZE-SCREEN_MARGIN*2)
  if not options.has("band_rect"):
   band_area=Rect2(geometry.position-TEXT_INSET,geometry.size+TEXT_INSET*2)
  var left: float=maxf(bounds.position.x,band_area.position.x)
  var right: float=minf(bounds.end.x,band_area.end.x)
  band_area.position.x=left
  band_area.size.x=maxf(TEXT_INSET.x*2+1,right-left)
  geometry.position.x=left+TEXT_INSET.x
  geometry.size.x=maxf(1,band_area.size.x-TEXT_INSET.x*2)
  if grows_up:
   band_area.size.y=minf(band_area.end.y,bounds.end.y)-band_area.position.y
  else:
   var bottom: float=band_area.end.y
   band_area.position.y=maxf(bounds.position.y,band_area.position.y)
   band_area.size.y=maxf(0,bottom-band_area.position.y)
   geometry.position.y=band_area.position.y+TEXT_INSET.y
 var wrap: bool=true if fixed_size else bool(options.get("wrap",true))
 var preferred: Vector2=font.get_multiline_string_size(translated,HORIZONTAL_ALIGNMENT_LEFT,geometry.size.x,pixels) if wrap else font.get_string_size(translated,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels)
 var lines: int=maxi(1,roundi(preferred.y/font.get_height(pixels)))
 var required: float=preferred.y+maxf(0.0,float(options.get("line_spacing",0)))*maxi(0,lines-1)+(0.0 if panel else padding)
 var old_end: float=geometry.end.y
 # Panel height comes from the text, never the empty space in a Flash text box.
 geometry.size.y=required if panel else maxf(geometry.size.y,required)
 if panel:
  var inset: float=_bottom_inset(font,pixels,translated,geometry.size.x,wrap)
  if grows_up:
   var bottom: float=band_area.end.y-inset
   geometry.position.y=bottom-geometry.size.y
   var top: float=geometry.position.y-TEXT_INSET.y
   band_area.size.y=band_area.end.y-top
   band_area.position.y=top
  else:
   var bottom: float=geometry.end.y+inset
   band_area.size.y=bottom-band_area.position.y
 elif grows_up:
  geometry.position.y=maxf(0.0,old_end-geometry.size.y)
 for item: Control in [band,label]:
  if item.get_parent()!=null:item.get_parent().remove_child(item)
  item.scale=Vector2.ONE;item.rotation=0;item.modulate=Color.WHITE
  item.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var band_host: Control=options.get("band_host",host)
 if panel:
  var area: Rect2=band_area
  band.position=area.position;band.size=area.size
  band.material.set_shader_parameter("panel_size",band.size)
  band.color=Color(0,0,0,clampf(float(options.get("band_alpha",BAND_ALPHA)),0.0,1.0))
  band_host.add_child(band);band.show()
 else:
  options.storage.add_child(band)
  band.hide()
 label.distressed=bool(options.get("distressed",false))
 label.visible_characters=-1
 label.visible_characters_behavior=TextServer.VC_CHARS_BEFORE_SHAPING
 label.shadow_pass.material=TEXT.shadow_material
 label.name="NarrativeText"
 label.text=translated
 label.add_theme_font_override("font",font)
 label.add_theme_font_size_override("font_size",pixels)
 label.add_theme_color_override("font_color",Color("e1e1e1"))
 label.add_theme_constant_override("line_spacing",int(options.get("line_spacing",0)))
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if options.get("center",false) else HORIZONTAL_ALIGNMENT_LEFT
 label.vertical_alignment=VERTICAL_ALIGNMENT_TOP
 label.clip_text=false
 label.position=geometry.position;label.size=geometry.size
 host.add_child(label);label.show();label.size=geometry.size
 label.set_deferred("size",geometry.size)
 label.request_shadow_sync()
 return label
