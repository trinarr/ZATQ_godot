extends SceneTree
const PAUSE := preload("res://scenes/shared/PauseMenu.tscn")
const ITEM := preload("res://scenes/shared/ItemPopup.tscn")
const DIALOG := preload("res://scenes/shared/PlayerDialog.tscn")
var failures := 0
var checks := 0
var selected := -1
var accepted := false
var requested := ""
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	# Instantiate without Main; views must not mutate Quest or own routing.
	var quest: Node = root.get_node("Quest")
	quest.save_path="user://shared_menus_test.json"
	quest.tmp_path="user://shared_menus_test.tmp"
	quest.backup_path="user://shared_menus_test.bak"
	quest.sound_enabled=false
	var initial_id: String = quest.current_id
	var textures: Dictionary = {}
	for artwork: String in ["item_keys","ep2_item_glock","ep2_item_mark23","e3_item_knife","e3_item_glock16","e3_item_glock7"]:
		var panel: Control = ITEM.instantiate()
		root.add_child(panel)
		panel.accepted.connect(func(): accepted=true)
		panel.configure(artwork,"Предмет / Item")
		await process_frame
		var count := 0
		for child: Node in panel.get_children():
			if child is TextureRect:
				count += 1
				check(child.texture!=null,"item texture: "+artwork)
				if count in [1,2,4]:
					if textures.has(count):check(textures[count]==child.texture,"shared item chrome")
					textures[count]=child.texture
		check(count==4,"frame, header, item and arrow: "+artwork)
		accepted=false
		for child: Node in panel.get_children():
			if child is Button:child.pressed.emit()
		check(accepted,"item emits acceptance")
		check(quest.current_id==initial_id,"item does not route")
		panel.free()
	var pause: Control = PAUSE.instantiate()
	root.add_child(pause)
	pause.configure(false)
	pause.resume_requested.connect(func(): requested="resume")
	pause.restart_requested.connect(func(): requested="restart")
	pause.sound_requested.connect(func(): requested="sound")
	pause.menu_requested.connect(func(): requested="menu")
	pause.quit_requested.connect(func(): requested="quit")
	pause.set_cover_rect(Rect2(-300,-40,2200,1040))
	check(pause.dimmer.position==Vector2(-300,-40) and pause.dimmer.size==Vector2(2200,1040),"pause covers visible safe area")
	check(pause.resume_art.position.x==-300,"pause resume tab stays at safe edge")
	var actions: Array[String] = []
	for child: Node in pause.get_children():
		if child is Button:
			child.pressed.emit()
			actions.append(requested)
	check(actions==["restart","sound","menu","quit","resume"],"all pause actions emit signals")
	check(quest.current_id==initial_id,"pause does not route")
	pause.free()
	for data: Dictionary in [{"text":"Выбор","art":"decision"},{"style":"confirmation","text":"Подтвердить?"},{"style":"speaker","text":"Реплика","speaker":"Дэвид","art":"result_background"},{"style":"speaker","original_ui":true,"text":"Реплика","speaker":"Джон","art":"e3_dialogue_john","shade":false}]:
		var dialog: Control = DIALOG.instantiate()
		root.add_child(dialog)
		dialog.choice_selected.connect(func(index: int): selected=index)
		dialog.configure(data,[{"text":"Да"},{"text":"Нет"},{"text":"Позже"}])
		check(dialog.choice_buttons.size()==3,"dialogue supports variable choices")
		for i: int in dialog.choice_buttons.size():
			dialog.choice_buttons[i].pressed.emit()
			check(selected==i,"dialogue preserves choice index")
		if data.get("style","")=="speaker":
			check(dialog.backdrop!=null,"dialogue owns its art and portrait")
		check(quest.current_id==initial_id,"dialogue does not route")
		dialog.free()
	var ui: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	for episode: int in [1,2,3]:
		ui.playing=true
		quest.new_game(episode)
		await process_frame
		ui._show_pause()
		check(ui.overlay.get_script()==load("res://scripts/ui/shared/pause_menu.gd"),"episode uses shared pause")
		ui.overlay.restart_requested.emit()
		check(ui.overlay.get_script()==load("res://scripts/ui/shared/player_dialog.gd"),"restart uses shared confirmation")
		ui.overlay.choice_buttons[1].pressed.emit()
		check(ui.paused and ui.overlay.get_script()==load("res://scripts/ui/shared/pause_menu.gd"),"cancel restores pause")
		ui.overlay.resume_requested.emit()
		check(not ui.paused and ui.overlay==null,"resume clears pause")
	# Cover every authored pickup and player dialogue through the real dispatcher.
	for id: String in quest.nodes:
		var node: Dictionary = quest.nodes[id]
		if node.get("kind","") not in ["item","city_pickup","city_decision","activity_dialogue"] and id!="transport_choice":continue
		quest.flags={"TakenKey":true,"Auto":0,"BulletsNumber":12,"LinkedFr":true,"TakenKnife":true,"JohnVariant":1,"code":"1234"}
		quest.current_id=id
		quest.episode=int(node.get("episode",1))
		quest.activity={}
		ui.playing=true
		ui.paused=false
		ui._show_story()
		var found := false
		for child: Node in ui.screen.get_children():
			if child.get_script()==load("res://scripts/ui/shared/item_popup.gd") or child.get_script()==load("res://scripts/ui/shared/player_dialog.gd"):found=true
		check(found,"authored screen uses shared component: "+id)
	ui.queue_free()
	await process_frame
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	print("PASS: %d shared menu checks; failures %d" % [checks,failures])
	quit(1 if failures else 0)
