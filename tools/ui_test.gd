extends SceneTree
var failures: int = 0
var checks: int = 0
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var quest: Node = root.get_node("Quest")
	quest.save_path="user://ui_test.json"
	quest.tmp_path="user://ui_test.tmp"
	quest.backup_path="user://ui_test.bak"
	quest.sound_enabled=false
	var scene: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.screen.get_node("Тесты") is Button,"menu tests button")
	scene.screen.get_node("Тесты").pressed.emit()
	await process_frame
	check(scene.section == "selector" and scene.selector_kind == "tests","menu -> tests")
	for i in 5:
		check(scene.selector_index == i,"test index")
		for node in scene.screen.get_children():
			if node is TextureRect:
				check(node.texture != null and node.size == Vector2(1600,960),"original selector asset fits stage")
			if node is Label:
				check(node.position.x+node.size.x <= 1600,"text remains inside stage")
		scene.screen.get_node("Следующий").pressed.emit()
		await process_frame
	check(scene.selector_index == 0,"test carousel wraps")
	scene.screen.get_node("Начать").pressed.emit()
	check(is_instance_valid(scene.overlay),"unconverted test gives explicit status")
	scene._close_overlay()
	scene._show_selector("episodes")
	for i in 7:
		check(scene.selector_index == i,"episode index")
		scene._cycle_selector(1)
		await process_frame
	check(scene.selector_index == 0,"episode carousel wraps")
	quest.has_progress=false
	scene.screen.get_node("Начать").pressed.emit()
	check(scene.playing and quest.current_id=="wake","first episode starts")
	quest._enter("morning_choice")
	await process_frame
	scene.screen.find_child("Смотреть последние новости",true,false).pressed.emit()
	check(quest.current_id=="tv","original TV hotspot")
	scene.screen.get_node("Пауза").pressed.emit()
	check(scene.paused and scene.television.is_stopped(),"original pause control stops TV")
	scene.overlay.get_node("Продолжить").pressed.emit()
	check(not scene.paused and not scene.television.is_stopped(),"original wheel resumes")
	quest._enter("transport")
	scene.screen.find_child("Взять ключи",true,false).pressed.emit()
	check(quest.current_id=="keys","keys hotspot")
	scene.screen.get_node("Забрать ключи").pressed.emit()
	await process_frame
	check(not scene.screen.has_node("Взять ключи"),"keys pickup removed after collection")
	scene.screen.find_child("Выйти на улицу",true,false).pressed.emit()
	scene.screen.get_node("Поехать на машине").pressed.emit()
	check(quest.flags.Auto==1,"original decision button")
	quest._enter("mainstreet_boundary")
	scene._show_pause()
	scene.overlay.get_node("Выйти в меню").pressed.emit()
	check(scene.section=="menu","completed street route exits to menu")
	scene._show_help()
	check(scene.screen.get_node("Закрыть справку") is Button,"help closes")
	scene.screen.get_node("Закрыть справку").pressed.emit()
	check(scene.section=="menu","help -> menu")
	scene.queue_free()
	await create_timer(0.25).timeout
	for path in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	if failures==0:print("PASS: %d Flash UI checks" % checks)
	quit(0 if failures==0 else 1)
