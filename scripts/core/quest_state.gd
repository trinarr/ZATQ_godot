extends Node
const LOC := preload("res://scripts/core/localization.gd")

signal changed
signal save_failed(message: String)

const STORY_GRAPH := preload("res://addons/story_graph/graph.gd")
const SAVE_PATH := "user://zombie_quest_v1.json"
const TMP_PATH := "user://zombie_quest_v1.tmp"
const BACKUP_PATH := "user://zombie_quest_v1.bak"
var save_path: String = SAVE_PATH
var tmp_path: String = TMP_PATH
var backup_path: String = BACKUP_PATH
const VERSION := 1
const TV_IMAGES := ["flash_2821.png", "flash_2823.png", "flash_2825.png", "flash_2827.png", "flash_2829.png", "flash_2831.png", "flash_2833.png"]
var nodes: Dictionary = {}
var current_id: String = ""
var popup_origin: String = ""
var activity: Dictionary = {}
var flags: Dictionary = {"TakenKey": false, "Auto": 0}
var episode_starts: Dictionary = {}
var episode_defaults: Dictionary = {}
var episode_metadata: Dictionary = {}
var extra_stats: Dictionary = {}
var episode: int = 1
var episode2_stats: Dictionary = {"wins":0,"losses":0,"endings":[]}
var channel: int = 0
var sound_enabled: bool = true
var has_progress: bool = false
var recovery_message: String = ""
var episode1_stats: Dictionary = {"wins":0,"losses":0,"endings":[]}
var result_recorded: bool = false
# Bounded view cache. Callers treat resolved nodes as read-only presentation data.
var _view_cache: Dictionary = {}
var current_resolutions := 0
var save_writes := 0
var _last_saved_text := ""
var _last_saved_paths := ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _view_cache.clear()

func _ready() -> void:
	LOC.prepare()
	for filename: String in DirAccess.get_files_at("res://data/story_graphs"):
		if not filename.begins_with("episode") or not filename.ends_with(".json"): continue
		var path: String = "res://data/story_graphs/" + filename
		var graph: Dictionary = STORY_GRAPH.load_graph(path)
		var errors: PackedStringArray = STORY_GRAPH.validate(graph)
		if not errors.is_empty():
			push_error("Invalid story graph: " + path + "\n" + "\n".join(errors))
			continue
		nodes.merge(STORY_GRAPH.compile(graph), true)
		episode_starts[int(graph.episode)] = graph.start
		episode_defaults[int(graph.episode)] = graph.get("variables",{})
		episode_metadata[int(graph.episode)] = graph
	_load_save()

func current(id: String = "") -> Dictionary:
	var key: String = current_id if id.is_empty() else id
	var node: Dictionary = nodes.get(key, {})
	var locale: String = TranslationServer.get_locale()
	var entry: Dictionary = _view_cache.get(key,{})
	# Hash the source too: editor/tests can replace or modify a graph in place.
	var source_hash: int = node.hash()
	if not entry.is_empty() and entry.locale == locale and entry.source_hash == source_hash and entry.flags == flags:
		return entry.view
	var resolved: Dictionary = node
	if node.has("variants"):
		resolved = node.duplicate(true)
		for variant: Dictionary in node.variants:
			if matches(variant.when):
				for field: String in variant:
					if field != "when": resolved[field] = variant[field]
	var view: Dictionary = _substitute_flags(LOC.resolve_tree(resolved))
	current_resolutions += 1
	if _view_cache.size() >= 16: _view_cache.erase(_view_cache.keys()[0])
	_view_cache[key] = {"locale":locale,"source_hash":source_hash,"flags":flags.duplicate(true),"view":view}
	return view

func _substitute_flags(value: Variant) -> Variant:
	if value is String:
		if not value.contains("{"): return value
		for key: String in flags:
			if flags[key] is String or flags[key] is int or flags[key] is float:
				value = value.replace("{"+key+"}",str(flags[key]))
		return value
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[key] = _substitute_flags(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_substitute_flags(item))
		return result
	return value

func _initialize_random_values() -> void:
	for key: String in nodes[current_id].get("random_values",{}):
		if not str(flags.get(key,"")).is_empty(): continue
		var rule: Dictionary = nodes[current_id].random_values[key]
		var digits: String = str(roundi(randf()*float(int(rule.maximum)-int(rule.minimum)))+int(rule.minimum))
		digits = digits.lpad(int(rule.get("digits",0)),"0")
		flags[key] = str(rule.get("prefix",""))+digits+str(rule.get("suffix",""))
		if rule.has("spaced_variable"):
			var parts: PackedStringArray = []
			for character: String in digits: parts.append(character)
			flags[rule.spaced_variable] = str(rule.get("prefix",""))+"-".join(parts)+str(rule.get("suffix",""))

func matches(conditions: Dictionary) -> bool:
	for key: String in conditions:
		var expected: Variant = conditions[key]
		var value: Variant = flags.get(key)
		if expected is Dictionary:
			if not (value is int or value is float): return false
			if expected.has("min") and value < expected.min: return false
			if expected.has("max") and value > expected.max: return false
		elif value != expected: return false
	return true

func stats_for(number: int) -> Dictionary:
	if number == 1: return episode1_stats
	if number == 2: return episode2_stats
	if not extra_stats.has(str(number)): extra_stats[str(number)] = {"wins":0,"losses":0,"endings":[]}
	return extra_stats[str(number)]

func available_choices() -> Array:
	var result: Array = []
	for choice in current().get("choices", []):
		if choice.get("unless_keys", false) and flags.TakenKey:
			continue
		if not matches(choice.get("requires",{})): continue
		result.append(choice)
	return result

func ending_count(number: int) -> int:
	var endings: Array = []
	for node: Dictionary in nodes.values():
		if int(node.get("episode",1))==number and node.get("alive",false) and node.has("result_id"):
			var ending_id: int = int(node.get("ending_id",node.result_id))
			if ending_id not in endings: endings.append(ending_id)
	return endings.size()

func new_game(number: int = 1) -> void:
	if not episode_starts.has(number): return
	episode = number
	result_recorded = false
	activity = {}
	flags = {"TakenKey": false, "Auto": 0, "BulletsNumber": -1, "LinkedFr": false}
	flags.merge(episode_defaults.get(number,{}),true)
	channel = 0
	has_progress = true
	var metadata: Dictionary = episode_metadata.get(number,{})
	var start: String = episode_starts[number]
	var continuations: Dictionary = metadata.get("continuations",{})
	if not continuations.is_empty():
		var previous: Dictionary = stats_for(number-1)
		var last: int = int(previous.get("last_ending",previous.endings[-1] if not previous.endings.is_empty() else -1))
		start = continuations.get(str(last),start)
	_enter(start)

func _enter(id: String) -> void:
	if not nodes.has(id):
		return
	if nodes[id].get("kind","") in ["item","city_pickup","city_death","city_ending"] and current().get("kind","") not in ["item","city_pickup","city_death","city_ending"]:
		popup_origin = current_id if int(current().get("episode",1)) == int(nodes[id].get("episode",1)) else ""
	if current_id != id: activity = {}
	current_id = id
	_initialize_random_values()
	episode = int(nodes[id].get("episode",1))
	channel = 0
	var pickup: Dictionary = current().get("pickup_if",{})
	if not pickup.is_empty() and matches(pickup.when):
		_enter(pickup.next)
		return
	var settings: Dictionary = current().get("set", {})
	for key in settings:
		flags[key] = settings[key]
	var additions: Dictionary = current().get("add", {})
	for key in additions:
		flags[key] = flags.get(key,0) + additions[key]
	_record_result()
	save_game()
	changed.emit()

func _record_result() -> void:
	if result_recorded: return
	var node: Dictionary = current()
	if not node.has("result_id"): return
	result_recorded = true
	var stats: Dictionary = stats_for(episode)
	if node.get("alive",false):
		stats.wins += 1
		var result_id: int = int(node.get("ending_id",node.result_id))
		stats.last_ending = result_id
		if result_id not in stats.endings:
			stats.endings.append(result_id)
	else:
		stats.losses += 1

func choose(index: int) -> void:
	var choices: Array = available_choices()
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	if choice.get("disabled",false): return
	if choice.get("action", "") == "channel":
		next_channel()
		return
	var routed_target: String = choice.get("next", "")
	for route: Dictionary in choice.get("next_cases",[]):
		if matches(route.when):
			routed_target = route.next
			break
	for key in choice.get("add", {}):
		flags[key] = flags.get(key,0) + choice.add[key]
	for key in choice.get("set", {}):
		flags[key] = choice.set[key]
	var target: String = routed_target
	if flags.TakenKey and choice.has("with_keys"):
		target = choice.with_keys
	if flags.Auto == 1 and choice.has("by_car"):
		target = choice.by_car
	_enter(target)

func next_channel() -> void:
	if current_id != "tv":
		return
	if channel == TV_IMAGES.size() - 1:
		_enter("morning_choice")
	else:
		channel += 1
		save_game()
		changed.emit()

func set_sound(enabled: bool) -> void:
	sound_enabled = enabled
	save_game()

func _snapshot() -> Dictionary:
	return {"version":VERSION,"extra_stats":extra_stats,"activity":activity,"current_id":current_id,"popup_origin":popup_origin,"flags":flags,"channel":channel,"sound_enabled":sound_enabled,"has_progress":has_progress,"episode":episode,"episode1_stats":episode1_stats,"episode2_stats":episode2_stats,"result_recorded":result_recorded}

func _valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != VERSION:
		return false
	if not data.get("popup_origin","") is String or (not str(data.get("popup_origin","")).is_empty() and not nodes.has(data.popup_origin)): return false
	if not data.get("current_id") is String or not data.get("flags") is Dictionary:
		return false
	if not data.get("has_progress") is bool or not data.get("sound_enabled") is bool:
		return false
	if data.has_progress and not nodes.has(data.current_id):
		return false
	if not data.flags.get("TakenKey") is bool:
		return false
	var auto: Variant = data.flags.get("Auto")
	if not (auto is int or auto is float) or auto != int(auto) or int(auto) not in [0, 1]:
		return false
	if data.has("result_recorded") and not data.result_recorded is bool: return false
	var saved_episode: Variant = data.get("episode",1)
	if not (saved_episode is int or saved_episode is float) or saved_episode != int(saved_episode) or not episode_starts.has(int(saved_episode)): return false
	var bullets: Variant = data.flags.get("BulletsNumber",-1)
	var max_bullets: int = 16 if int(saved_episode)>=3 else 12
	if not (bullets is int or bullets is float) or bullets != int(bullets) or bullets < -1 or bullets > max_bullets: return false
	if not data.flags.get("LinkedFr",false) is bool: return false
	for key: String in ["TakenDocs","TakenArmor","CabinCodeKnown"]:
		if not data.flags.get(key,false) is bool: return false
	for key: String in ["PilotCode","PilotCodeSpaced"]:
		if not data.flags.get(key,"") is String: return false
	if data.has_progress and int(nodes.get(data.current_id,{}).get("episode",1)) != int(saved_episode): return false
	for number: int in [1,2]:
		var stats_key := "episode%d_stats" % number
		if data.has(stats_key) and not _valid_stats(data[stats_key],[6,77,78] if number==1 else [38,43,47]): return false
	if not data.get("extra_stats",{}) is Dictionary: return false
	for key: String in data.get("extra_stats",{}):
		if not key.is_valid_int() or not episode_starts.has(int(key)): return false
		var allowed: Array = []
		for node: Dictionary in nodes.values():
			if int(node.get("episode",1)) == int(key) and node.get("alive",false): allowed.append(int(node.get("ending_id",node.get("result_id",0))))
		if not _valid_stats(data.extra_stats[key],allowed): return false
	if not data.get("activity",{}) is Dictionary: return false
	var activity_data: Dictionary = data.get("activity",{})
	if not activity_data.is_empty():
		if activity_data.get("id") != data.current_id or not activity_data.get("input") is String: return false
		for key: String in ["attempts","taps","remaining"]:
			var value: Variant = activity_data.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or value < 0: return false
		if activity_data.has("required_taps"):
			var required: Variant = activity_data.required_taps
			if not (required is int or required is float) or required != int(required) or required < 1: return false
		if activity_data.has("hit_windows"):
			if not activity_data.hit_windows is Array: return false
			var seen_windows: Array = []
			for window: Variant in activity_data.hit_windows:
				if not (window is int or window is float) or window != int(window) or window < 0 or window in seen_windows: return false
				seen_windows.append(window)
		if activity_data.has("last_target"):
			var last: Variant = activity_data.last_target
			if not (last is int or last is float) or last != int(last) or int(last) not in [0,1]: return false
		if activity_data.has("target_windows"):
			if not activity_data.target_windows is Array: return false
			for window: Variant in activity_data.target_windows:
				if not window is Dictionary or not window.get("rect") is Array or window.rect.size()!=4: return false
				for value: Variant in [window.get("start"),window.get("end"),window.rect[0],window.rect[1],window.rect[2],window.rect[3]]:
					if not (value is int or value is float) or not is_finite(float(value)): return false
				if window.end<=window.start or window.rect[2]<=0 or window.rect[3]<=0: return false
		for key: String in ["lock_frame","lock_fraction","feedback_remaining"]:
			if activity_data.has(key):
				var value: Variant = activity_data[key]
				if not (value is int or value is float) or not is_finite(float(value)) or value<0: return false
		if activity_data.has("lock_running") and not activity_data.lock_running is bool: return false
		if activity_data.has("status") and activity_data.status not in ["idle","error","accepted"]: return false
	var ch: Variant = data.get("channel")
	return (ch is float or ch is int) and ch == int(ch) and ch >= 0 and ch < TV_IMAGES.size()

func _valid_stats(stats: Variant, endings: Array) -> bool:
	if not stats is Dictionary or not stats.get("endings") is Array: return false
	for key: String in ["wins","losses"]:
		var counter: Variant = stats.get(key)
		if not (counter is int or counter is float) or counter < 0 or counter != int(counter): return false
	if stats.has("last_ending"):
		var last: Variant = stats.last_ending
		if not (last is int or last is float) or last != int(last) or (int(last) != -1 and int(last) not in endings): return false
	var seen: Array = []
	for ending: Variant in stats.endings:
		if not (ending is int or ending is float) or ending != int(ending) or int(ending) not in endings or int(ending) in seen: return false
		seen.append(int(ending))
	return true

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data

func _load_save() -> void:
	var data: Variant = _read(save_path)
	if not _valid(data):
		data = _read(backup_path)
		if not _valid(data):
			return
		recovery_message = LOC.text("@loc:ui.quest_state.1")
	current_id = data.current_id
	popup_origin = data.get("popup_origin","")
	flags = data.flags.duplicate(true)
	flags.Auto = int(flags.Auto)
	flags.BulletsNumber = int(flags.get("BulletsNumber",-1))
	flags.LinkedFr = flags.get("LinkedFr",false)
	activity = data.get("activity",{}).duplicate(true)
	extra_stats = data.get("extra_stats",{}).duplicate(true)
	for stats: Dictionary in extra_stats.values():
		stats.wins = int(stats.wins)
		stats.losses = int(stats.losses)
		if stats.has("last_ending"): stats.last_ending = int(stats.last_ending)
		for i: int in stats.endings.size(): stats.endings[i] = int(stats.endings[i])
	episode = int(data.get("episode",1))
	channel = int(data.channel)
	sound_enabled = data.sound_enabled
	has_progress = data.has_progress
	episode1_stats = {"wins":0,"losses":0,"endings":[]}
	episode2_stats = {"wins":0,"losses":0,"endings":[]}
	for number: int in [1,2]:
		var key := "episode%d_stats" % number
		if data.has(key):
			var stats: Dictionary = stats_for(number)
			stats.wins = int(data[key].wins)
			stats.losses = int(data[key].losses)
			if data[key].has("last_ending"): stats.last_ending = int(data[key].last_ending)
			stats.endings = data[key].endings.duplicate()
			for i: int in stats.endings.size(): stats.endings[i] = int(stats.endings[i])
	result_recorded = data.get("result_recorded",false)
	if has_progress: _record_result()

func save_game() -> bool:
	var serialized: String = JSON.stringify(_snapshot())
	var paths: String = save_path + "|" + tmp_path + "|" + backup_path
	if serialized == _last_saved_text and paths == _last_saved_paths and FileAccess.file_exists(save_path): return true
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		save_failed.emit(LOC.text("@loc:ui.quest_state.2"))
		return false
	file.store_string(serialized)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		save_failed.emit(LOC.text("@loc:ui.quest_state.3"))
		return false
	# Same temp/backup strategy as Hangman; never replace a good backup with corrupt data.
	if _valid(_read(save_path)):
		var backup_error := DirAccess.copy_absolute(save_path, backup_path)
		if backup_error != OK:
			save_failed.emit(LOC.text("@loc:ui.quest_state.4"))
			return false
	var error := DirAccess.rename_absolute(tmp_path, save_path)
	if error != OK:
		save_failed.emit(LOC.text("@loc:ui.quest_state.5"))
		return false
	_last_saved_text = serialized
	_last_saved_paths = paths
	save_writes += 1
	return true
