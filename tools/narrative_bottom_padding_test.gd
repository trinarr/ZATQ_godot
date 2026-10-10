extends SceneTree
const BLOCK=preload("res://scripts/ui/shared/narrative_block.gd")
const FONT=preload("res://fonts/oswald/Oswald-Medium.ttf")
var checks:=0
var failures:=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var host:=Control.new();root.add_child(host)
 var block:=BLOCK.new()
 var graph: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/story_graphs/episode4.json"))
 var b: Dictionary=graph.nodes.e4_camp_3_v1.data.blocks[0]
 var label: Label=block.configure(host,b.text,Rect2(b.rect[0],b.rect[1],b.rect[2],b.rect[3]),FONT,b.size,{"storage":host,"fit":"multiline","minimum":14,"padding":4,"band_rect":Rect2(0,(b.rect[1]-6)*2,1600,(b.rect[3]+12)*2)})
 await process_frame
 check(label.get_theme_font_size("font_size")==48,"forest caption uses the shared narrative size")
 check(label.position.y+label.size.y<=936.01,"text box leaves 12 authored pixels below it")
 check(label.get_minimum_size().y<=label.size.y+0.01,"complete text fits without clipping")
 print("FOREST: font=",label.get_theme_font_size("font_size")," lines=",label.get_line_count()," content_height=",label.get_minimum_size().y," box_height=",label.size.y," bottom_gap=",960-label.position.y-label.size.y)
 # A short bottom caption also respects height when fitting a single line.
 label=block.configure(host,"Короткий текст",Rect2(11,450,775,34),FONT,24,{"storage":host,"fit":"single","minimum":16,"band_rect":Rect2(0,888,1600,72)})
 await process_frame
 check(label.position.y+label.size.y<=936.01,"single line fits above bottom inset")
 check(label.get_minimum_size().y<=label.size.y+0.01,"single-line fitting includes height")
 check(label.get_theme_font_size("font_size")==48,"short caption stays at requested size")
 for sample: Array in [["Что дальше?",445.0],["Поехать ли на работу на машине или пойти пешком?",416.0]]:
  var y: float=sample[1]
  label=block.configure(host,sample[0],Rect2(11,y,775,34),FONT,24,{"storage":host,"fit":"single","minimum":16,"band_rect":Rect2(0,(y-6)*2,1600,(480-y+6)*2)})
  await process_frame
  check(label.get_theme_font_size("font_size")==48,"opening caption retains 24 Flash px: "+sample[0])
  check(label.get_minimum_size().y<=label.size.y+0.01,"opening caption fits: "+sample[0])
  check(label.position.y+label.size.y<=936.01,"opening caption retains bottom padding: "+sample[0])
 # A shallow Flash box must not shrink the two captions reported on device.
 for text: String in ["Что дальше?","Поехать ли на работу на машине или пойти пешком?"]:
  label=block.configure(host,text,Rect2(11,449,775,25),FONT,24,{"storage":host,"fit":"multiline","minimum":15,"band_rect":Rect2(0,878,1600,82)})
  await process_frame
  check(label.get_theme_font_size("font_size")==48,"shallow caption retains 24 Flash px: "+text)
  check(label.get_minimum_size().y<=label.size.y+0.01,"shallow caption fits: "+text)
  check(label.position.y+label.size.y<=936.01,"shallow caption retains bottom padding: "+text)
  check(block.band.position.y<=label.position.y and block.band.position.y+block.band.size.y==960,"band covers raised caption: "+text)
 # Reusing the component for ordinary text must release the inset constraint.
 label=block.configure(host,"Обычный текст",Rect2(11,6,769,80),FONT,24,{"storage":host})
 await process_frame
 check(label.position==Vector2(22,12) and label.size==Vector2(1538,160),"unbanded text geometry is unchanged")
 # Long upper and lower captions grow in opposite directions at identical size.
 var long_text: String="Реплика для проверки размера и направления роста плашки. ".repeat(14)
 for upper:bool in [true,false]:
  var y:float=6.0 if upper else 440.0
  var area:Rect2=Rect2(0,0,1600,90) if upper else Rect2(0,868,1600,92)
  label=block.configure(host,long_text,Rect2(11,y,775,25),FONT,18 if upper else 30,{"storage":host,"fit":"single","minimum":14,"band_rect":area})
  await process_frame
  check(label.get_theme_font_size("font_size")==48,"long caption never shrinks")
  check(label.get_line_count()>1,"single-line legacy setting now allows wrapping")
  check(label.get_minimum_size().y<=label.size.y+0.01,"grown box contains all lines")
  check(label.position.y==12.0 if upper else label.position.y<880.0,"text grows down from top or up from bottom")
  check(block.band.size.y>area.size.y,"band grows with the caption")
 print("PASS: %d bottom padding checks; failures %d" %[checks,failures])
 quit(1 if failures else 0)
