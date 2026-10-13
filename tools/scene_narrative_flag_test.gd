extends SceneTree
const MODEL := preload("res://addons/story_graph/graph.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var graph: Dictionary = {"version":1,"episode":1,"start":"custom_intro","variables":{"ReadCustomIntro":false},"nodes":{
		"custom_intro":{"type":"scene","data":{"kind":"city_story","art":"layout_bg_morning_choice","text":"Custom narrative","narrative_flag":"ReadCustomIntro","blocks":[{"text":"Custom narrative","rect":[70,20,660,120],"font":"Oswald Medium","size":24}]}},
		"after_intro":{"type":"scene","data":{"kind":"city_story","art":"layout_bg_morning_choice","text":""}},
		"continue":{"type":"choice","data":{"text":"Continue"}},
		"repeat":{"type":"choice","data":{"text":"Repeat"}},
		"reset_flag":{"type":"action","data":{"set":{"ReadCustomIntro":false}}}},"edges":[
		{"from":"custom_intro","port":"choice:0","to":"continue"},
		{"from":"continue","port":"next","to":"after_intro"},
		{"from":"after_intro","port":"choice:0","to":"repeat"},
		{"from":"repeat","port":"next","to":"custom_intro"},
		{"from":"repeat","port":"effects","to":"reset_flag"}]}
	check(MODEL.validate(graph).is_empty(), "arbitrary scene and narrative variable accepted")
	var broken: Dictionary = graph.duplicate(true)
	broken.variables.ReadCustomIntro = 0
	check(not MODEL.validate(broken).is_empty(), "non-boolean narrative variable rejected")
	broken = graph.duplicate(true)
	broken.variables.erase("ReadCustomIntro")
	check(not MODEL.validate(broken).is_empty(), "undeclared narrative variable rejected")
	broken = graph.duplicate(true)
	broken.nodes.custom_intro.data.text = ""
	check(not MODEL.validate(broken).is_empty(), "empty narrative text rejected")
	var quest: Node = root.get_node("Quest")
	quest.save_path = "user://scene_narrative_flag_test.json"
	quest.tmp_path = "user://scene_narrative_flag_test.tmp"
	quest.backup_path = "user://scene_narrative_flag_test.bak"
	quest.sound_enabled = false
	var ui: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(ui)
	ui.playing = true
	quest.new_game(1)
	var compiled: Dictionary = MODEL.compile(graph)
	check(compiled.custom_intro.narrative_flag == "ReadCustomIntro", "graph compiler retains narrative flag")
	quest.nodes.merge(compiled, true)
	quest.episode_defaults[1].ReadCustomIntro = false
	quest.flags.ReadCustomIntro = false
	quest._enter("custom_intro")
	check(quest.scene_narrative_pending(), "custom scene enters narrative state")
	check(ui.narrative_layer.active == 1 and ui.world_layer.get_child_count() == 1, "generic scene shows only narrative dismissal")
	quest.choose(0)
	check(quest.current_id == "custom_intro", "story choice cannot bypass visible narrative")
	var dismiss: Button = ui.world_layer.get_child(0)
	dismiss.pressed.emit()
	check(quest.current_id == "custom_intro" and quest.flags.ReadCustomIntro, "tap marks story variable without changing scene")
	check(not quest.scene_narrative_pending() and quest.current().text.is_empty() and quest.current().blocks.is_empty(), "completed narrative text and blocks suppressed")
	check(ui.narrative_layer.active == 0, "narrative removed before interactive content")
	check(quest._read(quest.save_path).flags.ReadCustomIntro, "narrative variable saved immediately")
	var restored: Node = load("res://scripts/core/quest_state.gd").new()
	restored.nodes.merge(compiled, true)
	restored.save_path = quest.save_path
	restored.tmp_path = quest.tmp_path
	restored.backup_path = quest.backup_path
	root.add_child(restored)
	check(restored.current_id == "custom_intro" and restored.scene_narrative_seen("custom_intro"), "custom narrative variable survives save reload")
	restored.free()
	quest.choose(0)
	check(quest.current_id == "after_intro", "normal graph transition available after narrative")
	quest.choose(0)
	check(quest.current_id == "custom_intro" and quest.scene_narrative_pending(), "graph action resets variable and replays narrative")
	quest.flags.erase("ReadCustomIntro")
	quest.episode_defaults[1].ReadCustomIntro = true
	check(quest.scene_narrative_seen("custom_intro"), "missing old-save variable uses declared default")
	var editor: Control = load("res://addons/story_graph/editor.gd").new()
	root.add_child(editor)
	await process_frame
	editor._inspect_id("morning_choice")
	var found := false
	for child: Node in editor.inspector.get_children():
		if child is Label and child.text == "Переменная: описание прочитано": found = true
	check(found, "scene inspector exposes narrative variable field")
	editor.free()
	ui.free()
	await process_frame
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("Scene narrative variables: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
