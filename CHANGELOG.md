# Changelog

## v1.1.0 - 2026-02-15

### Fixed
- Fixed Android runtime plugin registration by injecting:
  - `org.godotengine.plugin.v2.AdMobPlugin` -> `com.yourcompany.admobplugin.AdMobPlugin`
- Fixed export script app-id lookup to use `ProjectSettings["admob/app_id"]` fallback-safe path.
- Fixed native method compatibility issues between Godot wrappers and plugin API.

### Added
- Added compatibility wrappers in Kotlin plugin class:
  - `init(appId)`
  - `loadInterstitial(adUnitId)`
  - `showInterstitial()`
  - `isInterstitialLoaded()`
- Added autoload compatibility in `godot/autoload/AdManager.gd` for both snake_case and camelCase APIs.

### Updated
- Rebuilt and updated distributed AAR artifacts:
  - `godot/addons/admob_plugin/AdMobPlugin-debug.aar`
  - `godot/addons/admob_plugin/AdMobPlugin-release.aar`

## v1.0.0 - 2026-02-15

- Initial public release.
