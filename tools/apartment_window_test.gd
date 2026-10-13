extends SceneTree
var checks := 0
var failures := 0

class View extends Control:
	var hits: Array = []
	func _component_backdrop(_name: String) -> void: pass
	func _world_host() -> Control: return self
	func _world_hit(_label: String, rect: Rect2, action: Callable, mask: String) -> Button:
		var button := Button.new()
		button.pressed.connect(action)
		add_child(button)
		hits.append({"button":button,"mask":mask,"rect":rect})
		return button

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var quest: Node = root.get_node("Quest")
	var apartment: GDScript = load("res://scripts/ui/apartment_preview.gd")
	quest.save_path = "user://apartment_window_test.json"
	quest.tmp_path = "user://apartment_window_test.tmp"
	quest.backup_path = "user://apartment_window_test.bak"
	quest.sound_enabled = false
	var components: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/episode1_components.json"))
	var animations: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/episode1_animations.json"))
	check(components.layout_bg_screams == components.layout_bg_wake, "story advances over the same city background")
	check(not animations.art.has("layout_bg_screams"), "old animated traffic overlay cannot appear in story")
	check(components.layout_bg_apartment_window[0].rect == [60.0,36.0,680.0,408.0], "window city is centered at 85 percent")
	check(components.layout_bg_apartment_window[0].shader == "res://shaders/city_window_grade.gdshader", "window city has a separate cool grade")
	var window_parts: Array = components.layout_bg_apartment_window
	var collision: Array = window_parts.filter(func(part): return part.get("source", "") == "window_overlay:side_impact_collision")
	check(collision.size() == 1 and collision[0].texture == "apartment/window_collision.png", "side impact replaces the old collision and both road bodies")
	var glass: Array = window_parts.filter(func(part): return part.get("source", "") == "window_overlay:glass_reflections")
	check(glass.size() == 1 and glass[0].shader == "res://shaders/window_glass.gdshader", "glass reflections have a separate world layer")
	check(window_parts[-2].source == "window_overlay:glass_reflections", "glass covers street activity below the frame")
	check(window_parts[-1].texture == "apartment/window_frame.png" and window_parts[-1].rect == [0,0,800,480], "intact frame has one geometry at all four corners")
	check(window_parts[-1].shader == "res://shaders/window_frame_fit.gdshader", "frame fit preserves existing pane height and corner alignment")
	check(components.layout_bg_apartment_window[-1].source == "window_overlay:jack_living_window_frame", "frame is rendered above city and traffic")
	quest.new_game(1)
	var wake_text: String = quest.current().text
	quest.choose(0)
	check(quest.current_id == "screams" and quest.current().text != wake_text, "first tap advances original story text")
	quest.choose(0)
	check(quest.current_id == "morning_choice", "second story tap reaches living room")
	var flags: Dictionary = quest.flags.duplicate(true)
	var view := View.new()
	root.add_child(view)
	apartment.draw(view)
	var windows: Array = view.hits.filter(func(hit: Dictionary): return hit.mask == "living_window")
	check(windows.size() == 1, "living window has one hotspot")
	windows[0].button.pressed.emit()
	check(quest.current_id == "apartment_window", "window tap enters inspection scene")
	check(quest.current().text == "ТЕСТ", "inspection caption is the requested placeholder")
	check(quest.flags == flags, "inspection preserves story flags")
	var saved: Variant = quest._read(quest.save_path)
	check(saved.current_id == "apartment_window", "inspection location is saved")
	quest.choose(0)
	check(quest.current_id == "morning_choice", "inspection screen tap returns to living room")
	quest.navigate_apartment("city_foot")
	check(quest.current_id == "morning_choice", "other unreviewed exits remain blocked")
	view.free()
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("Apartment window: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
