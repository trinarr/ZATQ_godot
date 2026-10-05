extends Node
# Registered before the game autoloads so startup print() output is captured too.
# Native Android Logcat is outside Godot's Logger stream.

class ConsoleLogger:
	extends Logger
	const MAX_PENDING: int = 2048
	var _lock: Mutex = Mutex.new()
	var _pending: Array[Dictionary] = []
	var _dropped: int = 0

	func _enqueue(message: String, severity: int) -> void:
		# Logger callbacks may run on worker threads. Never touch the UI here.
		_lock.lock()
		if _pending.size() < MAX_PENDING:
			_pending.append({"text": message.left(16384), "severity": severity})
		else:
			_dropped += 1
		_lock.unlock()

	func _log_message(message: String, error: bool) -> void:
		_enqueue(message, 2 if error else 0)

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		var detail: String = rationale if not rationale.is_empty() else code
		_enqueue("%s (%s:%d, %s)" % [detail, file, line, function],
			1 if error_type == Logger.ERROR_TYPE_WARNING else 2)

	func take_batch() -> Array[Dictionary]:
		var batch: Array[Dictionary] = []
		_lock.lock()
		for _index: int in range(mini(_pending.size(), 100)):
			batch.append(_pending.pop_front())
		if _dropped > 0:
			batch.append({"text": "[Console] Skipped %d messages during log overflow" % _dropped, "severity": 1})
			_dropped = 0
		_lock.unlock()
		return batch

const TAP_GAP_MSEC: int = 450
const TAP_HOLD_MSEC: int = 300
const TAP_WINDOW_MSEC: int = 1500
const HOT_CORNER_RATIO: Vector2 = Vector2(0.18, 0.10)
var _logger: ConsoleLogger
var _tap_count: int = 0
var _first_tap_msec: int = 0
var _last_tap_msec: int = 0
var _pointer: int = -99
var _press_position: Vector2
var _press_msec: int = 0

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var enabled: bool = OS.is_debug_build() and not Engine.is_editor_hint()
	set_process(enabled)
	set_process_input(enabled)
	if enabled:
		_logger = ConsoleLogger.new()
		OS.add_logger(_logger)

func _exit_tree() -> void:
	if _logger != null:
		OS.remove_logger(_logger)
		_logger = null

func _process(_delta: float) -> void:
	var console: Node = get_node_or_null("/root/DevConsole")
	if _logger == null or console == null or not console.is_node_ready():
		return
	for entry: Dictionary in _logger.take_batch():
		match int(entry["severity"]):
			1: console.call("print_warning", str(entry["text"]))
			2: console.call("print_error", str(entry["text"]))
			_: console.call("print_line", str(entry["text"]))

func _in_hot_corner(position: Vector2) -> bool:
	var rect: Rect2 = get_viewport().get_visible_rect()
	return Rect2(rect.position + Vector2(rect.size.x * (1.0 - HOT_CORNER_RATIO.x), 0.0),
		rect.size * HOT_CORNER_RATIO).has_point(position)

func _reset_taps() -> void:
	_tap_count = 0
	_pointer = -99

func _record_tap(position: Vector2, now_msec: int) -> bool:
	if not _in_hot_corner(position):
		_reset_taps()
		return false
	if _tap_count == 0 or now_msec - _last_tap_msec > TAP_GAP_MSEC or now_msec - _first_tap_msec > TAP_WINDOW_MSEC:
		_tap_count = 0
		_first_tap_msec = now_msec
	_last_tap_msec = now_msec
	_tap_count += 1
	if _tap_count < 4:
		return false
	_reset_taps()
	var console: Node = get_node_or_null("/root/DevConsole")
	if console != null:
		console.set("visible", not bool(console.get("visible")))
	return true

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var position: Vector2
	var pressed: bool
	var pointer: int
	if event is InputEventScreenTouch:
		position = event.position
		pressed = event.pressed
		pointer = event.index
		if event.canceled:
			_reset_taps()
			return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Godot synthesizes a mouse event from touch. Never count it a second time.
		if event.device == -1:
			return
		position = event.position
		pressed = event.pressed
		pointer = -1
	else:
		return
	var now_msec: int = Time.get_ticks_msec()
	if pressed:
		if _pointer != -99 or not _in_hot_corner(position):
			_reset_taps()
			return
		_pointer = pointer
		_press_position = position
		_press_msec = now_msec
	elif pointer == _pointer:
		_pointer = -99
		var drag_limit: float = get_viewport().get_visible_rect().size.x * 0.03
		if now_msec - _press_msec > TAP_HOLD_MSEC or position.distance_to(_press_position) > drag_limit:
			_reset_taps()
			return
		if _record_tap(position, now_msec):
			get_viewport().set_input_as_handled()
