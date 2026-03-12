# iOS Plugin Payload

Place the built iOS plugin payload for Godot in this directory.

Required files for a usable iOS export:

- `AdMobPlugin.debug.xcframework`
- `AdMobPlugin.release.xcframework`
- `GoogleMobileAds.xcframework`
- `UserMessagingPlatform.xcframework`
- `admob_plugin.gdip`

Godot detects the plugin by scanning `res://ios/plugins/**.gdip`.

The included [admob_plugin.gdip](/Users/mladen/Documents/Plugins/GodotAdMobPlugin/ios/plugins/admob_plugin/admob_plugin.gdip) is configured for:

- singleton name: `AdMobPlugin`
- plugin binary basename: `AdMobPlugin.xcframework`
- `use_swift_runtime=true` so Godot exports add the Swift runtime scaffold (`dummy.swift`) automatically
- Info.plist keys:
  - `GADApplicationIdentifier`
  - `NSUserTrackingUsageDescription`
- required system frameworks:
  - `AdSupport.framework`
  - `AppTrackingTransparency.framework`
  - `Foundation.framework`
  - `JavaScriptCore.framework`
  - `StoreKit.framework`
  - `UIKit.framework`

## UMP Behavior

- The iOS payload now embeds `UserMessagingPlatform.xcframework` alongside `GoogleMobileAds.xcframework`.
- The native plugin now exposes UMP consent helpers for the consuming game:
  - `request_consent_info_update()`
  - `can_request_ads()`
  - `is_consent_form_available()`
  - `show_consent_form_if_required()`
  - `get_consent_status()`
  - `get_privacy_options_requirement_status()`
- Intended integration order:
  - UMP first
  - ATT second, if still needed

## ATT Behavior

- iOS ad loads no longer auto-request ATT.
- The native plugin updates tracking status when loading ads, but ATT is only shown when the consuming game explicitly calls:
  - `request_tracking_authorization()`
- This keeps early ad requests decoupled from the ATT prompt so a game can:
  - load/show non-IDFA ads before asking ATT
  - choose a calmer in-game moment for the prompt

## Rebuild Note

The native `AdMobPlugin.xcframework` must be rebuilt against the exact Godot iOS/export-template version used by the consuming project.

If the plugin is built against a different Godot version, Xcode archive can fail with unresolved Godot symbols such as `ClassDB::bind_methodfi(...)`.

If you need simulator support, provide `.xcframework` builds that include both device and simulator slices.

Native source scaffold lives in [ios/native/AdMobPlugin](/Users/mladen/Documents/Plugins/GodotAdMobPlugin/ios/native/AdMobPlugin).
