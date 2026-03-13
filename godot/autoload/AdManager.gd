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
signal consent_info_updated
signal consent_form_shown
signal consent_form_dismissed
signal consent_flow_finished
signal consent_error(message: String)
signal privacy_options_form_shown
signal privacy_options_form_dismissed
signal privacy_options_form_finished

const LEGACY_APP_ID_SETTING := "admob/app_id"
const ANDROID_APP_ID_SETTING := "admob/android/app_id"
const IOS_APP_ID_SETTING := "admob/ios/app_id"
const ANDROID_INTERSTITIAL_ID_SETTING := "admob/android/interstitial_id"
const IOS_INTERSTITIAL_ID_SETTING := "admob/ios/interstitial_id"
const ANDROID_REWARDED_ID_SETTING := "admob/android/rewarded_id"
const IOS_REWARDED_ID_SETTING := "admob/ios/rewarded_id"

const APP_ID := "ca-app-pub-3940256099942544~3347511713"
const INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"
const REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"
const TEST_MODE := true

const SINGLETON_CANDIDATES := ["AdMobPlugin", "admobplugin", "AdMob", "GodotAdMob"]

var _plugin: Object = null

func _ready() -> void:
	if not _is_supported_platform():
		push_warning("AdManager: supported platforms are Android and iOS. Current platform: %s." % OS.get_name())
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
	_try_connect("consent_info_updated", _on_consent_info_updated)
	_try_connect("consent_form_shown", _on_consent_form_shown)
	_try_connect("consent_form_dismissed", _on_consent_form_dismissed)
	_try_connect("consent_flow_finished", _on_consent_flow_finished)
	_try_connect("consent_error", _on_consent_error)
	_try_connect("privacy_options_form_shown", _on_privacy_options_form_shown)
	_try_connect("privacy_options_form_dismissed", _on_privacy_options_form_dismissed)
	_try_connect("privacy_options_form_finished", _on_privacy_options_form_finished)

func initialize() -> void:
	if _plugin == null:
		return
	var app_id := _get_configured_value(_get_platform_app_id_setting(), LEGACY_APP_ID_SETTING, APP_ID)
	if _plugin.has_method("initialize"):
		_plugin.call("initialize", app_id, TEST_MODE)
		return
	if _plugin.has_method("init"):
		_plugin.call("init", app_id)

func load_interstitial() -> void:
	if _plugin == null:
		return
	var ad_unit_id := _get_configured_value(_get_platform_interstitial_setting(), "", INTERSTITIAL_ID)
	if _plugin.has_method("load_interstitial"):
		_plugin.call("load_interstitial", ad_unit_id)
		return
	if _plugin.has_method("loadInterstitial"):
		_plugin.call("loadInterstitial", ad_unit_id)

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
	var ad_unit_id := _get_configured_value(_get_platform_rewarded_setting(), "", REWARDED_ID)
	if _plugin.has_method("load_rewarded"):
		_plugin.call("load_rewarded", ad_unit_id)
		return
	if _plugin.has_method("loadRewarded"):
		_plugin.call("loadRewarded", ad_unit_id)

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

func request_tracking_authorization() -> void:
	if _plugin == null:
		return
	if _plugin.has_method("request_tracking_authorization"):
		_plugin.call("request_tracking_authorization")
		return
	if _plugin.has_method("requestTrackingAuthorization"):
		_plugin.call("requestTrackingAuthorization")

func get_tracking_authorization_status() -> int:
	if _plugin == null:
		return -1
	if _plugin.has_method("get_tracking_authorization_status"):
		return int(_plugin.call("get_tracking_authorization_status"))
	if _plugin.has_method("getTrackingAuthorizationStatus"):
		return int(_plugin.call("getTrackingAuthorizationStatus"))
	return -1

func request_consent_info_update() -> void:
	if _plugin == null:
		return
	if _plugin.has_method("request_consent_info_update"):
		_plugin.call("request_consent_info_update")
		return
	if _plugin.has_method("requestConsentInfoUpdate"):
		_plugin.call("requestConsentInfoUpdate")

func can_request_ads() -> bool:
	if _plugin == null:
		return false
	if _plugin.has_method("can_request_ads"):
		return bool(_plugin.call("can_request_ads"))
	if _plugin.has_method("canRequestAds"):
		return bool(_plugin.call("canRequestAds"))
	return false

func is_consent_form_available() -> bool:
	if _plugin == null:
		return false
	if _plugin.has_method("is_consent_form_available"):
		return bool(_plugin.call("is_consent_form_available"))
	if _plugin.has_method("isConsentFormAvailable"):
		return bool(_plugin.call("isConsentFormAvailable"))
	return false

func show_consent_form_if_required() -> void:
	if _plugin == null:
		return
	if _plugin.has_method("show_consent_form_if_required"):
		_plugin.call("show_consent_form_if_required")
		return
	if _plugin.has_method("showConsentFormIfRequired"):
		_plugin.call("showConsentFormIfRequired")

func get_consent_status() -> int:
	if _plugin == null:
		return 0
	if _plugin.has_method("get_consent_status"):
		return int(_plugin.call("get_consent_status"))
	if _plugin.has_method("getConsentStatus"):
		return int(_plugin.call("getConsentStatus"))
	return 0

func get_privacy_options_requirement_status() -> int:
	if _plugin == null:
		return 0
	if _plugin.has_method("get_privacy_options_requirement_status"):
		return int(_plugin.call("get_privacy_options_requirement_status"))
	if _plugin.has_method("getPrivacyOptionsRequirementStatus"):
		return int(_plugin.call("getPrivacyOptionsRequirementStatus"))
	return 0

func is_privacy_options_form_available() -> bool:
	if _plugin == null:
		return false
	if _plugin.has_method("is_privacy_options_form_available"):
		return bool(_plugin.call("is_privacy_options_form_available"))
	if _plugin.has_method("isPrivacyOptionsFormAvailable"):
		return bool(_plugin.call("isPrivacyOptionsFormAvailable"))
	return false

func show_privacy_options_form() -> void:
	if _plugin == null:
		return
	if _plugin.has_method("show_privacy_options_form"):
		_plugin.call("show_privacy_options_form")
		return
	if _plugin.has_method("showPrivacyOptionsForm"):
		_plugin.call("showPrivacyOptionsForm")

func _try_connect(signal_name: String, callback: Callable) -> void:
	if _plugin == null:
		return
	if not _plugin.has_signal(signal_name):
		return
	if _plugin.is_connected(signal_name, callback):
		return
	_plugin.connect(signal_name, callback)

func _is_supported_platform() -> bool:
	return OS.get_name() == "Android" or OS.get_name() == "iOS"

func _get_platform_app_id_setting() -> String:
	if OS.get_name() == "iOS":
		return IOS_APP_ID_SETTING
	return ANDROID_APP_ID_SETTING

func _get_platform_interstitial_setting() -> String:
	if OS.get_name() == "iOS":
		return IOS_INTERSTITIAL_ID_SETTING
	return ANDROID_INTERSTITIAL_ID_SETTING

func _get_platform_rewarded_setting() -> String:
	if OS.get_name() == "iOS":
		return IOS_REWARDED_ID_SETTING
	return ANDROID_REWARDED_ID_SETTING

func _get_configured_value(primary_setting: String, fallback_setting: String, default_value: String) -> String:
	var primary_value := _read_setting(primary_setting)
	if primary_value != "":
		return primary_value
	if fallback_setting != "":
		var fallback_value := _read_setting(fallback_setting)
		if fallback_value != "":
			return fallback_value
	return default_value

func _read_setting(setting_name: String) -> String:
	if not ProjectSettings.has_setting(setting_name):
		return ""
	var value := str(ProjectSettings.get_setting(setting_name))
	return value.strip_edges()

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

func _on_consent_info_updated() -> void:
	emit_signal("consent_info_updated")

func _on_consent_form_shown() -> void:
	emit_signal("consent_form_shown")

func _on_consent_form_dismissed() -> void:
	emit_signal("consent_form_dismissed")

func _on_consent_flow_finished() -> void:
	emit_signal("consent_flow_finished")

func _on_consent_error(message: String = "") -> void:
	emit_signal("consent_error", message)

func _on_privacy_options_form_shown() -> void:
	emit_signal("privacy_options_form_shown")

func _on_privacy_options_form_dismissed() -> void:
	emit_signal("privacy_options_form_dismissed")

func _on_privacy_options_form_finished() -> void:
	emit_signal("privacy_options_form_finished")
