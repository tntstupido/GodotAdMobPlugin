@tool
extends EditorPlugin

const PLUGIN_NAME := "AdMobPlugin"
const ADMOB_TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"

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
		return platform is EditorExportPlatformAndroid

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
		var app_id := ADMOB_TEST_APP_ID
		if ProjectSettings.has_setting("admob/app_id"):
			var configured := str(ProjectSettings.get_setting("admob/app_id"))
			if configured.strip_edges() != "":
				app_id = configured
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
					"name": "admob/app_id",
					"type": TYPE_STRING,
				},
				"default_value": ADMOB_TEST_APP_ID,
			}
		]
