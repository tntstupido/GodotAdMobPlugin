extends Node

## AdManager — autoload singleton for AdMob interstitial ads.
##
## Setup in project.godot:
##   [autoload]
##   AdManager="*res://autoload/AdManager.gd"
##
## Usage:
##   AdManager.initialize()
##   AdManager.load_interstitial()
##   AdManager.show_interstitial()

# ---------------------------------------------------------------------------
# Configuration — replace with real IDs before publishing.
# ---------------------------------------------------------------------------
const APP_ID            := "ca-app-pub-3940256099942544~3347511713"
const INTERSTITIAL_ID   := "ca-app-pub-3940256099942544/1033173712"
const TEST_MODE         := true   # set false for production

# ---------------------------------------------------------------------------
# Signals forwarded from the native plugin
# ---------------------------------------------------------------------------
signal initialized
signal interstitial_loaded
signal interstitial_closed
signal interstitial_failed_to_load
signal interstitial_show_failed

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------
var _plugin: Object = null
var _is_android: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_is_android = OS.get_name() == "Android"
	if not _is_android:
		push_warning("AdManager: not running on Android — ads are disabled.")
		return

	# Try multiple plugin singleton names for flexibility.
	for name in ["AdMobPlugin", "AdMob", "GodotAdMob"]:
		if Engine.has_singleton(name):
			_plugin = Engine.get_singleton(name)
			print("AdManager: found plugin singleton '%s'" % name)
			break

	if _plugin == null:
		push_error("AdManager: AdMob plugin singleton not found. Check AAR and plugin registration.")
		return

	# Connect native signals → local signals.
	_plugin.connect("initialized",                _on_initialized)
	_plugin.connect("interstitial_loaded",        _on_interstitial_loaded)
	_plugin.connect("interstitial_closed",        _on_interstitial_closed)
	_plugin.connect("interstitial_failed_to_load",_on_interstitial_failed_to_load)
	_plugin.connect("interstitial_show_failed",   _on_interstitial_show_failed)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Initialize the AdMob SDK. Call once at game start.
func initialize() -> void:
	if _plugin == null:
		return
	_plugin.initialize(APP_ID, TEST_MODE)

## Begin loading an interstitial ad. Listen for interstitial_loaded signal.
func load_interstitial() -> void:
	if _plugin == null:
		return
	_plugin.load_interstitial(INTERSTITIAL_ID)

## Show the interstitial if one is loaded. Returns true if shown.
func show_interstitial() -> bool:
	if _plugin == null:
		return false
	return _plugin.show_interstitial()

## Check whether an interstitial is ready to show.
func is_interstitial_loaded() -> bool:
	if _plugin == null:
		return false
	return _plugin.is_interstitial_loaded()

# ---------------------------------------------------------------------------
# Private signal handlers
# ---------------------------------------------------------------------------
func _on_initialized() -> void:
	print("AdManager: SDK initialized.")
	emit_signal("initialized")

func _on_interstitial_loaded() -> void:
	print("AdManager: interstitial loaded.")
	emit_signal("interstitial_loaded")

func _on_interstitial_closed() -> void:
	print("AdManager: interstitial closed.")
	emit_signal("interstitial_closed")
	# Auto-load next ad for seamless flow.
	load_interstitial()

func _on_interstitial_failed_to_load() -> void:
	push_warning("AdManager: interstitial failed to load.")
	emit_signal("interstitial_failed_to_load")

func _on_interstitial_show_failed() -> void:
	push_warning("AdManager: interstitial failed to show.")
	emit_signal("interstitial_show_failed")
