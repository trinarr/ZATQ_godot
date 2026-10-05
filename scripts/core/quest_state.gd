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
	_load_save()

func current() -> Dictionary:
	return nodes.get(current_id, {})

func available_choices() -> Array:
	var result: Array = []
	for choice in current().get("choices", []):
		if choice.get("unless_keys", false) and flags.TakenKey:
			continue
		result.append(choice)
	return result

func new_game() -> void:
	result_recorded = false
	flags = {"TakenKey": false, "Auto": 0}
	channel = 0
	has_progress = true
	_enter("wake")

func _enter(id: String) -> void:
	if not nodes.has(id):
		return
	current_id = id
	channel = 0
	for key in current().get("set", {}):
		flags[key] = current().set[key]
	_record_result()
	save_game()
	changed.emit()

func _record_result() -> void:
	if result_recorded or not current().has("result_id"): return
	result_recorded = true
	var node: Dictionary = current()
	if node.get("alive",false):
		episode1_stats.wins += 1
		var result_id: int = int(node.result_id)
		if result_id not in episode1_stats.endings:
			episode1_stats.endings.append(result_id)
	else:
		episode1_stats.losses += 1

func choose(index: int) -> void:
	var choices: Array = available_choices()
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	if choice.get("action", "") == "channel":
		next_channel()
		return
	for key in choice.get("set", {}):
		flags[key] = choice.set[key]
	var target: String = choice.get("next", "")
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
	return {"version":VERSION,"current_id":current_id,"flags":flags,"channel":channel,"sound_enabled":sound_enabled,"has_progress":has_progress,"episode1_stats":episode1_stats,"result_recorded":result_recorded}

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
	if data.has("episode1_stats"):
		var stats: Variant = data.episode1_stats
		if not stats is Dictionary or not stats.get("endings") is Array: return false
		for key: String in ["wins","losses"]:
			var counter: Variant = stats.get(key)
			if not (counter is int or counter is float) or counter < 0 or counter != int(counter): return false
		var seen: Array = []
		for ending: Variant in stats.endings:
			if not (ending is int or ending is float) or ending != int(ending): return false
			var result_id: int = int(ending)
			if result_id not in [6,77,78] or result_id in seen: return false
			seen.append(result_id)
	var ch: Variant = data.get("channel")
	return (ch is float or ch is int) and ch == int(ch) and ch >= 0 and ch < TV_IMAGES.size()

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
	flags = {"TakenKey": data.flags.TakenKey, "Auto": int(data.flags.Auto)}
	channel = int(data.channel)
	sound_enabled = data.sound_enabled
	has_progress = data.has_progress
	episode1_stats = {"wins":0,"losses":0,"endings":[]}
	if data.has("episode1_stats"):
		episode1_stats = {"wins":int(data.episode1_stats.wins),"losses":int(data.episode1_stats.losses),"endings":data.episode1_stats.endings.duplicate()}
		for i: int in episode1_stats.endings.size():
			episode1_stats.endings[i] = int(episode1_stats.endings[i])
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
