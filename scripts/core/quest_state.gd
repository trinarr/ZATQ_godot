extends Node

signal changed
signal save_failed(message: String)

const CONTENT_PATH := "res://data/opening.json"
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
var flags: Dictionary = {"TakenKey": false, "Auto": 0}
var episode: int = 1
var episode2_stats: Dictionary = {"wins":0,"losses":0,"endings":[]}
var channel: int = 0
var sound_enabled: bool = true
var has_progress: bool = false
var recovery_message: String = ""
var episode1_stats: Dictionary = {"wins":0,"losses":0,"endings":[]}
var result_recorded: bool = false

func _ready() -> void:
	var content: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTENT_PATH))
	if content is Dictionary and content.get("nodes") is Dictionary:
		nodes = content.nodes
	var city_content: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/city_routes.json"))
	if city_content is Dictionary and city_content.get("nodes") is Dictionary:
		nodes.merge(city_content.nodes, true)
	var episode_content: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/episode1_routes.json"))
	if episode_content is Dictionary and episode_content.get("nodes") is Dictionary:
		nodes.merge(episode_content.nodes, true)
	var second_content: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/episode2_routes.json"))
	if second_content is Dictionary and second_content.get("nodes") is Dictionary:
		nodes.merge(second_content.nodes, true)
	_load_save()

func current() -> Dictionary:
	var node: Dictionary = nodes.get(current_id, {})
	if not node.has("variants"): return node
	var resolved: Dictionary = node.duplicate(true)
	for variant: Dictionary in node.variants:
		if matches(variant.when):
			for key: String in variant:
				if key != "when": resolved[key] = variant[key]
	return resolved

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
	return episode2_stats if number == 2 else episode1_stats

func available_choices() -> Array:
	var result: Array = []
	for choice in current().get("choices", []):
		if choice.get("unless_keys", false) and flags.TakenKey:
			continue
		if not matches(choice.get("requires",{})): continue
		result.append(choice)
	return result

func new_game(number: int = 1) -> void:
	if number not in [1,2]: return
	episode = number
	result_recorded = false
	flags = {"TakenKey": false, "Auto": 0, "BulletsNumber": -1, "LinkedFr": false}
	channel = 0
	has_progress = true
	_enter("e2_hospital_1" if episode == 2 else "wake")

func _enter(id: String) -> void:
	if not nodes.has(id):
		return
	current_id = id
	episode = 2 if id.begins_with("e2_") else 1
	channel = 0
	var pickup: Dictionary = current().get("pickup_if",{})
	if not pickup.is_empty() and matches(pickup.when):
		_enter(pickup.next)
		return
	for key in current().get("set", {}):
		flags[key] = current().set[key]
	_record_result()
	save_game()
	changed.emit()

func _record_result() -> void:
	if result_recorded or not current().has("result_id"): return
	result_recorded = true
	var node: Dictionary = current()
	var stats: Dictionary = stats_for(episode)
	if node.get("alive",false):
		stats.wins += 1
		var result_id: int = int(node.result_id)
		if result_id not in stats.endings:
			stats.endings.append(result_id)
	else:
		stats.losses += 1

func choose(index: int) -> void:
	var choices: Array = available_choices()
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
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
	return {"version":VERSION,"current_id":current_id,"flags":flags,"channel":channel,"sound_enabled":sound_enabled,"has_progress":has_progress,"episode":episode,"episode1_stats":episode1_stats,"episode2_stats":episode2_stats,"result_recorded":result_recorded}

func _valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != VERSION:
		return false
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
	if not (saved_episode is int or saved_episode is float) or saved_episode != int(saved_episode) or int(saved_episode) not in [1,2]: return false
	var bullets: Variant = data.flags.get("BulletsNumber",-1)
	if not (bullets is int or bullets is float) or bullets != int(bullets) or bullets < -1 or bullets > 12: return false
	if not data.flags.get("LinkedFr",false) is bool: return false
	if data.has_progress and (2 if data.current_id.begins_with("e2_") else 1) != int(saved_episode): return false
	for number: int in [1,2]:
		var stats_key := "episode%d_stats" % number
		if data.has(stats_key) and not _valid_stats(data[stats_key],[6,77,78] if number==1 else [38,43,47]): return false
	var ch: Variant = data.get("channel")
	return (ch is float or ch is int) and ch == int(ch) and ch >= 0 and ch < TV_IMAGES.size()

func _valid_stats(stats: Variant, endings: Array) -> bool:
	if not stats is Dictionary or not stats.get("endings") is Array: return false
	for key: String in ["wins","losses"]:
		var counter: Variant = stats.get(key)
		if not (counter is int or counter is float) or counter < 0 or counter != int(counter): return false
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
		recovery_message = "Сохранение восстановлено из резервной копии."
	current_id = data.current_id
	flags = {"TakenKey": data.flags.TakenKey, "Auto": int(data.flags.Auto), "BulletsNumber": int(data.flags.get("BulletsNumber",-1)), "LinkedFr": data.flags.get("LinkedFr",false)}
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
			stats.endings = data[key].endings.duplicate()
			for i: int in stats.endings.size(): stats.endings[i] = int(stats.endings[i])
	result_recorded = data.get("result_recorded",false)
	if has_progress: _record_result()

func save_game() -> bool:
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		save_failed.emit("Не удалось записать сохранение.")
		return false
	file.store_string(JSON.stringify(_snapshot()))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		save_failed.emit("Ошибка записи сохранения.")
		return false
	# Same temp/backup strategy as Hangman; never replace a good backup with corrupt data.
	if _valid(_read(save_path)):
		var backup_error := DirAccess.copy_absolute(save_path, backup_path)
		if backup_error != OK:
			save_failed.emit("Не удалось создать резервную копию.")
			return false
	var error := DirAccess.rename_absolute(tmp_path, save_path)
	if error != OK:
		save_failed.emit("Не удалось обновить сохранение.")
		return false
	return true
