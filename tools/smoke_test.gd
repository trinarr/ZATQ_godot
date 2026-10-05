extends SceneTree
var quest: Node
var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
	checks += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	quest = root.get_node("Quest")
	quest.save_path = "user://zombie_quest_smoke.json"
	quest.tmp_path = "user://zombie_quest_smoke.tmp"
	quest.backup_path = "user://zombie_quest_smoke.bak"
	var scene: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	# Barefoot path: no key and no car choice.
	scene._start()
	check(quest.current_id == "wake", "start")
	quest.choose(0)
	quest.choose(0)
	check(quest.current_id == "morning_choice", "intro text chain")
	quest.choose(0)
	check(quest.available_choices().size() == 2, "keys offered")
	quest.choose(0)
	check(quest.current_id == "lift", "no keys skips transport popup")
	quest.choose(0)
	quest.choose(0)
	check(quest.current_id == "city_foot", "walking boundary")
	# All 7 channels and auto return, pause must stop timer.
	scene._start()
	quest._enter("morning_choice")
	quest.choose(1)
	check(quest.current_id == "tv" and quest.channel == 0, "tv entry")
	check(not scene.television.is_stopped(), "tv timer starts")
	scene._show_menu()
	check(scene.television.is_stopped(), "tv timer pauses in menu")
	scene._resume()
	for i in 6: quest.next_channel()
	check(quest.channel == 6 and quest.current_id == "tv", "seven channels")
	quest.next_channel()
	check(quest.current_id == "morning_choice", "return after last channel")
	# Take keys -> return, no duplicate item button -> choose car.
	quest.choose(0)
	quest.choose(1)
	check(quest.flags.TakenKey, "keys recorded")
	quest.choose(0)
	check(quest.available_choices().size() == 1, "no duplicate keys")
	quest.choose(0)
	check(quest.current_id == "transport_choice", "transport popup with keys")
	quest.choose(0)
	check(quest.flags.Auto == 1, "car flag")
	quest.choose(0)
	quest.choose(0)
	check(quest.current_id == "city_car", "car boundary")
	# Exact resume and recovery when primary JSON is corrupt.
	check(quest.save_game(), "save writes")
	quest.current_id = "wake"
	quest._load_save()
	check(quest.current_id == "city_car" and quest.flags.TakenKey, "restore state")
	var bad := FileAccess.open(quest.save_path, FileAccess.WRITE)
	bad.store_string("{broken")
	bad.close()
	quest.current_id = "wake"
	quest._load_save()
	check(quest.current_id == "city_car", "backup recovery")
	check(not quest.recovery_message.is_empty(), "recovery notice")
	check(quest.save_game(), "replace corrupt primary without destroying backup")
	# Walking even with keys, restart clears inventory.
	scene._start()
	quest._enter("keys")
	quest.choose(0)
	quest.choose(0)
	quest.choose(1)
	check(quest.flags.Auto == 0, "explicit walking flag")
	quest.choose(0)
	quest.choose(0)
	check(quest.current_id == "city_foot", "walking with keys")
	scene._start()
	check(not quest.flags.TakenKey and quest.flags.Auto == 0, "restart clears flags")
	scene._show_menu()
	scene._request_new()
	scene._toggle_sound()
	check(not quest.sound_enabled, "sound off persisted")
	scene._toggle_sound()
	check(quest.sound_enabled, "sound on")
	scene.queue_free()
	await create_timer(0.25).timeout
	if failures == 0:
		print("PASS: %d runtime checks; opening routes, UI, timer, sound, save recovery" % checks)
	for path in [quest.save_path, quest.tmp_path, quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	# Let the debug log bridge drain its final message before shutting down.
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
