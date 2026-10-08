extends SceneTree
const TIMELINE := preload("res://scripts/ui/episode_timeline.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var stage:=SubViewport.new();stage.size=Vector2i(1600,960)
	stage.transparent_bg=true;stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	for art: String in ["e2_hospital_4","john2_12"]:
		var player:=TIMELINE.new();stage.add_child(player);player.configure(art);player.suspended=true
		check(player.masked_keys.size()==3,"three independent ECG windows: "+art)
		for key: String in player.masked_keys:
			var mask_key: String=player.spec.parts[key].mask_key
			check(player.spec.parts[mask_key].type=="mask","mask is geometry")
			check(not player.spec.parts[mask_key].has("texture"),"no painted mask bitmap")
			check(player.sprites[mask_key].get_child(0).get_class()=="Control","mask cannot paint a black plate")
		var samples: Array[int]=[0,7,14]
		if art=="john2_12":samples.append_array([22,40,47,254,255,270,320])
		for frame: int in samples:
			player.seek_frame(frame)
			for key: String in player.masked_keys:
				var image: Control=player.sprites[key].get_child(0)
				var paint: ShaderMaterial=image.material
				check(paint.get_shader_parameter("art_mask_enabled"),"clip enabled")
				var mask_key: String=player.spec.parts[key].mask_key
				var mask: Dictionary=player.spec.parts[mask_key]
				var m: Array=mask.mask_matrix;var r: Array=mask.mask_rect
				var reference:=Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5])*2)
				var mapping: Transform2D=(player.sprites[mask_key].get_global_transform()*reference).affine_inverse()*image.get_global_transform()
				var x: Vector3=paint.get_shader_parameter("art_mask_x")
				var y: Vector3=paint.get_shader_parameter("art_mask_y")
				if not player.sprites[mask_key].visible:
					check(x.z<0.0 and y.z<0.0,"missing source mask hides its curve")
					continue
				for uv: Vector2 in [Vector2.ZERO,Vector2(0.5,0.5),Vector2.ONE]:
					var expected: Vector2=(mapping*(uv*image.size)-Vector2(r[0],r[1])*2)/(Vector2(r[2],r[3])*2)
					var actual:=Vector2(x.dot(Vector3(uv.x,uv.y,1)),y.dot(Vector3(uv.x,uv.y,1)))
					check(actual.is_equal_approx(expected),"UV clips in authored rotated mask space")
			if DisplayServer.get_name()!="headless":
				# Render only curves/masks to prove no opaque pixels leak outside any
				# original mask. Parent background must not hide a failed clip.
				for key: String in player.sprites:
					if key not in player.masked_keys and player.spec.parts[key].type!="mask":player.sprites[key].visible=false
				await RenderingServer.frame_post_draw
				var pixels: Image=stage.get_texture().get_image()
				var leaked:=0;var covered:=0
				for py: int in range(90,415):
					for px: int in range(40,575):
						if pixels.get_pixel(px,py).a<0.01:continue
						covered+=1;var inside:=false
						for key: String in player.masked_keys:
							var mk: String=player.spec.parts[key].mask_key
							if not player.sprites[mk].visible:continue
							var mask: Dictionary=player.spec.parts[mk];var m: Array=mask.mask_matrix;var r: Array=mask.mask_rect
							var basis:=Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5])*2)
							var local: Vector2=(player.sprites[mk].get_global_transform()*basis).affine_inverse()*Vector2(px+0.5,py+0.5)
							if Rect2(Vector2(r[0],r[1])*2,Vector2(r[2],r[3])*2).has_point(local):inside=true;break
						if not inside:leaked+=1
				check(leaked==0,"GPU: no waveform pixels outside masks")
				if (art=="e2_hospital_4" and frame==7) or (art=="john2_12" and frame==22):
					check(covered>100,"GPU: clip preserves visible waveform: "+art+" (%d pixels)" % covered)
		if art=="john2_12":check(player.playing and player.spec.intro_loop==32,"John ECG loops beyond export horizon")
		else:check(not player.playing,"hospital death reaches original stop frame")
		player.free()
	stage.queue_free();await process_frame
	if failures==0:print("PASS: %d ECG mask checks" % checks)
	quit(0 if failures==0 else 1)
