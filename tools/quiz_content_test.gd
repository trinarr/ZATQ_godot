extends SceneTree
const QUIZ = preload("res://scripts/core/quiz_state.gd")
const VIEW = preload("res://scripts/ui/shared/quiz_view.gd")
const RESULT = preload("res://scripts/ui/shared/quiz_result.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1;push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var quiz := QUIZ.new()
	_test_second_test_scoring()
	check(quiz.catalog.tests.size()==5,"all five original tests")
	check(preload("res://scripts/core/localization.gd").imported_table("res://locales/tests.csv").rows.size()==409,"all imported test translations resolve")
	var expected := [16,10,15,9,14]
	for id: int in range(1,6):
		quiz.start(id)
		check(quiz.spec().questions.size()==expected[id-1],"complete questions for test "+str(id))
		check(not quiz.confirm(),"cannot confirm without selection")
		for key: String in quiz.spec().questions:
			quiz.question_id = int(key)
			var view := VIEW.new();root.add_child(view);view.configure(quiz)
			await process_frame;await process_frame
			check(view.answers.size()==quiz.question().options.size(),"all answer choices visible")
			for button: Button in view.answers:
				check(not button.caption.text.begins_with("@loc:"),"answer localization")
				check(button.caption.get_minimum_size().y <= button.caption.size.y+0.1,"answer fits without cropping")
				fits(button.caption)
				check(button.get_rect().end.x<=1560 and button.get_rect().end.y<=880,"answer inside authored frame")
			var question: Label = view.find_child("TestQuestion",true,false)
			check(question.get_minimum_size().y<=question.size.y+0.1,"question fits")
			fits(question)
			view.free()
	# Walk every branch of the first test, including all seventeen endings.
	var seen: Dictionary = {}
	_walk(1,[],seen)
	check(seen.size()==17,"every personality-test outcome reachable")
	# Extreme answer paths, percentage formulas and bounded survival duration.
	for id: int in range(2,6):
		for highest: bool in [false,true]:
			quiz.start(id)
			while quiz.result.is_empty():
				var best := 0
				for i: int in quiz.question().options.size():
					var points := int(quiz.question().options[i].points) if quiz.question().options[i].points!=null else 0
					var old := int(quiz.question().options[best].points) if quiz.question().options[best].points!=null else 0
					if (highest and points>old) or (not highest and points<old):best=i
				quiz.select(best);check(quiz.confirm(),"confirm accepted")
			check(quiz.answered==expected[id-1],"all linear questions answered")
			check(quiz.result.result_id==[29,50,100,150][id-2] or id==2,"original result mode")
			if id==3:check(quiz.result.label=="100%" if highest else quiz.result.label=="6%","survival percent denominator 88")
			if id==4:check(quiz.score>=0 and quiz.score<=100,"survival score clamp")
			if id==5:check(quiz.result.label=="100%" if highest else quiz.result.label=="12%","weapon percent denominator 41")
			var result := RESULT.new();root.add_child(result);result.configure(quiz.result)
			await process_frame;await process_frame
			for name: String in ["TestResultStory","TestAdvice"]:
				var label: Label=result.find_child(name,true,false)
				check(label.get_theme_font("font")==result.NARRATIVE_FONT,"Regular 400 result font")
				check(label.get_minimum_size().y<=label.size.y+0.1,"result text fits")
				fits(label)
			result.free()
	# Render every verdict and every recommendation, including the longest.
	var presentations: Array[Dictionary] = []
	for key: String in quiz.catalog.outcomes:
		var outcome: Variant=quiz.catalog.outcomes[key]
		if outcome is Dictionary:
			presentations.append({"result_id":int(key),"label":outcome.label,"text":outcome.text,"advice":"@loc:tests.ui.no_advice"})
		elif key=="100":
			for entry: Dictionary in outcome:presentations.append({"result_id":100,"label":entry.duration,"text":entry.text,"advice":entry.analog,"analog":true})
		else:
			for text: String in outcome:presentations.append({"result_id":int(key),"label":"100%","text":text,"advice":"@loc:tests.ui.no_advice"})
	for spec: Dictionary in quiz.catalog.tests:
		for question: Dictionary in spec.questions.values():
			if question.has("hint"):presentations.append({"result_id":50,"label":"50%","text":quiz.catalog.outcomes["50"][4],"advice":question.hint})
	for data: Dictionary in presentations:
		var panel:=RESULT.new();root.add_child(panel);panel.configure(data)
		await process_frame;await process_frame
		fits(panel.find_child("TestResultStory",true,false));fits(panel.find_child("TestAdvice",true,false))
		check(panel.find_child("TestResultOutcome",true,false).get_line_count()==1,"result subtitle stays on one line")
		panel.free()
	# Real menu dispatch, saved last result, replay and preservation of story.
	var quest=root.get_node("Quest")
	quest.save_path="user://quiz_test.json";quest.tmp_path="user://quiz_test.tmp";quest.backup_path="user://quiz_test.bak"
	quest.sound_enabled=false
	var before=quest._snapshot()
	var main=load("res://scenes/Main.tscn").instantiate();root.add_child(main)
	await process_frame
	main._show_selector("tests");main._selector_start()
	check(main.section=="test" and main.quiz.test_id==1,"selector launches a test rather than an episode")
	var view: Control=main.screen.get_child(main.screen.get_child_count()-1)
	view.answers[0].pressed.emit();view.next_button.pressed.emit()
	check(main.section=="test_result","selection and confirmation reach result")
	check(quest.test_results.has("1"),"last result saved")
	check(quest.current_id==before.current_id and quest.has_progress==before.has_progress,"test does not overwrite episode progress")
	quest.test_results.clear();quest._load_save()
	check(quest.test_results.has("1"),"last result survives save reload")
	main._show_selector("tests")
	var last: Label=main.screen.find_child("SelectorLastResult",true,false)
	check(last.text.contains("съедят"),"menu displays saved result")
	main.free()
	for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	await process_frame
	print("Quiz content: %d checks, %d failures" % [checks,failures])
	quit.call_deferred(1 if failures else 0)
func fits(label: Label) -> void:
	var optical=preload("res://scripts/ui/shared/optical_text_layout.gd")
	var area: Rect2=label.get_meta("optical_area")
	var font:Font=label.get_theme_font("font")
	var pixels=label.get_theme_font_size("font_size")
	var paragraph=TextParagraph.new();paragraph.width=area.size.x
	paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
	paragraph.add_string(label.text,font,pixels)
	var count=paragraph.get_line_count()
	var first=paragraph.get_line_range(0);var last=paragraph.get_line_range(count-1)
	var top=label.position.y+paragraph.get_line_ascent(0)+optical.ink(font,pixels,label.text.substr(first.x,first.y-first.x)).x
	var baseline=paragraph.get_line_ascent(count-1)
	for i:int in count-1:baseline+=paragraph.get_line_size(i).y+label.get_theme_constant("line_spacing")
	var bottom=label.position.y+baseline+optical.ink(font,pixels,label.text.substr(last.x,last.y-last.x)).y
	check(top>=area.position.y-0.1 and bottom<=area.end.y+0.1,"visible text inside its allotted area: "+label.text)
func _test_second_test_scoring() -> void:
	var state := QUIZ.new();state.start(2)
	for key: String in state.spec().questions:
		var question: Dictionary = state.spec().questions[key]
		for final_choice: int in question.options.size():
			for earlier_choice: int in question.options.size():
				state.start(2);state.question_id = int(key)
				state.select(earlier_choice);state.select(final_choice)
				check(state.score == 0, "selection alone does not award points")
				state.confirm()
				check(state.score == int(question.options[final_choice].points), "only confirmed answer determines points")
	# Build one answer path for every reachable score, then test each final
	# self-assessment answer against all four verdicts and every boundary.
	var paths: Dictionary = {0: []}
	for number: int in range(1, 10):
		var next_paths: Dictionary = {}
		var options: Array = state.spec().questions[str(number)].options
		for total: int in paths:
			for index: int in options.size():
				next_paths[total + int(options[index].points)] = paths[total] + [index]
		paths = next_paths
	var verdicts: Dictionary = {}
	for total: int in paths:
		var reference: Dictionary = {}
		for last_choice: int in 4:
			state.start(2)
			for index: int in paths[total]: state.select(index);state.confirm()
			check(state.question_id == 10 and state.score == total, "nine scored questions precede self-assessment")
			check(not state.question().scored, "self-assessment explicitly unscored")
			state.select(last_choice);state.confirm()
			check(state.answered == 10 and state.score == total, "self-assessment completes test without changing score")
			var expected := 29 if total < 6 else 30 if total < 16 else 31 if total < 26 else 32
			check(state.result.result_id == expected, "original verdict threshold")
			if reference.is_empty(): reference = state.result.duplicate(true)
			else: check(state.result == reference, "self-assessment cannot change verdict or saved result")
			verdicts[state.result.result_id] = true
	check(verdicts.size() == 4, "all four test II verdicts remain reachable")
	state.start(2)
	check(state.score == 0 and state.selected == -1 and state.result.is_empty(), "restart resets test II")
func _walk(node: int, path: Array, seen: Dictionary) -> void:
	var state := QUIZ.new();state.start(1)
	for index: int in path:state.select(index);state.confirm()
	if not state.result.is_empty():
		seen[state.result.result_id]=true
		check(state.result.result_id>=12 and state.result.result_id<=28,"original branch outcome ID")
		return
	check(path.size()<7,"branch depth bounded to original seven questions")
	for i: int in state.question().options.size():_walk(node,path+[i],seen)
