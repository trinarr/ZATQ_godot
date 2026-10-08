extends RefCounted
# Own the two original siblings so Flash caption transforms retain their origin.
const TEXT := preload("res://scripts/ui/shared/shader_text.gd")
const LOC := preload("res://scripts/core/localization.gd")
const LAYOUT := preload("res://scripts/ui/landscape_stage_layout.gd")
static var fit_cache: Dictionary = {}
var label: Label = TEXT.new()
var band := ColorRect.new()

func park(host: Control) -> void:
 for item: Control in [band,label]:
  if item.get_parent()!=null:item.get_parent().remove_child(item)
  host.add_child(item)
  item.hide()

func configure(host: Control, value: String, rect: Rect2, font: Font, font_size: int, options: Dictionary = {}) -> Label:
 var translated: String=LOC.text(value)
 var geometry: Rect2=LAYOUT.scaled_rect(rect)
 var mode: String=options.get("fit","none")
 var minimum: int=int(options.get("minimum",font_size))
 var padding: float=float(options.get("padding",0))
 var key: Array=[translated,font.get_instance_id(),font_size,minimum,geometry.size,mode,padding]
 var cache_key: String=var_to_str(key)
 var fitted: int=fit_cache.get(cache_key,-1)
 if fitted<0:
  fitted=font_size
  while fitted>minimum:
   var measured: Vector2=font.get_string_size(translated,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted*2) if mode=="single" else font.get_multiline_string_size(translated,HORIZONTAL_ALIGNMENT_LEFT,geometry.size.x,fitted*2)
   if mode=="none" or (measured.x<=geometry.size.x if mode=="single" else measured.y<=geometry.size.y-padding):break
   fitted-=1
  if fit_cache.size()>=256:fit_cache.erase(fit_cache.keys()[0])
  fit_cache[cache_key]=fitted
 for item: Control in [band,label]:
  if item.get_parent()!=null:item.get_parent().remove_child(item)
  item.scale=Vector2.ONE;item.rotation=0;item.modulate=Color.WHITE
  item.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var band_host: Control=options.get("band_host",host)
 if options.has("band_rect"):
  var area: Rect2=options.band_rect
  band.position=area.position;band.size=area.size;band.color=Color.BLACK
  band_host.add_child(band);band.show()
 else:
  options.storage.add_child(band)
  band.hide()
 label.material=null
 label.visible_characters=-1
 label.visible_characters_behavior=TextServer.VC_CHARS_BEFORE_SHAPING
 label.shadow_pass.material=TEXT.shadow_material
 label.name="NarrativeText"
 label.text=translated
 label.add_theme_font_override("font",font)
 label.add_theme_font_size_override("font_size",fitted*2)
 label.add_theme_color_override("font_color",Color("e1e1e1"))
 label.add_theme_constant_override("line_spacing",int(options.get("line_spacing",0)))
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART if options.get("wrap",true) else TextServer.AUTOWRAP_OFF
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if options.get("center",false) else HORIZONTAL_ALIGNMENT_LEFT
 label.vertical_alignment=VERTICAL_ALIGNMENT_TOP
 label.clip_text=false
 label.position=geometry.position;label.size=geometry.size
 host.add_child(label);label.show();label.size=geometry.size
 label.set_deferred("size",geometry.size)
 label.request_shadow_sync()
 return label
