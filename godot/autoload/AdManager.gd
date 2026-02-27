extends Node

signal initialized
signal interstitial_loaded
signal interstitial_closed
signal interstitial_failed_to_load
signal interstitial_show_failed
signal rewarded_loaded
signal rewarded_closed
signal rewarded_earned
signal rewarded_failed_to_load
signal rewarded_show_failed

const APP_ID := "ca-app-pub-3940256099942544~3347511713"
const INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"
const REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"
const TEST_MODE := true

const SINGLETON_CANDIDATES := ["AdMobPlugin", "admobplugin", "AdMob", "GodotAdMob"]

var _plugin: Object = null

func _ready() -> void:
	if OS.get_name() != "Android":
		push_warning("AdManager: not running on Android.")
		return

	for name in SINGLETON_CANDIDATES:
		if Engine.has_singleton(name):
			_plugin = Engine.get_singleton(name)
			print("AdManager: found plugin singleton '%s'" % name)
			break

	if _plugin == null:
		push_error("AdManager: plugin singleton not found.")
		return

	_try_connect("initialized", _on_initialized)
	_try_connect("interstitial_loaded", _on_interstitial_loaded)
	_try_connect("interstitial_closed", _on_interstitial_closed)
	_try_connect("interstitial_failed_to_load", _on_interstitial_failed_to_load)
	_try_connect("interstitial_show_failed", _on_interstitial_show_failed)
	_try_connect("rewarded_loaded", _on_rewarded_loaded)
	_try_connect("rewarded_closed", _on_rewarded_closed)
	_try_connect("rewarded_earned", _on_rewarded_earned)
	_try_connect("rewarded_failed_to_load", _on_rewarded_failed_to_load)
	_try_connect("rewarded_show_failed", _on_rewarded_show_failed)

func initialize() -> void:
	if _plugin == null:
		return
	if _plugin.has_method("initialize"):
		_plugin.call("initialize", APP_ID, TEST_MODE)
		return
	if _plugin.has_method("init"):
		_plugin.call("init", APP_ID)

func load_interstitial() -> void:
	if _plugin == null:
		return
	if _plugin.has_method("load_interstitial"):
		_plugin.call("load_interstitial", INTERSTITIAL_ID)
		return
	if _plugin.has_method("loadInterstitial"):
		_plugin.call("loadInterstitial", INTERSTITIAL_ID)

func show_interstitial() -> bool:
	if _plugin == null:
		return false
	if _plugin.has_method("show_interstitial"):
		return bool(_plugin.call("show_interstitial"))
	if _plugin.has_method("showInterstitial"):
		return bool(_plugin.call("showInterstitial"))
	return false

func is_interstitial_loaded() -> bool:
	if _plugin == null:
		return false
	if _plugin.has_method("is_interstitial_loaded"):
		return bool(_plugin.call("is_interstitial_loaded"))
	if _plugin.has_method("isInterstitialLoaded"):
		return bool(_plugin.call("isInterstitialLoaded"))
	return false

func load_rewarded() -> void:
	if _plugin == null:
		return
	if _plugin.has_method("load_rewarded"):
		_plugin.call("load_rewarded", REWARDED_ID)
		return
	if _plugin.has_method("loadRewarded"):
		_plugin.call("loadRewarded", REWARDED_ID)

func show_rewarded() -> bool:
	if _plugin == null:
		return false
	if _plugin.has_method("show_rewarded"):
		return bool(_plugin.call("show_rewarded"))
	if _plugin.has_method("showRewarded"):
		return bool(_plugin.call("showRewarded"))
	return false

func is_rewarded_loaded() -> bool:
	if _plugin == null:
		return false
	if _plugin.has_method("is_rewarded_loaded"):
		return bool(_plugin.call("is_rewarded_loaded"))
	if _plugin.has_method("isRewardedLoaded"):
		return bool(_plugin.call("isRewardedLoaded"))
	return false

func _try_connect(signal_name: String, callback: Callable) -> void:
	if _plugin == null:
		return
	if not _plugin.has_signal(signal_name):
		return
	if _plugin.is_connected(signal_name, callback):
		return
	_plugin.connect(signal_name, callback)

func _on_initialized() -> void:
	emit_signal("initialized")

func _on_interstitial_loaded() -> void:
	emit_signal("interstitial_loaded")

func _on_interstitial_closed() -> void:
	emit_signal("interstitial_closed")
	load_interstitial()

func _on_interstitial_failed_to_load() -> void:
	emit_signal("interstitial_failed_to_load")

func _on_interstitial_show_failed() -> void:
	emit_signal("interstitial_show_failed")

func _on_rewarded_loaded() -> void:
	emit_signal("rewarded_loaded")

func _on_rewarded_closed() -> void:
	emit_signal("rewarded_closed")
	load_rewarded()

func _on_rewarded_earned() -> void:
	emit_signal("rewarded_earned")

func _on_rewarded_failed_to_load() -> void:
	emit_signal("rewarded_failed_to_load")

func _on_rewarded_show_failed() -> void:
	emit_signal("rewarded_show_failed")
