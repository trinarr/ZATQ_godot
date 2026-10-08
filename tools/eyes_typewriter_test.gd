extends SceneTree
const EYE := preload("res://scripts/ui/eye_closure.gd")
const TIMELINE := preload("res://scripts/ui/episode_timeline.gd")
const TEXT := preload("res://scripts/ui/shared/shader_text.gd")
const TYPEWRITER := preload("res://scripts/ui/shared/typewriter_text.gd")
const BLOCK := preload("res://scripts/ui/shared/narrative_block.gd")
const FONT := preload("res://fonts/flash/font_2.ttf")
var checks:=0
var failures:=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var catalog: Dictionary=TIMELINE.catalog()
	for art: String in catalog.art:
		var spec: Dictionary=catalog.art[art]
		if not spec.has("eye_blur") or spec.eye_blur.closing:continue
		var result: Array=EYE.smooth_frames(spec.intro,spec.parts,19)
		var last: int=int(spec.eye_blur.frames[1])
		var fade_start: float=last*EYE.OPEN_FADE_START
		var end: int=ceili(fade_start+EYE.OPEN_FADE_SECONDS*19)
		check(result.size()>end,"eye opening extends to fade completion: "+art)
		var final: Dictionary={}
		for pose: Array in spec.intro[last]:
			if spec.parts[pose[0]].has("eye_lid"):final[pose[0]]=pose
		for i: int in range(end+1):
			var count:=0
			for pose: Array in result[i]:
				if not spec.parts[pose[0]].has("eye_lid"):continue
				count+=1
				var alpha: float=float(pose[2][3])
				check(alpha>=0.0 and alpha<=1.0,"fade alpha is bounded")
				if i<=floori(fade_start):check(is_equal_approx(alpha,1.0),"opaque until 70% opening")
				if i>ceili(fade_start) and i<end:check(alpha<1.0 and alpha>0.0,"fade begins during opening")
				if i==end:check(is_zero_approx(alpha),"no black edge at opening end")
				if i>last:
					var direction: float=-1.0 if spec.parts[pose[0]].eye_lid=="upper" else 1.0
					check((float(pose[1][5])-float(final[pose[0]][1][5]))*direction>0.0,"lids keep separating during fade tail")
			check(count==2,"both lids retain their movement through fade")
		check(spec.intro.size()==last+2,"source tracks are never mutated")

	for art: String in ["john2_1","john2_9"]:
		check(not catalog.art[art].has("caption_mask"),"typewriter has no clipping mask")
		# Only its narrative binding is needed to test reveal playback. Omit
		# scenery here to avoid unrelated asset dependencies.
		var original: Dictionary=catalog.art[art]
		var fixture: Dictionary=original.duplicate(true);fixture.parts={}
		fixture.intro=[[],[]];fixture.outro=[[]]
		catalog.art[art]=fixture
		var player:=TIMELINE.new();root.add_child(player);player.configure(art);player.suspended=true
		var label:=TEXT.new();root.add_child(label);label.add_theme_font_override("font",FONT)
		var tracks: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/episode101_text_animations.json"))
		label.text=tracks[art].anchors.keys()[0];label.position=Vector2(80,758);label.size=Vector2(1440,164)
		player.bind_caption(label)
		check(label.visible_characters==0,"text starts empty")
		check(player.frames.size()>2,"reveal can finish after authored fade")
		var origin: Vector2=label.position;var before:=0
		for frame: int in player.frames.size():
			player.seek_frame(frame,0.5)
			check(label.visible_characters>=before,"letters reveal monotonically")
			check(label.position==origin,"full text layout stays fixed")
			check(label.shadow_pass.visible_characters==label.visible_characters,"shadow reveals the same characters")
			before=label.visible_characters
		check(before==label.get_total_character_count(),"complete title remains visible")
		player.play("intro");check(label.visible_characters==0,"new playback resets reveal")
		player.play("outro");check(label.visible_characters==label.get_total_character_count(),"outro keeps complete title")
		player.free();label.free();catalog.art[art]=original
	var host:=Control.new();root.add_child(host)
	var block:=BLOCK.new();block.configure(host,"Обычный текст",Rect2(10,10,200,40),FONT,24,{"storage":host})
	TYPEWRITER.apply(block.label,0.1)
	block.configure(host,"Следующий обычный текст",Rect2(10,10,200,40),FONT,24,{"storage":host})
	check(block.label.visible_characters==-1,"pooled narrative resets character limit")
	var standalone:=EYE.new();root.add_child(standalone);standalone.configure_default();standalone.set_closure(1.0)
	standalone.animate_closure(0.0,1.0);await standalone.finished
	check(is_zero_approx(standalone.modulate.a),"standalone opening fades completely")
	check(is_zero_approx(standalone.closure),"standalone state remains fully open")
	check(standalone.lids.upper.position.y<46.0*2 and standalone.lids.lower.position.y>296.95*2,"standalone movement continues beyond the original open pose")
	standalone.queue_free()
	host.queue_free();await process_frame
	if failures==0:print("PASS: %d eye fade and typewriter checks" % checks)
	quit(0 if failures==0 else 1)
