extends Node2D
# MovieClip keys are discrete at the original document rate, not invented tweens.
signal finished
signal input_ready
static var data: Dictionary = {}
const BLUR_CACHE := preload("res://scripts/ui/blur_texture_cache.gd")
const EYE_CLOSURE := preload("res://scripts/ui/eye_closure.gd")
var eye_closure: Node2D
const SOFT_VIGNETTE := preload("res://scripts/ui/soft_vignette.gd")
const HIGHLIGHT := preload("res://scripts/ui/interactive_highlight.gd")
const QTE_PROMPT := preload("res://scripts/ui/qte_prompt.gd")
const LOC := preload("res://scripts/core/localization.gd")
static var caption_aliases: Dictionary = {}
const CAPTION_CLIP := preload("res://shaders/caption_clip.gdshader")
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
var input_ready_emitted := false
var suspended := false
var phase := "intro"
var applied_frame := -1
var applied_phase := ""
var pose_updates := 0
var variable_poses: Dictionary = {}
var variable_keys: Dictionary = {}
static func catalog() -> Dictionary:
	if data.is_empty():
		data={"fps":19,"art":{}}
		for filename: String in DirAccess.get_files_at("res://data"):
			if not filename.begins_with("episode") or not filename.ends_with("_animations.json") or filename.ends_with("_text_animations.json") or filename.ends_with("_ui_animations.json"):continue
			var episode: int=int(filename.get_slice("_",0).trim_prefix("episode"))
			var path: String="res://data/"+filename
			var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
			for art: String in source.art:
				var entry: Dictionary=source.art[art].duplicate(true)
				entry["episode"]=episode
				data.art[art]=entry
	return data
static func has_art(art: String) -> bool:return catalog().art.has(art)
func configure(art: String) -> void:
	art_name=art
	spec=catalog().art[art]
	for variable: String in spec.get("variables",{}):
		var keys: Dictionary={}
		for row: Array in spec.variables[variable]:
			for record: Array in row:keys[record[0]]=true
		variable_keys[variable]=keys
	for key: String in spec.parts:
		var part: Dictionary=spec.parts[key]
		var pivot: Node2D
		var visual: Control
		if part.has("eye_lid"):
			if eye_closure==null:
				eye_closure=EYE_CLOSURE.new();add_child(eye_closure)
			pivot=eye_closure.add_lid(part)
			visual=pivot.get_child(0)
		else:pivot=Node2D.new()
		if part.has("eye_lid"):pass
		elif part.type=="highlight":
			visual=HIGHLIGHT.new()
			visual.configure(part)
		elif part.type=="soft_vignette":
			visual=SOFT_VIGNETTE.new()
			visual.configure(part)
		elif part.type=="qte_prompt":
			visual=QTE_PROMPT.new()
		elif part.type=="panel":
			var panel:=ColorRect.new()
			var c: Array=part.color
			panel.color=Color(c[0],c[1],c[2],c[3]);visual=panel
		else:
			var image:=TextureRect.new()
			image.texture=load("res://assets/flash_ui/"+part.texture)
			image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;visual=image
		var r: Array=part.rect
		if part.type!="highlight":
			visual.position=Vector2(r[0],r[1])*2;visual.size=Vector2(r[2],r[3])*2
		visual.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var paint:=ShaderMaterial.new();paint.shader=COLOR_TRANSFORM
		if part.has("blur") and visual is TextureRect:
			visual.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
			BLUR_CACHE.bind(paint,visual.texture,part.blur)
		if part.type not in ["qte_prompt","highlight","soft_vignette"]:visual.material=paint
		if not part.has("eye_lid"):
			pivot.add_child(visual);add_child(pivot)
		sprites[key]=pivot
	if spec.has("caption_mask"):
		get_viewport().size_changed.connect(func(): _update_captions.call_deferred(current_frame))
	play("intro")
func play(next_phase: String) -> void:
	applied_frame=-1
	input_ready_emitted=false
	phase=next_phase;frames=_phase_frames(phase);elapsed=0;playing=true
	seek_frame(0)
func _phase_frames(next_phase: String) -> Array:
	var authored: Array=spec[next_phase]
	if art_name!="layout_bg_lift" or next_phase!="outro":return authored
	# The exported nested door clip restarts its opening on the parent outro.
	# Reverse door poses, but retain the parent's forward fade to black.
	var closing: Array=[]
	var opening: Array=spec.intro
	for i in authored.size():
		var pose_index: int=opening.size()-1-roundi(float(i)*float(opening.size()-1)/float(maxi(1,authored.size()-1)))
		var row: Array=opening[pose_index].duplicate(true)
		var colors: Dictionary={}
		for record: Array in authored[i]:colors[record[0]]=record[2]
		for record: Array in row:
			record[2]=colors.get(record[0],authored[i][0][2]).duplicate()
		closing.append(row)
	return closing
func seek_frame(index: int, subframe: float = 0.0) -> void:
	if phase=="intro" and not input_ready_emitted and spec.has("input_ready_frame") and index>=int(spec.input_ready_frame):
		input_ready_emitted=true;input_ready.emit()
	var cycle: int=int(spec.get("intro_loop",0)) if phase=="intro" else 0
	if cycle>1 and index>=frames.size():
		index=frames.size()-cycle+(index-(frames.size()-cycle))%cycle
	current_frame=clampi(index,0,frames.size()-1)
	if applied_frame!=current_frame or applied_phase!=phase:
		applied_frame=current_frame;applied_phase=phase;pose_updates+=1
		variable_poses.clear()
		for pivot: Node2D in sprites.values():pivot.visible=false
		var order:=0
		var ordered: Dictionary={}
		for record: Array in frames[current_frame]:
			var pivot: Node2D=sprites[record[0]]
			var m: Array=record[1];var c: Array=record[2]
			pivot.transform=Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5])*2)
			var visual: Control=pivot.get_child(0)
			var paint: ShaderMaterial=visual.material
			if visual.get_meta("interactive_highlight",false):
				visual.modulate=Color(c[0],c[1],c[2],c[3]*float(visual.get_meta("highlight_opacity",1.0)))
			elif paint:
				paint.set_shader_parameter("multiplier",Color(c[0],c[1],c[2],c[3]))
				paint.set_shader_parameter("offset",Vector3(c[4],c[5],c[6]))
			else:visual.modulate=Color(c[0],c[1],c[2],c[3])
			pivot.visible=true
			var layer: Node=eye_closure if pivot.get_parent()==eye_closure else pivot
			if not ordered.has(layer):
				move_child(layer,order);order+=1;ordered[layer]=true
		_update_captions(index)
	_update_blur_strength(float(current_frame)+subframe)
	if current_frame==frames.size()-1 and playing and cycle<=1:
		playing=false;finished.emit()
func _process(delta: float) -> void:
	if not playing or suspended:return
	elapsed+=delta
	var frame_time: float=elapsed*float(catalog().fps)
	seek_frame(int(floor(frame_time)),fposmod(frame_time,1.0))

func _update_blur_strength(frame_time: float) -> void:
	var strength: float
	if art_name=="ep1_mainstreet_choice":
		var progress: float=clampf(frame_time/float(maxi(1,frames.size()-1)),0.0,1.0)
		var eased: float=smoothstep(0.0,1.0,progress)
		strength=1.0-eased if phase=="intro" else eased
	elif spec.has("eye_blur"):
		strength=EYE_CLOSURE.blur_strength_at(frame_time,phase,spec.eye_blur)
	else:return
	for key: String in spec.parts:
		if not spec.parts[key].has("blur"):continue
		var paint: ShaderMaterial=sprites[key].get_child(0).material
		paint.set_shader_parameter("blur_strength",strength)

func has_outro() -> bool:return spec.outro.size()>1
func duration(next_phase: String) -> float:return float(spec[next_phase].size())/catalog().fps

func same_clip(art: String) -> bool:
	if not has_art(art):return false
	var other: Dictionary=catalog().art[art]
	return spec.get("clip","")==other.get("clip","_")

static func normalized_caption(text: String) -> String:
	return " ".join(text.replace("\n"," ").replace("\r"," ").replace("\t"," ").split(" ",false))

func bind_caption(label: Label, alias: String = "", decoration: Control = null) -> void:
	if caption_data.is_empty():
		for filename: String in DirAccess.get_files_at("res://data"):
			if filename.begins_with("episode") and filename.ends_with("_text_animations.json"):
				caption_data.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/"+filename)))
	if not caption_data.has(art_name):return
	var text: String=normalized_caption(label.text if alias.is_empty() else alias)
	if not caption_data[art_name].anchors.has(text) and alias.is_empty():
		if caption_aliases.is_empty():
			LOC.prepare()
			for table: Dictionary in LOC.tables.values():
				for values: Dictionary in table.rows.values():
					var original: String=normalized_caption(values.get("ru",""))
					if original.is_empty():continue
					for translation: String in values.values():
						if not translation.is_empty():caption_aliases[normalized_caption(translation)]=original
		text=caption_aliases.get(text,text)
	if not caption_data[art_name].anchors.has(text):return
	if spec.has("caption_mask"):
		var clip := ShaderMaterial.new();clip.shader=CAPTION_CLIP
		label.material=clip
		if label.get("shadow_pass") is Label:
			label.shadow_pass.material=label.shadow_pass.material.duplicate()
			label.shadow_pass.material.set_shader_parameter("clip_enabled",true)
	captions.append({"label":label,"text":text,"origin":label.position,"scale":label.scale,"color":label.modulate,"inverse":_caption_inverse(text)})
	if decoration!=null:
		captions.append({"label":decoration,"text":text,"origin":decoration.position,"scale":decoration.scale,"color":decoration.modulate,"inverse":_caption_inverse(text)})
	_update_captions(current_frame)
func _caption_inverse(text: String) -> Transform2D:
	var base: Array=caption_data[art_name].anchors[text]
	return Transform2D(Vector2(base[0],base[1]),Vector2(base[2],base[3]),Vector2(base[4],base[5])*2).affine_inverse()
func _update_captions(index: int) -> void:
	if captions.is_empty():return
	var spec_text: Dictionary=caption_data[art_name]
	var row: Array=spec_text[phase][mini(index,spec_text[phase].size()-1)]
	for entry: Dictionary in captions:
		var label: Control=entry.label
		if not is_instance_valid(label):continue
		label.visible=false
		for record: Array in row:
			if record[0]!=entry.text:continue
			var m: Array=record[1];var c: Array=record[2]
			var pose:=Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5])*2)
			var delta: Transform2D=pose*entry.inverse
			label.position=delta*entry.origin;label.scale=entry.scale*delta.get_scale();label.rotation=delta.get_rotation()
			label.modulate=entry.color*Color(c[0],c[1],c[2],c[3]);label.visible=true
			if spec.has("caption_mask") and label is Label:
				var areas: Array=spec.caption_mask[phase]
				var area: Array=areas[mini(index,areas.size()-1)]
				var rect := get_global_transform()*Rect2(float(area[0])*2,float(area[1])*2,float(area[2])*2,float(area[3])*2)
				var uniform := Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y)
				label.material.set_shader_parameter("clip_rect",uniform)
				if label.get("shadow_pass") is Label:label.shadow_pass.material.set_shader_parameter("clip_rect",uniform)
			break

# Independent MovieClips driven by an activity (ratchet lock, keypad lamps).
func apply_variable_frame(variable: String, index: int) -> void:
	var poses: Array=spec.get("variables",{}).get(variable,[])
	if poses.is_empty():return
	index=clampi(index,0,poses.size()-1)
	if variable_poses.get(variable,-1)==index:return
	variable_poses[variable]=index
	for key: String in variable_keys[variable]:sprites[key].visible=false
	for record: Array in poses[index]:
		var pivot: Node2D=sprites[record[0]]
		var m: Array=record[1];var c: Array=record[2]
		pivot.transform=Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5])*2)
		var visual: Control=pivot.get_child(0)
		var paint: ShaderMaterial=visual.material
		if visual.get_meta("interactive_highlight",false):
			visual.modulate=Color(c[0],c[1],c[2],c[3]*float(visual.get_meta("highlight_opacity",1.0)))
		elif paint:
			paint.set_shader_parameter("multiplier",Color(c[0],c[1],c[2],c[3]))
			paint.set_shader_parameter("offset",Vector3(c[4],c[5],c[6]))
		else:visual.modulate=Color(c[0],c[1],c[2],c[3])
		pivot.visible=true
