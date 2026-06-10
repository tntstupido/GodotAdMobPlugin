# Changelog

## v1.3.7 - 2026-06-10

### Fixed
- Fixed iOS rewarded-ad freeze where `adDidDismissFullScreenContent` could
  fail to fire after the reward credit, leaving the Godot UI stalled until
  the app was backgrounded and re-foregrounded.
  - Root cause: the rewarded ad was being presented against a view controller
    that was not the topmost presenter at the moment of the SDK's dismiss
    transition (typical Godot iOS case where a system overlay — ATT, AVPlayer
    pre-roll, etc. — disrupts the key-window chain). The AdMob SDK then
    blocked waiting for a dismiss callback that iOS would only deliver after
    a scene re-resolve.
  - Fix 1: introduced `TopMostPresentedViewController()` helper that walks
    the presented-VC chain of the key window and is re-resolved on the main
    queue at the moment of present.
  - Fix 2: wrapped `adDidDismissFullScreenContent` (and the
    `userDidEarnRewardHandler` callback) in `dispatch_async(main, ...)` so
    Godot signal emission always happens on the script VM thread — defends
    against mediation adapters that deliver from a background queue.
  - Fix 3: added a 60s close watchdog timer armed at show time that force-
    fires `notify_rewarded_closed` if the SDK dismiss never lands, converting
    the worst-case full freeze into a clean "ad auto-dismissed" recovery.

## v1.3.6 - 2026-05-15

### Added
- Added reusable iOS under-age consent request configuration API to native plugin:
  - `set_tag_for_under_age_of_consent(enabled)` / `setTagForUnderAgeOfConsent(enabled)`
  - Applies both Google Mobile Ads request-configuration flags:
    - `tagForUnderAgeOfConsent`
    - `tagForChildDirectedTreatment`
- Added matching wrapper method in `godot/autoload/AdManager.gd`:
  - `set_tag_for_under_age_of_consent(enabled: bool)`

### Documentation
- Updated README status + API tables to include the new under-age consent tagging helper and behavior.

## v1.3.5 - 2026-05-10

### Documentation
- Expanded iOS source-plugin handoff documentation for later Mac setup:
  - added readiness snapshot with explicit `ready` vs `pending` scope
  - added Mac preflight/setup checklist for consuming projects
  - documented post-export patch helper scope (`dielaughing.xcodeproj` expectation)
- Updated README iOS status/quick-start sections to use repository-relative paths and include the same handoff-ready checklist.

## v1.3.4 - 2026-03-28

### Added
- Added Android impression-level ad revenue (ILR) paid-event support:
  - native plugin now emits `paid_event` with payload:
    - `ad_type`
    - `ad_unit_id`
    - `value_micros`
    - `currency_code`
    - `precision_type`
  - wired `OnPaidEventListener` for both interstitial and rewarded ads.
- Added Godot autoload bridge signal in plugin payload:
  - `paid_event(ad_type, ad_unit_id, value_micros, currency_code, precision_type)`

### Changed
- Updated Godot addon export-plugin default/fallback IDs to project production Android IDs so export-time manifest metadata does not fall back to Google test App ID.

## v1.3.3 - 2026-03-19

### Added
- Added Android UMP debug/testing API surface in native plugin (`AdMobPlugin.kt`):
  - debug geography setter (`set_ump_debug_geography` / `setUmpDebugGeography`)
  - consent state reset (`reset_ump_consent_state` / `resetUmpConsentState`)
  - UMP consent update/status/form/privacy-options helper methods and related signals.
- Added Android UMP dependency to Gradle module:
  - `com.google.android.ump:user-messaging-platform:3.1.0`

### Documentation
- Added README section documenting Android UMP test helper methods.
- Added explicit README guidance that debug-forcing controls are testing-only and should be gated by host-app debug build policy.

## v1.3.2 - 2026-03-13

### Fixed
- Fixed the iOS release xcframework packaging workflow:
  - the native build script had been compiling with `-DDEBUG_ENABLED` for both debug and release outputs
  - the script then copied the debug-built xcframework to the `AdMobPlugin.release.xcframework` name, producing a fake release payload
  - this caused Xcode archive linker failures once the consuming project linked against `libgodot.ios.release.xcframework`
- Fixed iOS native method-binding ABI compatibility for the shipped Godot iOS release exporter:
  - adjusted native method registration so rebuilt release payloads now reference `ClassDB::bind_methodfi(..., const char *, ...)`

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
