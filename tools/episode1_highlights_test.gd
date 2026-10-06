extends SceneTree
const HIGHLIGHT := preload("res://scripts/ui/interactive_highlight.gd")
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var definitions: Dictionary = HIGHLIGHT.definitions()
	check(definitions.regions.size()==15 and definitions.masks.size()==8,"all original overlay and hit shapes converted")
	for id: String in definitions.regions:
		var region: Dictionary = definitions.regions[id]
		var cached: Dictionary = HIGHLIGHT.build_region(id)
		check(cached.texture!=null and cached.hit_image!=null,"vector mask builds without PNG")
		check(cached.hit_image.get_size()==Vector2i(region.size[0],region.size[1]),"hit mask preserves original dimensions")
		check(cached.texture.get_size()==Vector2(region.size[0]+12,region.size[1]+12),"transparent padding prevents feather clipping")
		check(HIGHLIGHT.build_region(id).texture==cached.texture,"same contour reuses runtime texture")
		check(cached.material.shader==HIGHLIGHT.SHADER,"all regions use shared soft pulse shader")
		check(float(cached.material.get_shader_parameter("alpha_max"))>float(cached.material.get_shader_parameter("alpha_min")),"blink range matches original alpha states")
		var c: Color = cached.material.get_shader_parameter("glow_color")
		check(c.r>c.g*2 and c.r>c.b*2,"original red tint retained")
	for id: String in definitions.masks:
		check(HIGHLIGHT.mask_image(id)==HIGHLIGHT.build_region(definitions.masks[id]).hit_image,"interaction reuses same contour")
		check(not FileAccess.file_exists("res://assets/flash_ui/"+id+".png"),"duplicated hit PNG deleted")
	# Export for exact silhouette comparison with original resources in Python.
	for id: String in definitions.regions:
		HIGHLIGHT.build_region(id).hit_image.save_png("/tmp/zatq_"+id+".png")
	var quest: Node=root.get_node("Quest")
	quest.sound_enabled=false
	quest.save_path="user://highlights_test.json";quest.tmp_path="user://highlights_test.tmp";quest.backup_path="user://highlights_test.bak"
	var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
	quest.new_game(1)
	for node: String in ["morning_choice","transport","farm_boundary","farm_inside","metro_junction"]:
		if not quest.nodes.has(node):continue
		quest.flags={"Auto":0,"TakenKey":false,"BulletsNumber":-1,"LinkedFr":false}
		quest.current_id=node;ui.playing=true;ui.paused=false;ui._show_story()
		await process_frame
		for glow: Node in ui.screen.find_children("*","TextureRect",true,false):
			if glow.has_meta("interactive_highlight"):
				check(glow.mouse_filter==Control.MOUSE_FILTER_IGNORE,"glow does not intercept taps")
				check(glow.texture.resource_path.is_empty(),"glow uses only in-memory mask")
	quest.flags.TakenKey=true;quest.current_id="transport";ui._show_story()
	await process_frame
	var regions: Array[String]=[]
	for glow: Node in ui.screen.find_children("*","TextureRect",true,false):
		if glow.has_meta("interactive_highlight"):regions.append(glow.region_id)
	var key_region := ""
	for part: Dictionary in ui.episode_components.layout_controls_transport:
		if String(part.source).begins_with("But2/"): key_region=part.region
	check(not key_region.is_empty() and not regions.has(key_region),"taken keys do not retain interactive glow")
	ui._show_pause();ui._resume()
	check(ui.playing and not ui.paused,"dynamic overlays survive pause/re-entry")
	ui.queue_free();await process_frame
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	print("PASS: %d dynamic highlight checks; failures %d" % [checks,failures])
	quit(1 if failures else 0)
