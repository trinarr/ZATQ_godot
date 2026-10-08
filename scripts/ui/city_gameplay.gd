extends RefCounted
const LOC := preload("res://scripts/core/localization.gd")
const RESULT := preload("res://scripts/ui/result_screen.gd")
# Coordinates use the original Flash frame; Main applies the uniform 2x scale.
static func draw(ui: Control, node: Dictionary) -> void:
	var artwork: String = node.get("art", "")
	var story_text: String = node.get("text", "")
	var choices: Array = Quest.available_choices()
	if Quest.flags.Auto == 0: artwork = node.get("art_on_foot", artwork)
	if Quest.flags.Auto == 0: story_text = node.get("text_on_foot", story_text)
	if node.kind in ["city_death", "city_ending"]:
		RESULT.draw(ui,node)
		return
	if node.kind == "city_pickup":
		if not str(node.get("background_art","")).is_empty(): ui._pickup_backdrop(node.background_art)
		ui._show_item_popup(artwork,node.text)
		return
	if node.kind == "city_decision":
		if ui.decision_scene_origin.is_empty():
			if not ui._component_backdrop(artwork):
				ui._set_backdrop(load("res://assets/flash_ui/" + artwork + "."+node.get("art_extension","png")), not node.get("clean_background",false))
			var timeline: Node2D = ui.viewport_canvas.episode_timeline
			if is_instance_valid(timeline):
				timeline.playing = false
				timeline.seek_frame(timeline.frames.size()-1)
		ui._show_player_dialog({"text":node.text,"art":node.get("decision_art","city_decision_3" if choices.size()==3 else "decision"),"fit_body":true,"dismissable":true},choices,Callable(),func(): ui._dismiss_story_decision(node.back))
		if not is_instance_valid(ui.edge_hit): ui._edge_tab(LOC.text("@loc:ui.city_gameplay.3"),ui._show_pause)
		return
	if not ui._component_backdrop(artwork):
		ui._set_backdrop(load("res://assets/flash_ui/" + artwork + "."+node.get("art_extension","png")), not node.get("clean_background",false))
	if Quest.current_id == "metro_junction":
		ui._component_backdrop("adaptive_metro_background")
		ui._world_art("adaptive_metro_controls")
	if node.get("input_after_intro",false) and is_instance_valid(ui.viewport_canvas.episode_timeline) and ui.viewport_canvas.episode_timeline.playing:
		var origin: String = Quest.current_id
		ui.world_layer.set_meta("episode_animation_block",true)
		var ready_signal: Signal = ui.viewport_canvas.episode_timeline.input_ready if ui.viewport_canvas.episode_timeline.spec.has("input_ready_frame") else ui.viewport_canvas.episode_timeline.finished
		ready_signal.connect(func():
			if Quest.current_id==origin and is_instance_valid(ui.world_layer):ui.world_layer.remove_meta("episode_animation_block"),CONNECT_ONE_SHOT)
	var controls: Control
	if node.has("controls_art"):
		controls = ui._world_art(node.controls_art)
	var kind: String = node.kind
	if kind == "city_cutscene":
		var timeline: Node2D = ui.viewport_canvas.episode_timeline
		if is_instance_valid(timeline):
			# A Flash End/Next event is emitted at the last authored frame.
			var origin: String = Quest.current_id
			var automatic := func():
				if Quest.current_id == origin and not ui.paused:
					ui._commit_choice(0)
			if timeline.has_outro():
				timeline.finished.connect(automatic,CONNECT_ONE_SHOT)
				timeline.play("outro")
			elif timeline.playing:
				timeline.finished.connect(automatic,CONNECT_ONE_SHOT)
			else: ui.cutscene.start(node.auto_seconds)
		else:
			var duration: float = node.auto_seconds
			ui.cutscene.start(duration)
			ui.cutscene_tween = ui.create_tween().bind_node(ui.screen)
			ui.cutscene_tween.tween_property(ui.screen,"modulate:a",0.0,duration)
			ui.cutscene_tween.parallel().tween_property(ui.viewport_canvas.background,"modulate:a",0.0,duration)

	else:
		for block: Dictionary in node.get("blocks",[]):
			var b: Array = block.rect.duplicate()
			var options: Dictionary = {"fit":"multiline","minimum":14,"padding":4,"host":ui._world_host() if block.get("world",false) else ui.screen}
			if "Hist" in block.get("path", ""):
				options.band_host = ui.screen
				options.band_rect = Rect2(-ui.screen.position.x/ui.screen.scale.x,maxf(0,b[1]-6)*2,ui.viewport_canvas.safe_layer.size.x/ui.screen.scale.x,(b[3]+12)*2)
			var block_font: Font = ui.BODY_FONT
			if block.font in ["SegoeScript", "Segoe Script"]:
				block_font = load("res://fonts/flash/font_2508.ttf")
			elif block.font == "B52 Regular":
				block_font = load("res://fonts/flash/font_2511.ttf")
			if block.has("font_file"):
				block_font = load(block.font_file)
			for key: String in ["minimum","padding","line_spacing","wrap","band_alpha"]:
				if block.has(key): options[key] = block[key]
			options.font = block_font
			var label: Label = ui._narrative_text(block.text,Rect2(b[0],b[1],b[2],b[3]),int(block.size),options)
			ui._bind_episode_caption(label,ui.narrative_layer.band_for(label) if Quest.episode>1 else null)
		if node.has("text_rect"):
			var panel: Array = node.panel_rect
			if Quest.flags.Auto == 0: panel = node.get("panel_rect_on_foot",panel)
			var rect: Rect2 = ui.LAYOUT.scaled_rect(Rect2(panel[0],panel[1],panel[2],panel[3]))
			var band_rect := Rect2(-ui.screen.position.x/ui.screen.scale.x,rect.position.y,ui.viewport_canvas.safe_layer.size.x/ui.screen.scale.x,rect.size.y)
			var box: Array = node.text_rect.duplicate()
			if Quest.flags.Auto == 0: box = node.get("text_rect_on_foot",box).duplicate()
			var description: Label = ui._narrative_text(story_text,Rect2(box[0],box[1],box[2],box[3]),24,{"fit":"multiline","minimum":15,"band_rect":band_rect})
			ui._bind_episode_caption(description,ui.narrative_layer.band_for(description) if Quest.episode>1 else null)
		var choice_buttons: Array[Control] = []
		for i in choices.size():
			var index: int = i
			var r: Array = choices[i].get("rect",[70,0,730,480])
			var button: Button = ui._world_hit(choices[i].text,Rect2(r[0],r[1],r[2],r[3]),func(): ui._choose(index),choices[i].get("mask",""))
			choice_buttons.append(button)
			if node.get("choice_captions",false):
				ui._button_text(choices[i].text,Rect2(10,4,r[2]-20,r[3]-8),24,button,ui.BODY_FONT)
		if artwork == "ep1_mainstreet_choice" and is_instance_valid(ui.viewport_canvas.episode_timeline) and ui.viewport_canvas.episode_timeline.playing:
			var arriving: Array[Control] = choice_buttons.duplicate()
			if is_instance_valid(controls): arriving.append(controls)
			for child: Control in arriving: child.hide()
			ui.viewport_canvas.episode_timeline.finished.connect(func():
				for child: Control in arriving:
					if is_instance_valid(child): child.show(),CONNECT_ONE_SHOT)
	if kind not in ["city_decision", "city_death", "city_ending"]:
		ui._edge_tab(LOC.text("@loc:ui.city_gameplay.3"),ui._show_pause)
