extends Node2D
# MovieClip keys are discrete at the original document rate, not invented tweens.
signal finished
static var data: Dictionary = {}
const COLOR_TRANSFORM := preload("res://shaders/flash_color_transform.gdshader")
static var caption_data: Dictionary = {}
var art_name := ""
var captions: Array[Dictionary] = []
var spec: Dictionary
var sprites: Dictionary = {}
var frames: Array = []
var elapsed := 0.0
var current_frame := 0
var playing := false
var suspended := false
var phase := "intro"
static func catalog() -> Dictionary:
 if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://data/episode1_animations.json"))
 return data
static func has_art(art: String) -> bool:return catalog().art.has(art)
func configure(art: String) -> void:
 art_name=art
 spec=catalog().art[art]
 for key: String in spec.parts:
  var part: Dictionary=spec.parts[key]
  var pivot:=Node2D.new()
  var visual: Control
  if part.type=="panel":
   var panel:=ColorRect.new()
   var c: Array=part.color
   panel.color=Color(c[0],c[1],c[2],c[3]);visual=panel
  else:
   var image:=TextureRect.new()
   image.texture=load("res://assets/flash_ui/"+part.texture)
   image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;visual=image
  var r: Array=part.rect
  visual.position=Vector2(r[0],r[1])*2;visual.size=Vector2(r[2],r[3])*2
  visual.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var paint:=ShaderMaterial.new();paint.shader=COLOR_TRANSFORM
  paint.set_shader_parameter("blur_sigma",Vector2.ZERO)
  if part.has("blur"):
   var blur: Dictionary=part.blur
   paint.set_shader_parameter("blur_sigma",Vector2(blur.sigma[0],blur.sigma[1])*2)
   paint.set_shader_parameter("blur_angle",float(blur.angle))
  visual.material=paint
  pivot.add_child(visual);add_child(pivot);sprites[key]=pivot
 play("intro")
func play(next_phase: String) -> void:
 phase=next_phase;frames=spec[phase];elapsed=0;playing=true
 seek_frame(0)
func seek_frame(index: int) -> void:
 var cycle: int=int(spec.get("intro_loop",0)) if phase=="intro" else 0
 if cycle>1 and index>=frames.size():
  index=frames.size()-cycle+(index-(frames.size()-cycle))%cycle
 current_frame=clampi(index,0,frames.size()-1)
 for pivot: Node2D in sprites.values():pivot.visible=false
 var order:=0
 for record: Array in frames[current_frame]:
  var pivot: Node2D=sprites[record[0]]
  var m: Array=record[1];var c: Array=record[2]
  pivot.transform=Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5])*2)
  var paint: ShaderMaterial=pivot.get_child(0).material
  paint.set_shader_parameter("multiplier",Color(c[0],c[1],c[2],c[3]))
  paint.set_shader_parameter("offset",Vector3(c[4],c[5],c[6]));pivot.visible=true
  move_child(pivot,order);order+=1
 _update_captions(index)
 if current_frame==frames.size()-1 and playing and cycle<=1:
  playing=false;finished.emit()
func _process(delta: float) -> void:
 if not playing or suspended:return
 elapsed+=delta
 seek_frame(int(floor(elapsed*catalog().fps)))
func has_outro() -> bool:return spec.outro.size()>1
func duration(next_phase: String) -> float:return float(spec[next_phase].size())/catalog().fps

func same_clip(art: String) -> bool:
 if not has_art(art):return false
 var other: Dictionary=catalog().art[art]
 return spec.get("clip","")==other.get("clip","_")

func bind_caption(label: Label, alias: String = "") -> void:
 if caption_data.is_empty():caption_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/episode1_text_animations.json"))
 if not caption_data.has(art_name):return
 var text: String=" ".join(label.text.split("\n",false)).replace("\r"," ")
 text=" ".join(text.split(" ",false))
 if not alias.is_empty():text=alias
 if not caption_data[art_name].anchors.has(text):return
 captions.append({"label":label,"text":text,"origin":label.position,"scale":label.scale,"color":label.modulate})
 _update_captions(current_frame)
func _update_captions(index: int) -> void:
 if captions.is_empty():return
 var spec_text: Dictionary=caption_data[art_name]
 var row: Array=spec_text[phase][mini(index,spec_text[phase].size()-1)]
 for entry: Dictionary in captions:
  var label: Label=entry.label
  if not is_instance_valid(label):continue
  label.visible=false
  for record: Array in row:
   if record[0]!=entry.text:continue
   var m: Array=record[1];var base: Array=spec_text.anchors[entry.text];var c: Array=record[2]
   var pose:=Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5])*2)
   var anchor:=Transform2D(Vector2(base[0],base[1]),Vector2(base[2],base[3]),Vector2(base[4],base[5])*2)
   var delta:=pose*anchor.affine_inverse()
   label.position=delta*entry.origin;label.scale=entry.scale*delta.get_scale();label.rotation=delta.get_rotation()
   label.modulate=entry.color*Color(c[0],c[1],c[2],c[3]);label.visible=true
   break
