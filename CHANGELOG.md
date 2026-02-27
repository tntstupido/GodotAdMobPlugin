# Changelog

## v1.2.0 - 2026-02-27

### Added
- Added rewarded ad support in the Android plugin (`AdMobPlugin.kt`):
  - New load/show APIs:
    - `load_rewarded(adUnitId)`
    - `show_rewarded()`
    - `is_rewarded_loaded()`
  - CamelCase compatibility wrappers:
    - `loadRewarded(adUnitId)`
    - `showRewarded()`
    - `isRewardedLoaded()`
  - New rewarded signals:
    - `rewarded_loaded`
    - `rewarded_closed`
    - `rewarded_earned`
    - `rewarded_failed_to_load`
    - `rewarded_show_failed`

### Changed
- Replaced the unused `isInitialized` field with rewarded ad state tracking (`rewardedAd`).
- Standardized local activity handling to `currentActivity` in initialization and interstitial flows for consistency.

### Packaging
- Added an untracked distribution archive in the repository root:
  - `AdMobPlugin-v1.1.0-addons.zip`

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
