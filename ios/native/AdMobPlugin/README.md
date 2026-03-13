# Native iOS Scaffold

This directory contains the native iOS source scaffold for the Godot AdMob plugin.

Current scope:

- Godot singleton registration as `AdMobPlugin`
- `initialize(appId, testMode)` and legacy `init(appId)`
- interstitial load/show/state
- rewarded load/show/state
- ATT helpers:
  - `request_tracking_authorization()`
  - `get_tracking_authorization_status()`
- UMP helpers:
  - `request_consent_info_update()`
  - `can_request_ads()`
  - `is_consent_form_available()`
  - `show_consent_form_if_required()`
  - `get_consent_status()`
  - `get_privacy_options_requirement_status()`
- snake_case and camelCase wrappers

Expected external dependencies:

- Godot iOS template headers and C++ sources available locally
- Google Mobile Ads iOS SDK as `GoogleMobileAds.xcframework`

This scaffold does not vendor those dependencies into the repository.

## Layout

- `src/admob_plugin.h`
- `src/admob_plugin.mm`
- `src/admob_plugin_bootstrap.h`
- `src/admob_plugin_bootstrap.mm`
- `scripts/build_xcframework.sh`

## Build expectations

`build_xcframework.sh` expects:

- `GODOT_HEADERS_DIR`
  - directory containing Godot iOS headers such as `core/config/engine.h`
- `GOOGLE_MOBILE_ADS_XCFRAMEWORK`
  - path to `GoogleMobileAds.xcframework`
- `USER_MESSAGING_PLATFORM_XCFRAMEWORK`
  - path to `UserMessagingPlatform.xcframework`

Example:

```bash
export GODOT_HEADERS_DIR="$HOME/dev/godot-ios-headers"
export GOOGLE_MOBILE_ADS_XCFRAMEWORK="$HOME/Downloads/GoogleMobileAds.xcframework"
export USER_MESSAGING_PLATFORM_XCFRAMEWORK="$HOME/Downloads/UserMessagingPlatform.xcframework"
./ios/native/AdMobPlugin/scripts/build_xcframework.sh
```

The script outputs:

- `ios/plugins/admob_plugin/AdMobPlugin.debug.xcframework`
- `ios/plugins/admob_plugin/AdMobPlugin.release.xcframework`

Important:

- the script now builds true debug and true release xcframeworks separately
- release builds must compile without `DEBUG_ENABLED`, otherwise Godot method binding will target the wrong ABI for `libgodot.ios.release.xcframework`

You still need to place `GoogleMobileAds.xcframework` inside `ios/plugins/admob_plugin/` for Godot export packaging.
