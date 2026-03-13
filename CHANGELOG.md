# Changelog

## v1.3.1 - 2026-03-12

### Fixed
- Fixed the iOS UMP privacy-options settings flow:
  - removed an overly strict native preflight check that could block `show_privacy_options_form()` even when UMP had already reported `privacy_options_requirement_status=required`
  - the plugin now lets the native UMP SDK own final privacy-options presentation/error handling

### Documentation
- Updated README status to reflect current iOS payload reality:
  - `AdMobPlugin` debug/release xcframeworks included
  - `GoogleMobileAds.xcframework` and `UserMessagingPlatform.xcframework` included
- Expanded README API reference with current iOS UMP methods and consent signals.
- Added documentation for the dedicated iOS UMP privacy-options API used by settings-driven consent review.
- Added explicit scope-boundary note:
  - iOS IAP (StoreKit) and iOS Game Center integrations are separate plugin/workstream responsibilities outside this AdMob plugin.

## v1.3.0 - 2026-03-12

### Added
- Added platform-specific ProjectSettings defaults in the Godot export plugin:
  - `admob/android/app_id`
  - `admob/android/interstitial_id`
  - `admob/android/rewarded_id`
  - `admob/ios/app_id`
  - `admob/ios/interstitial_id`
  - `admob/ios/rewarded_id`
  - `admob/ios/att_message`
- Added iOS-oriented helper methods to `AdManager.gd`:
  - `request_tracking_authorization()`
  - `get_tracking_authorization_status()`
- Added Godot iOS plugin distribution scaffolding:
  - `ios/plugins/admob_plugin/admob_plugin.gdip`
  - `ios/plugins/admob_plugin/README.md`
  - `scripts/package_release.sh`
- Added native iOS source scaffolding for the AdMob plugin:
  - `ios/native/AdMobPlugin/src/admob_plugin.h`
  - `ios/native/AdMobPlugin/src/admob_plugin.mm`
  - `ios/native/AdMobPlugin/src/admob_plugin_bootstrap.h`
  - `ios/native/AdMobPlugin/src/admob_plugin_bootstrap.mm`
  - `ios/native/AdMobPlugin/scripts/build_xcframework.sh`
  - `ios/native/AdMobPlugin/README.md`

### Changed
- Updated `AdManager.gd` to resolve app/ad unit IDs by active platform while preserving legacy fallback for `admob/app_id`.
- Expanded the Godot addon metadata to describe Android + iOS-facing support at the API/config layer.
- Updated README to document the new iOS plugin folder layout, release packaging flow, and remaining native xcframework gap.

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
