# Add iOS Support to Godot AdMob Plugin (v1.3.0)

## Summary
Add first-class iOS support with interstitial + rewarded parity, keep the current GDScript-facing API stable, and ship a turnkey release artifact (no manual Xcode edits after Godot export).

## Implementation Changes
- Build a native iOS AdMob plugin that registers the same singleton name (`AdMobPlugin`) and exposes the same method/signal surface as Android, including snake_case + camelCase compatibility wrappers.
- Add iOS native implementation for:
  - `initialize(appId, testMode)`
  - interstitial load/show/state
  - rewarded load/show/state
  - emitted signals identical to Android (`initialized`, `*_loaded`, `*_closed`, `*_failed_*`, `rewarded_earned`)
- Add ATT support (no UMP in this release):
  - request tracking authorization before first ad request on iOS
  - expose tracking status helper API for diagnostics
- Extend addon/export integration:
  - keep Android flow unchanged
  - add iOS plugin metadata/artifacts so Godot iOS export includes required AdMob binaries automatically
  - inject required Info.plist keys for AdMob app ID and ATT message
- Move ad ID configuration to platform-specific ProjectSettings defaults, while preserving backward compatibility fallback to current keys/constants.
- Update docs and release packaging to include both Android (`.aar`) and iOS artifacts in one addon release zip.

## Public API / Interface Changes
- Keep existing `AdManager` methods/signals behavior unchanged for current users.
- Add optional iOS-focused helpers in `AdManager`:
  - `request_tracking_authorization()`
  - `get_tracking_authorization_status() -> int`
- Add ProjectSettings keys:
  - `admob/android/app_id`, `admob/android/interstitial_id`, `admob/android/rewarded_id`
  - `admob/ios/app_id`, `admob/ios/interstitial_id`, `admob/ios/rewarded_id`, `admob/ios/att_message`
- Keep legacy fallback so existing projects using current constants/settings still run.

## Test Plan
- Android regression:
  - initialize, load/show interstitial, load/show rewarded, signal emission unchanged.
- iOS functional:
  - export succeeds with plugin enabled and no manual Xcode dependency edits.
  - initialize, interstitial flow, rewarded flow, and signal parity.
  - ATT prompt appears as expected and status is reported correctly.
- Compatibility:
  - existing GDScript calls continue to work without code changes.
  - both snake_case and camelCase method aliases work on iOS singleton.

## Assumptions and Defaults
- Target baseline: Godot 4.5.1, iOS minimum 13.0.
- Scope for this update: interstitial + rewarded only (no banner/app-open yet).
- Privacy scope: ATT only in this release; UMP deferred.
- Delivery model: prebuilt, turnkey iOS binaries committed as part of plugin release artifacts.
- Primary touchpoints:
  - `godot/addons/admob_plugin/admob_plugin.gd`
  - `godot/autoload/AdManager.gd`
  - `README.md`
