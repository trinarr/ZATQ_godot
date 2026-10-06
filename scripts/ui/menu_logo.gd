extends Control
# LogoMov's four existing texture parts, played once at the authored 19 fps.
const DATA := preload("res://scripts/ui/menu_timeline.gd")
var parts: Dictionary = {}
var frame := 0
var elapsed := 0.0
var finished := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_components.json"))
	for part: Dictionary in catalog.adaptive_menu:
		if not String(part.source).begins_with("Symbol 132/"): continue
		var image := TextureRect.new()
		image.texture = load("res://assets/flash_ui/" + part.texture)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.position = (Vector2(part.rect[0],part.rect[1])-Vector2(415,70))*2
		image.size = Vector2(part.rect[2],part.rect[3])*2
		add_child(image)
		parts[part.source] = image
	seek_frame(0)

func _process(delta: float) -> void:
	if finished: return
	elapsed += delta
	seek_frame(int(floor(elapsed * DATA.timelines().fps)))

func seek_frame(index: int) -> void:
	var logo: Dictionary = DATA.timelines().logo
	frame = clampi(index,0,int(logo.frames)-1)
	for track: Dictionary in logo.tracks:
		parts[track.source].self_modulate.a = track.alpha[frame]
	finished = frame == int(logo.frames)-1
