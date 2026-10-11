extends SceneTree
const ITEM=preload("res://scenes/shared/ItemPopup.tscn")
const RESULT=preload("res://scenes/shared/ResultPopup.tscn")
var checks:=0
var failures:=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1;push_error(message)
func ink_center(label: Label) -> float:
 var font:=label.get_theme_font("font")
 var pixels:=label.get_theme_font_size("font_size")
 var server:=TextServerManager.get_primary_interface()
 var rid: RID=font.get_rids()[0]
 var top:=INF
 var bottom:=-INF
 for c: String in label.text:
  var glyph:=server.font_get_glyph_index(rid,pixels,c.unicode_at(0),0)
  for point: Vector3 in server.font_get_glyph_contours(rid,pixels,glyph).get("points",PackedVector3Array()):
   top=minf(top,point.y);bottom=maxf(bottom,point.y)
 return label.position.y+font.get_ascent(pixels)+(top+bottom)*0.5
func _initialize() -> void:call_deferred("run")
func run() -> void:
 for locale: String in ["ru","en"]:
  TranslationServer.set_locale(locale)
  for alive: bool in [false,true]:
   var item:=ITEM.instantiate();root.add_child(item)
   item.configure("item_keys","Ключи от Subaru R1e" if locale=="ru" else "Keys to Subaru R1e")
   var result:=RESULT.instantiate();root.add_child(result)
   result.configure({"kind":"city_ending" if alive else "city_death","text":"Sample result"},{"endings":[1],"losses":1},3,true)
   await process_frame
   await process_frame
   check(item.get_child(1).get_rect()==result.get_child(1).get_rect(),"common body "+locale)
   for panel: Control in [item,result]:
    var title: Label=panel.find_child("ItemTitle" if panel==item else "ResultTitle",true,false)
    var subtitle: Label=panel.find_child("ItemDescription" if panel==item else "ResultOutcome",true,false)
    check(absf(ink_center(title)-60)<0.01,"title visible ink centered "+locale)
    check(absf(ink_center(subtitle)-167.5)<0.01,"subtitle visible ink centered "+locale)
    check(title.get_theme_font_size("font_size")==48,"title size reduced by twenty percent")
    check(title.get_line_count()==1 and subtitle.get_line_count()==1,"headings fit one line "+locale)
    check(title.shadow_pass.position==title.shadow_offset,"shadow follows centered title")
    for child: Node in panel.get_children():
     if child is TextureRect and child.texture==load("res://assets/flash_ui/episode1_components/part_4c241560532984aa6b29.png"):
      check(child.z_index==1,"header overlays subtitle")
      check(child.position==Vector2(70,0) and child.size==Vector2(1458,120),"complete shared header")
     if child is TextureRect and child.texture==load("res://assets/flash_ui/components/panel_header_shadow_tail.png"):
      check(child.z_index==1 and child.position.y==120,"header shadow overlays adjoining red strip")
     if child is TextureRect and child.get_script()==load("res://scripts/ui/vector_decoration.gd"):
      check(child.position.y==120 and child.z_index==0,"red strip adjoins header edge")
     if child is Control and child.has_meta("bound_action"):
      check(child.get_rect().end.y<=848,"button inside shared body")
   var stats: Control=result.find_child("ResultStatistics",true,false)
   var icon: Control=result.find_child("ResultIcon",true,false)
   var count: Label=result.find_child("ResultCount",true,false)
   check(absf(stats.get_rect().get_center().y-437.5)<0.01,"complete statistics block centered")
   check(icon.get_parent()==stats and count.get_parent()==stats,"icon and counter move as one block")
   check(absf((icon.get_rect().get_center().x)-(count.get_meta("optical_area") as Rect2).get_center().x)<0.01,"icon and counter share horizontal center")
   var story: Label=result.find_child("ResultStory",true,false)
   var underlay: TextureRect
   for child: Node in result.get_children():
    if child is TextureRect and child.texture==load("res://assets/flash_ui/episode1_components/part_62082e0e9b33edbe7d78.png"):underlay=child
   check(underlay==null,"light result underlay removed")
   check(story.position.y>=275,"story starts below subtitle strip")
   check(story.get_rect().end.y<=640,"story leaves space before result buttons")
   item.free();result.free()
 print("Metal popup layout: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
