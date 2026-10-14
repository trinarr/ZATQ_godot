extends Control

signal next_requested
signal switched_off

const LOC := preload("res://scripts/core/localization.gd")

const BASE_SIZE := Vector2(1600, 960)
const TV_CENTER := Vector2(1184, 248)
const CLOSEUP_ZOOM := 2.0
# Inner glass corners measured on the 1619x971 room image, mapped to 1600x960.
const SCREEN_CORNERS := [
	Vector2(948.73, 117.65), Vector2(1418.16, 108.75), Vector2(1418.16, 378.66), Vector2(948.73, 381.63)
]
const NARRATIVE_KEYS := {
	"tv/news_anchor.png": "@loc:tv.channels.news_anchor",
	"tv/sport_news.png": "@loc:tv.channels.sport_news",
	"tv/commercial.png": "@loc:tv.channels.commercial",
	"tv/dorwood_nqc.png": "@loc:tv.channels.dorwood",
	"tv/hazmat_vestnik.png": "@loc:tv.channels.hazmat",
	"tv/maintenance_aera.png": "@loc:tv.channels.maintenance"
}
var suspended := false
var accepting_input := false
var closing := false
var camera_progress := 0.0
var channel_paths: Array = []
var channel_index := -1
var animation: Tween

@onready var room: Node2D = $Room
@onready var broadcast: Polygon2D = $Room/Broadcast
@onready var broadcast_viewport: SubViewport = $BroadcastViewport
@onready var picture: TextureRect = $BroadcastViewport/Picture
@onready var maintenance: Control = $BroadcastViewport/Maintenance
@onready var channel_label: Label = $BroadcastViewport/TVChannel

func _ready() -> void:
	clip_contents = true
	broadcast.polygon = PackedVector2Array(SCREEN_CORNERS)
	broadcast.uv = PackedVector2Array([Vector2.ZERO, Vector2(1536, 0), Vector2(1536, 864), Vector2(0, 864)])
	broadcast.texture = broadcast_viewport.get_texture()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_channel_label()

func _update_channel_label() -> void:
	if channel_index >= 0:
		channel_label.text = (LOC.text("@loc:ui.main.channel_format") % (channel_index + 1)).to_upper()

func narrative_text() -> String:
	if channel_index < 0 or channel_index >= channel_paths.size(): return ""
	return LOC.text(NARRATIVE_KEYS.get(str(channel_paths[channel_index]), ""))

func configure(index: int, paths: Array, animate: bool = false) -> void:
	channel_paths = paths
	show_channel(index)
	accepting_input = false
	if animate:
		camera_progress = 0.0
		_apply_camera(0.0)
		animation = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		animation.finished.connect(func(): animation = null)
		animation.tween_method(_apply_camera, 0.0, 1.0, 0.4)
		animation.tween_callback(func(): accepting_input = true)
	else:
		_apply_camera(1.0)
		accepting_input = true

func _apply_camera(progress: float) -> void:
	camera_progress = progress
	room.scale = Vector2.ONE * lerpf(1.0, CLOSEUP_ZOOM, progress)
	room.position = (BASE_SIZE * 0.5 - TV_CENTER * CLOSEUP_ZOOM) * progress

func show_channel(index: int) -> void:
	if index < 0 or index >= channel_paths.size() or closing: return
	if channel_index == index: return
	channel_index = index
	_update_channel_label()
	var path: String = "res://assets/flash_ui/" + str(channel_paths[index])
	var is_maintenance := path.ends_with("maintenance_aera.png")
	maintenance.visible = is_maintenance
	picture.visible = not is_maintenance
	picture.texture = null if is_maintenance else load(path)
	if is_maintenance: maintenance.refresh_text()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		if accepting_input and not suspended and not closing: next_requested.emit()

func switch_off() -> void:
	if closing: return
	closing = true
	accepting_input = false
	if animation != null and animation.is_valid(): animation.kill()
	animation = create_tween()
	animation.finished.connect(func(): animation = null)
	animation.tween_property(broadcast, "modulate:a", 0.0, 0.18)
	animation.tween_callback(func(): switched_off.emit())

func _process(_delta: float) -> void:
	# Pausing freezes both the entry and the power-off transition.
	if animation != null and animation.is_valid():
		if suspended: animation.pause()
		elif not animation.is_running(): animation.play()
