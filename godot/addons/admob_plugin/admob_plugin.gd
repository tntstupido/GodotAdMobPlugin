@tool
extends EditorPlugin

# AdMob test App ID — replace with your real one for production.
const ADMOB_APP_ID = "ca-app-pub-3940256099942544~3347511713"

var export_plugin: AdMobExportPlugin

func _enter_tree() -> void:
	export_plugin = AdMobExportPlugin.new()
	add_export_plugin(export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null


# ---------------------------------------------------------------------------
# Export plugin
# ---------------------------------------------------------------------------
class AdMobExportPlugin extends EditorExportPlugin:

	func _get_name() -> String:
		return "AdMobPlugin"

	# AAR libraries bundled with this addon.
	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray([
				"res://addons/admob_plugin/AdMobPlugin-debug.aar"
			])
		else:
			return PackedStringArray([
				"res://addons/admob_plugin/AdMobPlugin-release.aar"
			])

	# Remote Maven dependencies resolved during Godot's Gradle build.
	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"com.google.android.gms:play-services-ads:24.1.0"
		])

	# Extra Maven repositories needed to resolve dependencies.
	func _get_android_maven_repos(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"https://maven.google.com"
		])

	# Inject AdMob Application ID into AndroidManifest.xml <application> block.
	func _get_android_manifest_application_element_contents(
			platform: EditorExportPlatform, debug: bool) -> String:
		# Read app id from export options if provided, otherwise fall back to test id.
		var app_id: String = _get_option("admob/app_id", "ca-app-pub-3940256099942544~3347511713")
		return (
			'\t\t<meta-data\n'
			+ '\t\t\tandroid:name="com.google.android.gms.ads.APPLICATION_ID"\n'
			+ '\t\t\tandroid:value="' + app_id + '" />\n'
		)

	func _get_android_permissions(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"android.permission.INTERNET",
			"android.permission.ACCESS_NETWORK_STATE"
		])

	# Helper to read export options (defined in _get_export_options).
	func _get_option(key: String, default_value: Variant) -> Variant:
		var opts = get_export_options(null)
		if opts == null:
			return default_value
		return opts.get(key, default_value)

	func _get_export_options(platform: EditorExportPlatform) -> Array[Dictionary]:
		return [
			{
				"option": {
					"name": "admob/app_id",
					"type": TYPE_STRING,
				},
				"default_value": "ca-app-pub-3940256099942544~3347511713",
			}
		]
