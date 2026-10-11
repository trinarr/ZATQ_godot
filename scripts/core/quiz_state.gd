extends RefCounted
const LOC := preload("res://scripts/core/localization.gd")
var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tests.json"))
var test_id := 0
var question_id := 1
var selected := -1
var score := 0
var answered := 0
var hints: Array[String] = []
var result: Dictionary = {}

func start(number: int) -> void:
	assert(number >= 1 and number <= 5)
	test_id = number
	question_id = 1
	selected = -1
	score = int(spec().initial_score)
	answered = 0
	hints.clear()
	result.clear()

func spec() -> Dictionary:
	return catalog.tests[test_id-1]

func question() -> Dictionary:
	return spec().questions[str(question_id)]

func select(index: int) -> void:
	if not result.is_empty() or index < 0 or index >= question().options.size(): return
	selected = index

func confirm() -> bool:
	if selected < 0 or not result.is_empty(): return false
	var item: Dictionary = question().options[selected]
	answered += 1
	if test_id == 1:
		if item.has("result_id"):
			var outcome: Dictionary = catalog.outcomes[str(int(item.result_id))]
			result = {"label":outcome.label,"text":outcome.text,"advice":"@loc:tests.ui.no_advice","result_id":int(item.result_id)}
		else: question_id = int(item.next)
	else:
		var points := int(item.points) if question().get("scored", true) else 0
		score += points
		if (test_id == 3 and points <= 2) or (test_id == 5 and points < 2): hints.append(question().hint)
		if question_id == spec().questions.size(): _finish()
		else: question_id += 1
	selected = -1
	return true

func _finish() -> void:
	var advice: String = hints.pick_random() if not hints.is_empty() else "@loc:tests.ui.no_hints"
	match test_id:
		2:
			var id := 29 if score < 6 else 30 if score < 16 else 31 if score < 26 else 32
			var outcome: Dictionary = catalog.outcomes[str(id)]
			result = {"label":outcome.label,"text":outcome.text,"advice":"@loc:tests.ui.no_advice","result_id":id}
		3:
			var band := 0 if score < 15 else 1 if score < 32 else 2 if score < 40 else 3 if score < 50 else 4 if score < 60 else 5 if score < 70 else 6 if score == 88 else 7
			result = {"label":"%d%%" % roundi(float(score)/88*100),"text":catalog.outcomes["50"][band],"advice":advice,"result_id":50}
		4:
			score = clampi(score,0,100)
			var band := floori(float(score)/100*11)
			var outcome: Dictionary = catalog.outcomes["100"][band]
			result = {"label":outcome.duration,"text":outcome.text,"advice":outcome.analog,"result_id":100,"analog":true}
		5:
			var percent := roundi(float(score)/41*100)
			var band := 0 if percent < 20 else 1 if percent < 50 else 2 if percent < 70 else 3 if percent < 85 else 4 if percent < 100 else 5
			result = {"label":"%d%%" % percent,"text":catalog.outcomes["150"][band],"advice":advice,"result_id":150}
	result.score = score
