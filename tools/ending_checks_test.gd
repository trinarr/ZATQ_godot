extends SceneTree
const CHECKS := preload("res://scripts/ui/ending_checks.gd")
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:call_deferred("run")
func indicators(ui: Control) -> Control:
	for child: Node in ui.screen.get_children():
		if child.get_script()==CHECKS:return child
	return null
func run() -> void:
	var quest: Node = root.get_node("Quest")
	quest.save_path="user://ending_checks_test.json"
	quest.tmp_path="user://ending_checks_test.tmp"
	quest.backup_path="user://ending_checks_test.bak"
	quest.sound_enabled=false
	var ui: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui._show_selector("episodes")
	for episode: int in [1,2,3]:
		var slots: Array = CHECKS.ORIGINAL_SLOTS[episode]
		for mask: int in range(8):
			var unlocked: Array = []
			for i: int in 3:
				if mask & (1<<i):unlocked.append(slots[i])
			quest.stats_for(episode).endings=unlocked
			for i: int in ui._selector_items().size():
				if int(ui._selector_items()[i].get("episode",0))==episode:ui.selector_index=i
			ui._draw_selector()
			var view := indicators(ui)
			check(view!=null and view.get_child_count()==3,"three Flash ending slots")
			if view==null:continue
			for i: int in 3:
				var tick: TextureRect = view.get_child(i)
				check(tick.texture==CHECKS.ICON and tick.get_script()==CHECKS.ICON_VIEW,"same statistics icon resource")
				check(tick.modulate==(Color.WHITE if slots[i] in unlocked else CHECKS.UNSEEN_COLOR),"ending-specific state, not completed count")
				check(tick.position==Vector2(284+i*15,284)*2 and tick.size==Vector2(28,34),"original geometry")
				check(tick.mouse_filter==Control.MOUSE_FILTER_IGNORE,"indicator does not intercept input")
				check(tick.get_meta("ending_id")==slots[i],"original ending order")
			for label: Node in ui.screen.get_children():
				if label is Label:check(not label.text.begins_with("Финалы:"),"numeric ending label removed")
	# Episode III result 73 belongs to ending 67, the third slot.
	quest.stats_for(3).endings=[]
	ui.playing=true
	quest.new_game(3)
	quest._enter("e3_result_73")
	check(quest.stats_for(3).endings==[67],"alternate result shares one ending")
	quest.save_game()
	quest.stats_for(3).endings=[]
	quest._load_save()
	check(quest.stats_for(3).endings==[67],"saved discoveries restored")
	ui._show_selector("episodes")
	for i: int in ui._selector_items().size():
		if int(ui._selector_items()[i].get("episode",0))==3:ui.selector_index=i
	ui._draw_selector()
	var view := indicators(ui)
	check(view.get_child(0).modulate==CHECKS.UNSEEN_COLOR and view.get_child(1).modulate==CHECKS.UNSEEN_COLOR and view.get_child(2).modulate==Color.WHITE,"67/73 marks only third slot after load")
	ui._show_selector("tests")
	check(indicators(ui)==null,"quiz selector has no ending checks")
	ui._show_selector("episodes")
	for i: int in ui._selector_items().size():
		if not ui._selector_items()[i].available:
			ui.selector_index=i
			ui._draw_selector()
			check(indicators(ui)==null,"unavailable episode has no discovered endings")
	ui.queue_free()
	await process_frame
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	print("PASS: %d ending indicator checks; failures %d" % [checks,failures])
	quit(1 if failures else 0)
