extends Control
# Flash: Symbol 211.LeftOpt (132,280), Tick1/2/3 at (152/167/182,4).
# ResultBad.Summer orders Episode III as 64, 68, then the shared 67/73 ending.
const ORIGINAL_SLOTS := {1:[6,77,78],2:[38,43,47],3:[64,68,67]}
# Same clean tick sprite and shader extrusion as the win counter.
const ICON_VIEW := preload("res://scripts/ui/statistic_icon.gd")
const ICON: Texture2D = preload("res://assets/flash_ui/components/stat_tick.png")
const UNSEEN_COLOR := Color("803c3c")
const LAYOUT := preload("res://scripts/ui/landscape_stage_layout.gd")

static func ending_slots(number: int, nodes: Dictionary) -> Array:
	if ORIGINAL_SLOTS.has(number): return ORIGINAL_SLOTS[number]
	var ids: Array = []
	for node: Dictionary in nodes.values():
		if int(node.get("episode",1))!=number or not node.get("alive",false) or not node.has("result_id"): continue
		var id: int = int(node.get("ending_id",node.result_id))
		if id not in ids: ids.append(id)
	ids.sort()
	return ids

func configure(number: int, unlocked: Array, nodes: Dictionary) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var slots := ending_slots(number,nodes)
	for i: int in slots.size():
		var tick := ICON_VIEW.new()
		tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tick.name = "EndingTick%d" % (i+1)
		tick.texture = ICON
		tick.modulate = Color.WHITE if slots[i] in unlocked else UNSEEN_COLOR
		var rect := LAYOUT.scaled_rect(Rect2(284+i*15,284,14,17))
		tick.position = rect.position
		tick.size = rect.size
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.set_meta("ending_id",slots[i])
		add_child(tick)
