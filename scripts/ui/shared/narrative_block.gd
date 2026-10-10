extends RefCounted
# Own the two original siblings so Flash caption transforms retain their origin.
const TEXT := preload("res://scripts/ui/shared/shader_text.gd")
const LOC := preload("res://scripts/core/localization.gd")
const LAYOUT := preload("res://scripts/ui/landscape_stage_layout.gd")
const BAND_ALPHA := 127.0/255.0
const NARRATIVE_FONT_SIZE := 24 # 48 px in the 1600x960 stage.
const BOTTOM_PADDING := 12.0 # Flash coordinates; 24 px in the 1600x960 stage.
var label: Label = TEXT.new()
var band := ColorRect.new()

func park(host: Control) -> void:
 for item: Control in [band,label]:
  if item.get_parent()!=null:item.get_parent().remove_child(item)
  host.add_child(item)
  item.hide()

func configure(host: Control, value: String, rect: Rect2, font: Font, font_size: int, options: Dictionary = {}) -> Label:
 var translated: String=LOC.text(value)
 if options.get("distressed",false):translated=translated.to_upper()
 var geometry: Rect2=LAYOUT.scaled_rect(rect)
 # Story narration has one size; terminal labels and headings opt out.
 var fixed_size: bool=bool(options.get("fixed_size",not options.get("distressed",false)))
 var requested_size: int=NARRATIVE_FONT_SIZE if fixed_size else font_size
 var fitted: int=requested_size
 var padding: float=float(options.get("padding",0))
 var band_area: Rect2=options.get("band_rect",Rect2())
 var wrap: bool=true if fixed_size else bool(options.get("wrap",true))
 var preferred: Vector2=font.get_multiline_string_size(translated,HORIZONTAL_ALIGNMENT_LEFT,geometry.size.x,requested_size*2) if wrap else font.get_string_size(translated,HORIZONTAL_ALIGNMENT_LEFT,-1,requested_size*2)
 var lines: int=maxi(1,roundi(preferred.y/font.get_height(requested_size*2)))
 var required: float=preferred.y+maxf(0.0,float(options.get("line_spacing",0)))*maxi(0,lines-1)+padding
 var old_end: float=geometry.end.y
 geometry.size.y=maxf(geometry.size.y,required)
 var grows_up: bool=(band_area.get_center().y if options.has("band_rect") else (geometry.position.y+old_end)*0.5)>=LAYOUT.BASE_SIZE.y*0.5
 if options.has("band_rect"):
  var inset: float=maxf(0.0,float(options.get("bottom_padding",BOTTOM_PADDING)))*LAYOUT.AUTHORING_SCALE
  if grows_up:
   var bottom: float=minf(band_area.end.y,LAYOUT.BASE_SIZE.y)-inset
   geometry.position.y=maxf(0.0,minf(geometry.position.y,bottom-geometry.size.y))
   var top: float=minf(band_area.position.y,maxf(0.0,geometry.position.y-6.0*LAYOUT.AUTHORING_SCALE))
   band_area.size.y=band_area.end.y-top
   band_area.position.y=top
  else:
   var bottom: float=maxf(band_area.end.y,geometry.end.y+inset)
   band_area.size.y=bottom-band_area.position.y
 elif grows_up:
  geometry.position.y=maxf(0.0,old_end-geometry.size.y)
 for item: Control in [band,label]:
  if item.get_parent()!=null:item.get_parent().remove_child(item)
  item.scale=Vector2.ONE;item.rotation=0;item.modulate=Color.WHITE
  item.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var band_host: Control=options.get("band_host",host)
 if options.has("band_rect"):
  var area: Rect2=band_area
  band.position=area.position;band.size=area.size
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
 label.add_theme_font_size_override("font_size",fitted*2)
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
