extends "res://scripts/ui/shared/modal_view.gd"
signal resume_requested
signal restart_requested
signal sound_requested
signal menu_requested
signal quit_requested
var resume_art: TextureRect
var resume_hit: Button

func configure(sound_enabled: bool) -> void:
	add_shade(0.6)
	_art("layout_pause")
	_button_text(LOC.text("@loc:ui.main.24") + LOC.text("@loc:ui.main.25" if sound_enabled else "@loc:ui.main.26"),Rect2(101,170,243,42),22,null,TITLE_FONT)
	_hit("@loc:ui.main.28",Rect2(15,94,290,64),func(): restart_requested.emit())
	_hit("@loc:ui.main.29",Rect2(73,158,280,62),func(): sound_requested.emit())
	_hit("@loc:ui.main.30",Rect2(72,225,280,62),func(): menu_requested.emit())
	_hit("@loc:ui.main.31",Rect2(20,290,290,62),func(): quit_requested.emit())
	var source: Texture2D = load("res://assets/flash_ui/pause_button.png")
	var image := source.get_image()
	if image.is_compressed(): image.decompress()
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = image.get_used_rect()
	resume_art = TextureRect.new()
	resume_art.texture = atlas
	resume_art.size = atlas.region.size
	resume_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	resume_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(resume_art)
	resume_hit = _hit("@loc:ui.main.27",Rect2(Vector2.ZERO,atlas.region.size/2),func(): resume_requested.emit())
	set_cover_rect(cover_rect)

func set_cover_rect(rect: Rect2) -> void:
	super.set_cover_rect(rect)
	if is_instance_valid(resume_art):
		resume_art.position = Vector2(rect.position.x,rect.position.y+(rect.size.y-resume_art.size.y)*0.5)
		resume_hit.position = resume_art.position
		resume_hit.size = resume_art.size
