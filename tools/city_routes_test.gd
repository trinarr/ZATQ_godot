extends SceneTree
var quest: Node
var checks: int = 0
var failures: int = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func walk(start: String, choices: Array, target: String) -> void:
	quest._enter(start)
	for index: int in choices: quest.choose(index)
	check(quest.current_id == target, "%s -> %s" % [start,target])
func run() -> void:
	quest = root.get_node("Quest")
	quest.save_path = "user://city_routes_test.json"
	quest.tmp_path = "user://city_routes_test.tmp"
	quest.backup_path = "user://city_routes_test.bak"
	quest.sound_enabled = false
	var scene: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._start()
	quest.flags.Auto = 1
	walk("city_car",[0,0,0,0,0],"farm_boundary")
	walk("city_car",[0,0,0,0,1,0,0],"car_fatal")
	await create_timer(0.5).timeout
	check(quest.current_id == "death_3","car fatal transition completes")
	walk("city_car",[0,1,0,0,0,0,0,0,1,0,0],"car_battery_return")
	walk("car_battery_return",[0,1],"forest_boundary")
	walk("office_gate",[0,1],"car_battery_return")
	walk("office_enter",[0,0,0,0,0],"office_fatal")
	await create_timer(0.5).timeout
	check(quest.current_id == "death_11","office fatal transition completes")
	walk("office_enter",[0,0,0,2,0,0],"roof_explosion")
	check(not scene.cutscene.is_stopped(),"cinematic timer starts")
	scene._show_pause()
	check(scene.cutscene.is_stopped(),"pause stops cinematic timer")
	await create_timer(1.0).timeout
	check(quest.current_id == "roof_explosion","paused cinematic does not advance")
	check(scene.screen.modulate.a == 1.0,"pause remains visible")
	scene._resume()
	await create_timer(1.7).timeout
	check(quest.current_id == "death_2","explosion resumes to result")
	quest.flags.Auto = 0
	walk("office_exit",[0,0,0],"suburb_boundary")
	walk("city_foot",[0,0,1],"mainstreet_boundary")
	walk("city_foot",[0,0,2],"taxi_boundary")
	walk("city_foot",[0,0,0,0,0,0,0,0,0],"death_5")
	walk("city_foot",[0,0,0,0,0,1,0,0,2],"taxi_escape_boundary")
	walk("shop_window",[0,0,0],"bite_transition")
	await create_timer(2.8).timeout
	check(quest.current_id == "checkpoint","bite sequence transitions to checkpoint")
	quest.choose(0)
	quest.choose(0)
	check(quest.current_id == "death_10","checkpoint rejects bitten Jack")
	# Old city IDs now resume to real gameplay; no save-version migration needed.
	quest._enter("city_car")
	quest.flags.Auto=1
	check(quest.save_game(),"save extended route")
	quest.current_id="wake"
	quest._load_save()
	check(quest.current_id=="city_car" and quest.current().kind=="city_story","resume old city boundary ID")
	quest._enter("documents_decision")
	check(quest.save_game(),"save decision")
	quest.current_id="wake"
	quest._load_save()
	check(quest.current_id=="documents_decision" and quest.available_choices().size()==3,"resume exact three-way decision")
	# Draw every new node and validate native labels, artwork, and hotspots.
	var city: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/city_routes.json")).nodes
	for id: String in city:
		quest._enter(id)
		await process_frame
		check(scene.section=="story","draw %s" % id)
		for node: Node in scene.screen.get_children():
			if node is TextureRect: check(node.texture != null,"texture %s" % id)
			if node is Label:
				check(node.position.x+node.size.x<=1600.1 and node.position.y+node.size.y<=960.1,"label bounds %s" % id)
		if city[id].kind=="city_decision":
			var before: String = city[id].back
			scene.screen.get_node("Закрыть выбор").pressed.emit()
			check(quest.current_id==before,"cancel choice returns to narrative")
	# Result buttons perform a real restart and preserve menu continuation.
	quest._enter("death_3")
	scene.screen.get_node("В меню").pressed.emit()
	check(scene.section=="menu" and quest.current_id=="death_3","death -> menu preserves result")
	scene._resume()
	scene.screen.get_node("Начать заново").pressed.emit()
	check(quest.current_id=="wake" and not quest.flags.TakenKey and quest.flags.Auto==0,"death -> clean restart")
	scene.queue_free()
	await create_timer(0.25).timeout
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	if failures==0:print("PASS: %d city-route checks" % checks)
	quit(0 if failures==0 else 1)
