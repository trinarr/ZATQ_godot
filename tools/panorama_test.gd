extends SceneTree
const CANVAS := preload("res://scripts/ui/adaptive_landscape_canvas.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/animation_viewport_audit.json"))
	var canvas:=CANVAS.new();root.add_child(canvas)
	for entry: Dictionary in report.changes:
		check(canvas.set_episode_background(entry.art),"repaired scene has timeline: "+entry.art)
		var player: Node2D=canvas.episode_timeline
		player.suspended=true
		var visual: TextureRect=player.sprites[entry.key].get_child(0)
		var r: Array=entry.after.rect
		check(visual.texture!=null,"texture loads: "+entry.art)
		if visual.texture==null:continue
		check(visual.texture.get_size()==Vector2(r[2],r[3])*2,"PNG and rect retain source scale: "+entry.art)
		for phase: String in ["intro","outro"]:
			player.play(phase)
			for frame: int in player.frames.size():
				player.seek_frame(frame)
				for row: Array in player.frames[frame]:
					if row[0]!=entry.key:continue
					var m: Array=row[1]
					check(player.sprites[entry.key].transform.origin.is_equal_approx(Vector2(m[4],m[5])*2),"authored translation: "+entry.art)
	canvas.set_episode_background("ep1_dorvud_street")
	var dorvud: Node2D=canvas.episode_timeline;dorvud.suspended=true
	var key: String=dorvud.spec.parts.keys()[0]
	var picture: TextureRect=dorvud.sprites[key].get_child(0)
	for frame: int in dorvud.frames.size():
		dorvud.seek_frame(frame)
		var bounds: Rect2=dorvud.sprites[key].transform*picture.get_rect()
		check(bounds.encloses(Rect2(0,0,1600,960)),"Dorvud panorama covers stage at frame %d" % frame)
	for size: Vector2 in [Vector2(1600,960),Vector2(2400,1080),Vector2(1280,960)]:
		canvas.update_layout(size)
		check(canvas.art_layer.clip_contents,"panorama clipped at Flash stage")
		check(canvas.art_layer.size==Vector2(1600,960),"clip uses authored stage dimensions")
		check(canvas.safe_layer.get_rect().encloses(Rect2(canvas.art_layer.position,canvas.art_layer.size*canvas.art_layer.scale)),"stage fits device")
	canvas.set_component_background([])
	check(not canvas.art_layer.clip_contents,"static components retain existing layout")
	canvas.queue_free();await process_frame
	if failures==0:print("PASS: %d panorama checks" % checks)
	quit(0 if failures==0 else 1)
