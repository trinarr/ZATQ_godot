extends Node

class_name YandexAds

signal sdk_initialized
signal banner_loaded(size_pixels: Vector2)
signal banner_failed_to_load(error_code: int)
signal interstitial_loaded
signal interstitial_failed_to_load(error_code: int)
signal interstitial_shown
signal interstitial_failed_to_show(message: String)
signal interstitial_closed
signal rewarded(currency: String, amount: int)
signal rewarded_for_request(request_id: String, currency: String, amount: int)
signal rewarded_video_closed_for_request(request_id: String)
signal rewarded_video_failed_to_show_for_request(request_id: String, message: String)
signal rewarded_video_loaded
signal rewarded_video_failed_to_load(error_code: int)
signal rewarded_video_failed_to_show(message: String)
signal rewarded_video_closed

const DEFAULT_BANNER_ID := "demo-banner-yandex"
const DEFAULT_INTERSTITIAL_ID := "demo-interstitial-yandex"
const DEFAULT_REWARDED_ID := "demo-rewarded-yandex"
const PLUGIN_SINGLETON := "GodotAndroidYandexAds"

var banner_id: String = DEFAULT_BANNER_ID
var interstitial_id: String = DEFAULT_INTERSTITIAL_ID
var rewarded_id: String = DEFAULT_REWARDED_ID
var banner_on_top: bool = false
var banner_width_dp: int = 320
var banner_height_dp: int = 50
var age_restricted_user: bool = false
var user_consent: bool = false
var logging_enabled: bool = false

var _native: Object = null
var _sdk_ready: bool = false
var _sdk_initialization_requested: bool = false
var _banner_wanted: bool = false
var _banner_loading: bool = false
var _banner_loaded: bool = false
var _interstitial_loading: bool = false
var _interstitial_loaded: bool = false
var _interstitial_loading_id: String = ""
var _interstitial_loaded_id: String = ""
var _rewarded_loading: bool = false
var _rewarded_loaded: bool = false
var _rewarded_loading_id: String = ""
var _rewarded_loaded_id: String = ""
var _rewarded_pending_show: bool = false
var _rewarded_pending_validator: Callable = Callable()
var _rewarded_pending_request_id: String = ""
# Drain an in-flight request after a privacy or placement change without exposing
# the stale ad. The bundled native bridge has untagged load callbacks, so each
# replacement is serialized until the old callback has been drained.
var _discard_banner_load: bool = false
var _discard_interstitial_load: bool = false
var _discard_rewarded_load: bool = false
var _rewarded_show_id: String = ""
var _rewarded_show_open: bool = false
var _rewarded_show_legacy: bool = false
var _rewarded_show_tagged_legacy_bridge: bool = false

func _enter_tree() -> void:
	_read_project_settings()
	_bind_native_plugin()

func _exit_tree() -> void:
	if is_native_available():
		_native.removeBanner()

func _read_project_settings() -> void:
	# Debug/editor builds always use Yandex demo units. Release exports use the
	# project settings; fullscreen units can be specified per placement.
	if OS.is_debug_build():
		banner_id = DEFAULT_BANNER_ID
		interstitial_id = DEFAULT_INTERSTITIAL_ID
		rewarded_id = DEFAULT_REWARDED_ID
	else:
		banner_id = str(ProjectSettings.get_setting("yandex_ads/banner_id", DEFAULT_BANNER_ID))
		interstitial_id = str(ProjectSettings.get_setting("yandex_ads/interstitial_id", DEFAULT_INTERSTITIAL_ID))
		rewarded_id = str(ProjectSettings.get_setting("yandex_ads/rewarded_id", DEFAULT_REWARDED_ID))
	user_consent = bool(ProjectSettings.get_setting("yandex_ads/user_consent", false))
	age_restricted_user = bool(ProjectSettings.get_setting(
		"yandex_ads/age_restricted_user",
		false
	))
	logging_enabled = OS.is_debug_build() and bool(ProjectSettings.get_setting(
		"yandex_ads/logging_enabled",
		OS.is_debug_build()
	))

func _rewarded_id_for_placement(placement: StringName) -> String:
	if OS.is_debug_build():
		return DEFAULT_REWARDED_ID
	return str(ProjectSettings.get_setting("yandex_ads/rewarded_placements", {}).get(placement, rewarded_id))

func _interstitial_id_for_placement(placement: StringName) -> String:
	if OS.is_debug_build():
		return DEFAULT_INTERSTITIAL_ID
	return str(ProjectSettings.get_setting("yandex_ads/interstitial_placements", {}).get(placement, interstitial_id))

func _bind_native_plugin() -> bool:
	if !Engine.has_singleton(PLUGIN_SINGLETON):
		return false
	_native = Engine.get_singleton(PLUGIN_SINGLETON)
	_connect_native_signals()
	return true

func initialize_after_consent(consent_value: bool) -> bool:
	if !is_native_available() and !_bind_native_plugin():
		user_consent = consent_value
		return false
	# Consent must reach Yandex before initialize(). The native configure() method
	# applies the privacy flags first and only then requests SDK initialization.
	if _sdk_ready or _sdk_initialization_requested:
		set_user_consent(consent_value)
		return true
	user_consent = consent_value
	_sdk_initialization_requested = true
	_native.configure(age_restricted_user, user_consent, logging_enabled)
	return true

func is_native_available() -> bool:
	return _native != null and is_instance_valid(_native)

func is_sdk_ready() -> bool:
	return _sdk_ready

func _connect_native_signals() -> void:
	_connect_native(&"_on_sdk_initialized", Callable(self, "_on_sdk_initialized"))
	_connect_native(&"_on_banner_loaded", Callable(self, "_on_banner_loaded"))
	_connect_native(&"_on_banner_failed_to_load", Callable(self, "_on_banner_failed_to_load"))
	_connect_native(&"_on_interstitial_loaded", Callable(self, "_on_interstitial_loaded"))
	_connect_native(
		&"_on_interstitial_failed_to_load",
		Callable(self, "_on_interstitial_failed_to_load")
	)
	_connect_native(&"_on_interstitial_ad_show", Callable(self, "_on_interstitial_ad_show"))
	_connect_native(
		&"_on_interstitial_failed_to_show",
		Callable(self, "_on_interstitial_failed_to_show")
	)
	_connect_native(
		&"_on_interstitial_ad_dismissed",
		Callable(self, "_on_interstitial_ad_dismissed")
	)
	if _native.has_method("showRewardedVideoForRequest"):
		_connect_native(&"_on_rewarded_for_request", Callable(self, "_on_rewarded_for_request"))
		_connect_native(&"_on_rewarded_closed_for_request", Callable(self, "_on_rewarded_closed_for_request"))
		_connect_native(&"_on_rewarded_failed_for_request", Callable(self, "_on_rewarded_failed_for_request"))
	else:
		_connect_native(&"_on_rewarded", Callable(self, "_on_rewarded"))
		_connect_native(&"_on_rewarded_video_ad_failed_to_show", Callable(self, "_on_rewarded_video_ad_failed_to_show"))
		_connect_native(&"_on_rewarded_video_ad_dismissed", Callable(self, "_on_rewarded_video_ad_dismissed"))
	_connect_native(
		&"_on_rewarded_video_ad_loaded",
		Callable(self, "_on_rewarded_video_ad_loaded")
	)
	_connect_native(
		&"_on_rewarded_video_ad_failed_to_load",
		Callable(self, "_on_rewarded_video_ad_failed_to_load")
	)

func _connect_native(signal_name: StringName, callback: Callable) -> void:
	if _native.has_signal(signal_name) and !_native.is_connected(signal_name, callback):
		_native.connect(signal_name, callback)

func show_banner() -> void:
	# Do not even queue a banner request before the app has explicitly started the
	# SDK after the user's personalization choice.
	if !_sdk_initialization_requested:
		return
	_banner_wanted = true
	if !is_native_available() or !_sdk_ready:
		return
	if _banner_loaded:
		_native.showBanner()
		return
	load_banner()

func hide_banner() -> void:
	_banner_wanted = false
	if is_native_available():
		_native.hideBanner()

func load_banner() -> void:
	if !is_native_available() or !_sdk_ready or banner_id.is_empty() or _banner_loading:
		return
	_banner_loading = true
	_banner_loaded = false
	_native.loadBanner(banner_id, banner_on_top, banner_width_dp, banner_height_dp)

func remove_banner() -> void:
	_banner_wanted = false
	_banner_loading = false
	_banner_loaded = false
	if is_native_available():
		_native.removeBanner()

func get_banner_dimension() -> Vector2:
	if !is_native_available():
		return Vector2.ZERO
	return Vector2(float(_native.getBannerWidth()), float(_native.getBannerHeight()))

func prepare_interstitial_placement(placement: StringName) -> bool:
	var placement_id: String = _interstitial_id_for_placement(placement)
	if placement_id.is_empty():
		return false
	_select_interstitial_id(placement_id)
	return true

func _select_interstitial_id(placement_id: String) -> void:
	if placement_id.is_empty():
		return
	interstitial_id = placement_id
	if _interstitial_loading:
		if _interstitial_loading_id != interstitial_id:
			_discard_interstitial_load = true
		return
	if _interstitial_loaded and _interstitial_loaded_id != interstitial_id:
		_interstitial_loaded = false
		_interstitial_loaded_id = ""
	if !_interstitial_loaded:
		load_interstitial()

func load_interstitial() -> void:
	if (
		!is_native_available()
		or !_sdk_ready
		or interstitial_id.is_empty()
		or _interstitial_loading
		or (_interstitial_loaded and _interstitial_loaded_id == interstitial_id)
	):
		return
	_interstitial_loading = true
	_interstitial_loaded = false
	_interstitial_loading_id = interstitial_id
	_native.loadInterstitial(interstitial_id)

func is_interstitial_loaded(placement: StringName = &"") -> bool:
	if placement == &"":
		return _interstitial_loaded
	var placement_id: String = _interstitial_id_for_placement(placement)
	return _interstitial_loaded and !placement_id.is_empty() and _interstitial_loaded_id == placement_id

func show_interstitial(placement: StringName = &"") -> bool:
	if placement != &"" and !prepare_interstitial_placement(placement):
		return false
	if !is_native_available() or !_sdk_ready or interstitial_id.is_empty():
		return false
	if _interstitial_loaded and _interstitial_loaded_id == interstitial_id:
		_start_interstitial_show()
		return true
	# A network request must never block navigation or auto-show later.
	load_interstitial()
	return false

func _start_interstitial_show() -> void:
	if !is_native_available() or !_interstitial_loaded:
		return
	_interstitial_loaded = false
	_interstitial_loaded_id = ""
	_native.showInterstitial()

func prepare_rewarded_placement(placement: StringName) -> bool:
	var placement_id: String = _rewarded_id_for_placement(placement)
	if placement_id.is_empty():
		return false
	_select_rewarded_id(placement_id)
	return true

func _select_rewarded_id(placement_id: String) -> void:
	if placement_id.is_empty():
		return
	# Keep the unit selected by the user's tap stable while it is loading. A later
	# UI refresh may warm another placement, but it must not hijack this show.
	if _rewarded_pending_show and rewarded_id != placement_id:
		return
	rewarded_id = placement_id
	if _rewarded_show_open:
		return
	if _rewarded_loading:
		if _rewarded_loading_id != rewarded_id:
			_discard_rewarded_load = true
		return
	if _rewarded_loaded and _rewarded_loaded_id != rewarded_id:
		_rewarded_loaded = false
		_rewarded_loaded_id = ""
	if !_rewarded_loaded:
		load_rewarded_video()

func load_rewarded_video() -> void:
	if (
		!is_native_available()
		or !_sdk_ready
		or rewarded_id.is_empty()
		or _rewarded_loading
		or _rewarded_show_open
		or (_rewarded_loaded and _rewarded_loaded_id == rewarded_id)
	):
		return
	_rewarded_loading = true
	_rewarded_loaded = false
	_rewarded_loading_id = rewarded_id
	_native.loadRewardedVideo(rewarded_id)

func is_rewarded_video_loaded(placement: StringName = &"") -> bool:
	if placement == &"":
		return _rewarded_loaded
	var placement_id: String = _rewarded_id_for_placement(placement)
	return _rewarded_loaded and !placement_id.is_empty() and _rewarded_loaded_id == placement_id

func can_request_rewarded_video(placement: StringName = &"") -> bool:
	if !is_native_available() or !_sdk_ready:
		return false
	if placement == &"":
		return !rewarded_id.is_empty()
	return !_rewarded_id_for_placement(placement).is_empty()

func show_rewarded_video(
	request_id: String = "", placement: StringName = &"", validator: Callable = Callable()
) -> bool:
	if _rewarded_show_open or _rewarded_pending_show:
		return false
	if placement != &"" and !prepare_rewarded_placement(placement):
		return false
	if !is_native_available() or !_sdk_ready or rewarded_id.is_empty():
		return false
	_rewarded_pending_show = true
	_rewarded_pending_request_id = request_id
	_rewarded_pending_validator = validator
	if _rewarded_loaded and _rewarded_loaded_id == rewarded_id:
		_start_rewarded_show(request_id)
		return _rewarded_show_open
	load_rewarded_video()
	return true

func cancel_pending_rewarded_request(request_id: String) -> bool:
	if !_rewarded_pending_show or _rewarded_pending_request_id != request_id:
		return false
	_rewarded_pending_show = false
	_rewarded_pending_request_id = ""
	_rewarded_pending_validator = Callable()
	return true

func is_rewarded_request_pending(request_id: String) -> bool:
	return _rewarded_pending_show and _rewarded_pending_request_id == request_id

func _start_rewarded_show(request_id: String) -> void:
	# A deferred loaded callback may belong to an already cancelled request.
	if !_rewarded_pending_show or _rewarded_pending_request_id != request_id:
		return
	if !_rewarded_pending_validator.is_null() and (
		!_rewarded_pending_validator.is_valid() or !bool(_rewarded_pending_validator.call())
	):
		_fail_pending_rewarded_show("Reward context changed")
		return
	if !is_native_available() or !_rewarded_loaded or _rewarded_show_open:
		return
	_rewarded_pending_validator = Callable()
	_rewarded_pending_show = false
	_rewarded_pending_request_id = ""
	_rewarded_loaded = false
	_rewarded_loaded_id = ""
	_rewarded_show_legacy = request_id.is_empty()
	_rewarded_show_id = request_id if !request_id.is_empty() else "action:%d" % Time.get_ticks_usec()
	_rewarded_show_open = true
	_rewarded_show_tagged_legacy_bridge = (
		!request_id.is_empty()
		and !_native.has_method("showRewardedVideoForRequest")
	)
	if _native.has_method("showRewardedVideoForRequest"):
		_native.showRewardedVideoForRequest(_rewarded_show_id)
	else:
		# Keep tagged final-reward requests working with an older cached Android
		# bridge too. The wrapper owns the single active show id and converts the
		# legacy native callbacks back into the request-specific Godot signals.
		_native.showRewardedVideo()

func _fail_pending_rewarded_show(message: String) -> void:
	if !_rewarded_pending_show:
		return
	var request_id: String = _rewarded_pending_request_id
	_rewarded_pending_validator = Callable()
	_rewarded_pending_show = false
	_rewarded_pending_request_id = ""
	if request_id.is_empty():
		rewarded_video_failed_to_show.emit(message)
	else:
		rewarded_video_failed_to_show_for_request.emit(request_id, message)

func _on_rewarded_for_request(request_id: String, currency: String, amount: int) -> void:
	# Deliver late tagged rewards even after another show or navigation. Legacy
	# consumers only receive callbacks belonging to their own current show.
	rewarded_for_request.emit(request_id, currency, amount)
	if request_id == _rewarded_show_id and _rewarded_show_legacy:
		rewarded.emit(currency, amount)

func _on_rewarded_closed_for_request(request_id: String) -> void:
	if request_id == _rewarded_show_id and _rewarded_show_open:
		_rewarded_show_open = false
		_rewarded_loaded = false
		_rewarded_loaded_id = ""
		if _rewarded_show_legacy:
			rewarded_video_closed.emit()
		call_deferred("load_rewarded_video")
	rewarded_video_closed_for_request.emit(request_id)

func _on_rewarded_failed_for_request(request_id: String, message: String) -> void:
	if request_id == _rewarded_show_id and _rewarded_show_open:
		_rewarded_show_open = false
		_rewarded_loaded = false
		_rewarded_loaded_id = ""
		if _rewarded_show_legacy:
			rewarded_video_failed_to_show.emit(message)
		call_deferred("load_rewarded_video")
	rewarded_video_failed_to_show_for_request.emit(request_id, message)

func set_user_consent(value: bool) -> void:
	var changed: bool = user_consent != value
	user_consent = value
	if !is_native_available():
		return
	_native.setUserConsent(value)
	if !changed or !_sdk_ready:
		return
	# Never show a cached ad loaded with the previous choice. Do not revoke
	# reward callbacks for an already shown ad: earned rewards remain valid.
	_discard_banner_load = _banner_loading
	_discard_interstitial_load = _interstitial_loading
	_discard_rewarded_load = _rewarded_loading
	_banner_loaded = false
	_interstitial_loaded = false
	_interstitial_loaded_id = ""
	_rewarded_loaded = false
	_rewarded_loaded_id = ""
	_native.hideBanner()
	if !_banner_loading:
		_native.removeBanner()
		if _banner_wanted:
			load_banner()
	if !_interstitial_loading:
		load_interstitial()
	if !_rewarded_loading and !_rewarded_show_open:
		load_rewarded_video()

func _finish_discarded_banner_load() -> void:
	_discard_banner_load = false
	_banner_loaded = false
	_native.removeBanner()
	if _banner_wanted:
		load_banner()

func _on_sdk_initialized() -> void:
	# configure() runs on Android UI thread. Re-apply the latest choice if it
	# changed while initialization was in flight, before any load/listener runs.
	_native.setUserConsent(user_consent)
	_sdk_ready = true
	sdk_initialized.emit()
	if _banner_wanted:
		load_banner()
	# Debug keeps the original eager demo preload. Release fullscreen units are
	# selected by gameplay placement before loading so one point cannot use another
	# point's production ad unit.
	if OS.is_debug_build():
		load_interstitial()
		load_rewarded_video()

func _on_banner_loaded() -> void:
	_banner_loading = false
	if _discard_banner_load:
		_finish_discarded_banner_load()
		return
	_banner_loaded = true
	if _banner_wanted:
		_native.showBanner()
	else:
		_native.hideBanner()
	banner_loaded.emit(get_banner_dimension())

func _on_banner_failed_to_load(error_code: int) -> void:
	_banner_loading = false
	if _discard_banner_load:
		_finish_discarded_banner_load()
		return
	_banner_loaded = false
	banner_failed_to_load.emit(error_code)

func _on_interstitial_loaded() -> void:
	var loaded_id: String = _interstitial_loading_id
	_interstitial_loading = false
	_interstitial_loading_id = ""
	if _discard_interstitial_load or loaded_id != interstitial_id:
		_discard_interstitial_load = false
		_interstitial_loaded = false
		_interstitial_loaded_id = ""
		load_interstitial()
		return
	_interstitial_loaded = true
	_interstitial_loaded_id = loaded_id
	interstitial_loaded.emit()

func _on_interstitial_failed_to_load(error_code: int) -> void:
	var failed_id: String = _interstitial_loading_id
	_interstitial_loading = false
	_interstitial_loading_id = ""
	if _discard_interstitial_load or failed_id != interstitial_id:
		_discard_interstitial_load = false
		_interstitial_loaded = false
		_interstitial_loaded_id = ""
		load_interstitial()
		return
	_interstitial_loaded = false
	_interstitial_loaded_id = ""
	interstitial_failed_to_load.emit(error_code)

func _on_interstitial_ad_show() -> void:
	interstitial_shown.emit()

func _on_interstitial_failed_to_show(message: String) -> void:
	_interstitial_loaded = false
	_interstitial_loaded_id = ""
	interstitial_failed_to_show.emit(message)
	call_deferred("load_interstitial")

func _on_interstitial_ad_dismissed() -> void:
	_interstitial_loaded = false
	_interstitial_loaded_id = ""
	interstitial_closed.emit()
	call_deferred("load_interstitial")

func _on_rewarded(currency: String, amount: int) -> void:
	if _rewarded_show_tagged_legacy_bridge and !_rewarded_show_id.is_empty():
		rewarded_for_request.emit(_rewarded_show_id, currency, amount)
		return
	rewarded.emit(currency, amount)

func _on_rewarded_video_ad_loaded() -> void:
	var loaded_id: String = _rewarded_loading_id
	_rewarded_loading = false
	_rewarded_loading_id = ""
	if _discard_rewarded_load or loaded_id != rewarded_id:
		_discard_rewarded_load = false
		_rewarded_loaded = false
		_rewarded_loaded_id = ""
		load_rewarded_video()
		return
	_rewarded_loaded = true
	_rewarded_loaded_id = loaded_id
	rewarded_video_loaded.emit()
	if _rewarded_pending_show:
		call_deferred("_start_rewarded_show", _rewarded_pending_request_id)

func _on_rewarded_video_ad_failed_to_load(error_code: int) -> void:
	var failed_id: String = _rewarded_loading_id
	_rewarded_loading = false
	_rewarded_loading_id = ""
	if _discard_rewarded_load or failed_id != rewarded_id:
		_discard_rewarded_load = false
		_rewarded_loaded = false
		_rewarded_loaded_id = ""
		load_rewarded_video()
		return
	_rewarded_loaded = false
	_rewarded_loaded_id = ""
	rewarded_video_failed_to_load.emit(error_code)
	_fail_pending_rewarded_show("Rewarded ad failed to load: %d" % error_code)

func _on_rewarded_video_ad_failed_to_show(message: String) -> void:
	var request_id: String = _rewarded_show_id
	var tagged_legacy_bridge: bool = _rewarded_show_tagged_legacy_bridge
	_rewarded_show_open = false
	_rewarded_loaded = false
	_rewarded_loaded_id = ""
	if tagged_legacy_bridge and !request_id.is_empty():
		rewarded_video_failed_to_show_for_request.emit(request_id, message)
	else:
		rewarded_video_failed_to_show.emit(message)
	call_deferred("load_rewarded_video")

func _on_rewarded_video_ad_dismissed() -> void:
	var request_id: String = _rewarded_show_id
	var tagged_legacy_bridge: bool = _rewarded_show_tagged_legacy_bridge
	_rewarded_show_open = false
	_rewarded_loaded = false
	_rewarded_loaded_id = ""
	if tagged_legacy_bridge and !request_id.is_empty():
		rewarded_video_closed_for_request.emit(request_id)
	else:
		rewarded_video_closed.emit()
	call_deferred("load_rewarded_video")
