extends SceneTree
const ICON_VIEW := preload("res://scripts/ui/statistic_icon.gd")
const TICK: Texture2D = preload("res://assets/flash_ui/components/stat_tick.png")
const SKULL: Texture2D = preload("res://assets/flash_ui/components/stat_skull.png")
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)
func _initialize() -> void:call_deferred("run")
func inspect_icon(icon: TextureRect) -> void:
	check(icon.shadow_layers.size()==2,"two compact extrusion layers")
	for i: int in icon.shadow_layers.size():
		var layer: TextureRect=icon.shadow_layers[i]
		check(layer.texture==icon.texture,"shadow reuses foreground texture")
		check(layer.material==ICON_VIEW.shared_shadow,"shared immutable shadow material")
		check(layer.material.shader==ICON_VIEW.SHADOW_SHADER,"adapted Hangman shader")
		check(layer.show_behind_parent,"shadow stays behind foreground")
		check(layer.position==Vector2(1,2)*float(i+1)/2.0,"compact ZATQ shadow offset")
		check(layer.size==icon.size,"shadow follows icon dimensions")
		check(layer.mouse_filter==Control.MOUSE_FILTER_IGNORE,"shadow does not intercept input")
	check(icon.material==null,"foreground keeps original grayscale and tint")
func run() -> void:
	var quest: Node=root.get_node("Quest")
	quest.sound_enabled=false
	var ui: Control=load("res://scenes/Main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui._show_selector("episodes")
	for index: int in ui._selector_items().size():
		ui.selector_index=index
		ui._draw_selector()
		await process_frame
		var count:=0
		for child: Node in ui.screen.get_children():
			if child.get_script()==ui.ENDING_CHECKS:continue
			for component: Node in child.get_children():
				if component.get_script()==ICON_VIEW:
					count+=1
					check(component.texture==TICK or component.texture==SKULL,"statistics uses standalone icon sprites")
					inspect_icon(component)
		var frame: int=int(ui._selector_items()[index].frame)
		check(count==(2 if frame in [0,2,4,5,7,9,11] else 0),"statistics strip split into two controls")
		for child: Node in ui.screen.get_children():
			if child.get_script()==ui.ENDING_CHECKS:
				for tick: TextureRect in child.get_children():
					check(tick.texture==TICK,"ending and statistics share the same tick")
					inspect_icon(tick)
	# Brown is a foreground modulation of the same texture, not another raster.
	var icon: TextureRect=ICON_VIEW.new()
	icon.texture=TICK
	icon.size=Vector2(28,34)
	icon.modulate=Color("803c3c")
	root.add_child(icon)
	await process_frame
	inspect_icon(icon)
	icon.size=Vector2(56,68)
	await process_frame
	inspect_icon(icon)
	check(icon.texture==TICK and icon.modulate==Color("803c3c"),"resizing preserves shared texture and brown tint")
	icon.queue_free()
	ui.queue_free()
	await process_frame
	print("PASS: %d split icon/shader checks; failures %d" % [checks,failures])
	quit(1 if failures else 0)
