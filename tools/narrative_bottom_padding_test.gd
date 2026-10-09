extends SceneTree
const BLOCK=preload("res://scripts/ui/shared/narrative_block.gd")
const FONT=preload("res://fonts/flash/font_2.ttf")
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
 check(label.position==Vector2(22,689.4),"authored position stays fixed")
 check(label.position.y+label.size.y<=936.01,"text box leaves 12 authored pixels below it")
 check(label.get_minimum_size().y<=label.size.y+0.01,"complete text fits without clipping")
 print("FOREST: font=",label.get_theme_font_size("font_size")," lines=",label.get_line_count()," content_height=",label.get_minimum_size().y," box_height=",label.size.y," bottom_gap=",960-label.position.y-label.size.y)
 # A short bottom caption also respects height when fitting a single line.
 label=block.configure(host,"Короткий текст",Rect2(11,450,775,34),FONT,24,{"storage":host,"fit":"single","minimum":16,"band_rect":Rect2(0,888,1600,72)})
 await process_frame
 check(label.position.y+label.size.y<=936.01,"single line fits above bottom inset")
 check(label.get_minimum_size().y<=label.size.y+0.01,"single-line fitting includes height")
 # Reusing the component for ordinary text must release the inset constraint.
 label=block.configure(host,"Обычный текст",Rect2(11,6,769,80),FONT,24,{"storage":host})
 await process_frame
 check(label.position==Vector2(22,12) and label.size==Vector2(1538,160),"unbanded text geometry is unchanged")
 print("PASS: %d bottom padding checks; failures %d" %[checks,failures])
 quit(1 if failures else 0)
