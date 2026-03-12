@tool
extends EditorPlugin

const PLUGIN_NAME := "AdMobPlugin"
const ADMOB_TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const ADMOB_TEST_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"
const ADMOB_TEST_REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"
const DEFAULT_ATT_MESSAGE := "This identifier will be used to deliver more relevant ads to you."

const LEGACY_APP_ID_SETTING := "admob/app_id"
const ANDROID_APP_ID_SETTING := "admob/android/app_id"
const ANDROID_INTERSTITIAL_ID_SETTING := "admob/android/interstitial_id"
const ANDROID_REWARDED_ID_SETTING := "admob/android/rewarded_id"
const IOS_APP_ID_SETTING := "admob/ios/app_id"
const IOS_INTERSTITIAL_ID_SETTING := "admob/ios/interstitial_id"
const IOS_REWARDED_ID_SETTING := "admob/ios/rewarded_id"
const IOS_ATT_MESSAGE_SETTING := "admob/ios/att_message"

var export_plugin: AdMobExportPlugin

func _enter_tree() -> void:
	export_plugin = AdMobExportPlugin.new()
	add_export_plugin(export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null


class AdMobExportPlugin extends EditorExportPlugin:
	func _get_name() -> String:
		return PLUGIN_NAME

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid or _is_ios_platform(platform)

	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray(["res://addons/admob_plugin/AdMobPlugin-debug.aar"])
		return PackedStringArray(["res://addons/admob_plugin/AdMobPlugin-release.aar"])

	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"com.google.android.gms:play-services-ads:24.1.0"
		])

	func _get_android_maven_repos(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"https://dl.google.com/dl/android/maven2/"
		])

	func _get_android_manifest_application_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
		var app_id := _get_setting_with_fallback(ANDROID_APP_ID_SETTING, LEGACY_APP_ID_SETTING, ADMOB_TEST_APP_ID)
		return (
			'\t\t<meta-data\n'
			+ '\t\t\tandroid:name="com.google.android.gms.ads.APPLICATION_ID"\n'
			+ '\t\t\tandroid:value="' + app_id + '" />\n'
			+ '\t\t<meta-data\n'
			+ '\t\t\tandroid:name="org.godotengine.plugin.v2.AdMobPlugin"\n'
			+ '\t\t\tandroid:value="com.yourcompany.admobplugin.AdMobPlugin" />\n'
		)

	func _get_android_permissions(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"android.permission.INTERNET",
			"android.permission.ACCESS_NETWORK_STATE"
		])

	func _get_export_options(platform: EditorExportPlatform) -> Array[Dictionary]:
		return [
			{
				"option": {
					"name": LEGACY_APP_ID_SETTING,
					"type": TYPE_STRING,
				},
				"default_value": ADMOB_TEST_APP_ID,
			},
			{
				"option": {
					"name": ANDROID_APP_ID_SETTING,
					"type": TYPE_STRING,
				},
				"default_value": ADMOB_TEST_APP_ID,
			},
			{
				"option": {
					"name": ANDROID_INTERSTITIAL_ID_SETTING,
					"type": TYPE_STRING,
				},
				"default_value": ADMOB_TEST_INTERSTITIAL_ID,
			},
			{
				"option": {
					"name": ANDROID_REWARDED_ID_SETTING,
					"type": TYPE_STRING,
				},
				"default_value": ADMOB_TEST_REWARDED_ID,
			},
			{
				"option": {
					"name": IOS_APP_ID_SETTING,
					"type": TYPE_STRING,
				},
				"default_value": ADMOB_TEST_APP_ID,
			},
			{
				"option": {
					"name": IOS_INTERSTITIAL_ID_SETTING,
					"type": TYPE_STRING,
				},
				"default_value": ADMOB_TEST_INTERSTITIAL_ID,
			},
			{
				"option": {
					"name": IOS_REWARDED_ID_SETTING,
					"type": TYPE_STRING,
				},
				"default_value": ADMOB_TEST_REWARDED_ID,
			},
			{
				"option": {
					"name": IOS_ATT_MESSAGE_SETTING,
					"type": TYPE_STRING,
				},
				"default_value": DEFAULT_ATT_MESSAGE,
			}
		]

	func _is_ios_platform(platform: EditorExportPlatform) -> bool:
		return platform.get_class().contains("iOS")

	func _get_setting_with_fallback(primary_setting: String, fallback_setting: String, default_value: String) -> String:
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
		var configured := str(ProjectSettings.get_setting(setting_name))
		return configured.strip_edges()
