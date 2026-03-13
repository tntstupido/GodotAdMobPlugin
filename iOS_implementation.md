# iOS Support Status and Next Steps (v1.3.0)

## Goal

Ship Godot iOS support for this AdMob plugin with:

- singleton name `AdMobPlugin`
- GDScript API parity with Android for interstitial and rewarded ads
- ATT helper support
- iOS export payload included in the addon release

This document is now a handoff/status file, not just a proposal.

## What Is Already Done In This Repository

### 1. Godot-facing API and configuration

Completed:

- `godot/autoload/AdManager.gd`
  - supports Android and iOS
  - keeps existing interstitial/rewarded API unchanged
  - resolves IDs from platform-specific `ProjectSettings`
  - preserves legacy fallback for `admob/app_id`
  - adds:
    - `request_tracking_authorization()`
    - `get_tracking_authorization_status() -> int`

- `godot/addons/admob_plugin/admob_plugin.gd`
  - still supports Android export
  - defines export settings for:
    - `admob/android/app_id`
    - `admob/android/interstitial_id`
    - `admob/android/rewarded_id`
    - `admob/ios/app_id`
    - `admob/ios/interstitial_id`
    - `admob/ios/rewarded_id`
    - `admob/ios/att_message`

- `godot/addons/admob_plugin/plugin.cfg`
  - updated for v1.3.0

### 2. iOS plugin payload

Completed:

- `ios/plugins/admob_plugin/admob_plugin.gdip`
- `ios/plugins/admob_plugin/AdMobPlugin.debug.xcframework`
- `ios/plugins/admob_plugin/AdMobPlugin.release.xcframework`
- `ios/plugins/admob_plugin/GoogleMobileAds.xcframework`
- `ios/plugins/admob_plugin/UserMessagingPlatform.xcframework`

The iOS payload is already present in this repo and is included in:

- `AdMobPlugin-v1.3.0-addons.zip`

### 3. Native iOS source scaffold

Completed:

- `ios/native/AdMobPlugin/src/admob_plugin.h`
- `ios/native/AdMobPlugin/src/admob_plugin.mm`
- `ios/native/AdMobPlugin/src/admob_plugin_bootstrap.h`
- `ios/native/AdMobPlugin/src/admob_plugin_bootstrap.mm`
- `ios/native/AdMobPlugin/scripts/build_xcframework.sh`

Current native scope:

- `initialize(appId, testMode)` and legacy `init(appId)`
- interstitial load/show/is_loaded
- rewarded load/show/is_loaded
- ATT:
  - `request_tracking_authorization()`
  - `get_tracking_authorization_status()`
  - ATT prompt is manual only; ad loads do not auto-trigger it
- UMP:
  - `request_consent_info_update()`
  - `can_request_ads()`
  - `is_consent_form_available()`
  - `show_consent_form_if_required()`
  - `get_consent_status()`
  - `get_privacy_options_requirement_status()`
  - `is_privacy_options_form_available()`
  - `show_privacy_options_form()`
- snake_case and camelCase wrappers
- same emitted signal names as Android:
  - `initialized`
  - `interstitial_loaded`
  - `interstitial_closed`
  - `interstitial_failed_to_load`
  - `interstitial_show_failed`
  - `rewarded_loaded`
  - `rewarded_closed`
  - `rewarded_earned`
  - `rewarded_failed_to_load`
  - `rewarded_show_failed`

### 4. Build verification already done

Completed in this repo:

- downloaded official Godot `4.5.1-stable` source for headers/generation
- downloaded official Google Mobile Ads iOS SDK
- generated required Godot build-time headers needed by this native plugin build
- built:
  - `AdMobPlugin.debug.xcframework`
  - `AdMobPlugin.release.xcframework`
- copied `GoogleMobileAds.xcframework` into the plugin payload
- rebuilt the release zip

## What Is Not Verified Yet

These are still open:

- runtime validation inside an actual Godot project
- actual interstitial ad flow on iOS
- actual rewarded ad flow on iOS
- ATT prompt timing/behavior on device
- UMP consent flow timing/behavior on device
- whether the rebuilt plugin is link-compatible with the exact Godot iOS/export-template version used by the consuming project

## Integration Findings From Real Project Export

Observed while integrating this plugin into a consuming Godot project:

- Godot did recognize and export the iOS plugin once the consuming project enabled `plugins/AdMobPlugin=true` in the iOS export preset.
- The generated Xcode project linked:
  - `AdMobPlugin`
  - `GoogleMobileAds`
  - ATT/system frameworks
  - `-ObjC`

Current blockers found during real Xcode archive:

- `GoogleMobileAds` required `JavaScriptCore.framework`
  - fixed in this repository by adding `JavaScriptCore.framework` to `ios/plugins/admob_plugin/admob_plugin.gdip`
- `AdMobPlugin.xcframework` failed to link against the consuming project's Godot iOS export with unresolved Godot C++ symbols such as:
  - `ClassDB::bind_methodfi(...)`
- the generated Xcode target did not compile the existing `dummy.swift`, so Swift compatibility libraries required by `GoogleMobileAds` were not being linked/embedded

Interpretation:

- This is consistent with the plugin being built against a different Godot iOS ABI/export-template version than the one used by the consuming project.
- The next rebuild of `AdMobPlugin.xcframework` must use the exact Godot version/templates used by the target project export.
- the consuming project's generated Xcode target may also need Swift enabled (for example by compiling `dummy.swift`) so Swift compatibility libraries from `GoogleMobileAds` are linked.

## Current Verified State

After rebuilding `AdMobPlugin.xcframework` from this source repo against official Godot `4.5.1-stable` headers plus generated `.gen.h` files, and after fixing the generated Xcode target to compile `dummy.swift` and link `JavaScriptCore.framework`, the consuming project's iOS archive succeeded.

Runtime ad-flow validation is still pending.

## ATT Prompt Policy Adjustment

Updated in the source plugin after consuming-project review:

- native iOS ad loads no longer request ATT automatically
- `load_interstitial()` and `load_rewarded()` now load ads directly with `GADRequest`
- the plugin still exposes:
  - `request_tracking_authorization()`
  - `get_tracking_authorization_status()`
- intended consuming-project behavior is now:
  - early ads may load/show before ATT
  - ATT should be requested explicitly from game UX at a deliberate moment

Reason:

- auto-requesting ATT from the first ad preload could surface the ATT prompt at `Game Over` before the first rewarded ad, which is poor UX for the current game design
- this decoupling better matches the consuming project’s desired flow: rewarded ads can work before ATT, and ATT can be asked later from a calmer menu context

## UMP Integration Adjustment

Updated in the source plugin after consuming-project review:

- native iOS plugin now links and embeds `UserMessagingPlatform.xcframework`
- UMP consent helpers are exposed to GDScript so the consuming game can orchestrate:
  - consent info update
  - consent form presentation if required
  - ATT only after UMP has completed
- intended consuming-project order is now:
  - UMP first
  - ATT second
  - no consent prompts from `Game Over`

## Current Working Export Workflow

For a fresh Godot iOS export:

1. Rebuild/sync the plugin payload from this source repo when native/plugin metadata changes.
2. Export the iOS/Xcode project from Godot.
3. Run:

`python3 scripts/patch_ios_export_xcode_project.py <exported_ios_project_dir>`

Current purpose of that helper:

- enable Swift compilation by adding `dummy.swift` to the target
- enable Swift standard library embedding
- link `JavaScriptCore.framework`

The helper is idempotent and should be rerun after each fresh export until this step is handled directly by Godot/plugin metadata generation.

## Fresh Export Metadata Fix

This repository now sets:

- `use_swift_runtime=true` in `ios/plugins/admob_plugin/admob_plugin.gdip`

Godot `4.5.1` exporter code uses that flag to inject the Swift runtime scaffold (`dummy.swift`) and Swift build settings into the generated Xcode project.

Expected result for fresh exports:

- no manual `dummy.swift` target edit should be needed
- the helper script should only remain as fallback until a fresh export is revalidated end-to-end

## Next Step For The Agent Running From The Godot Project Folder

The next agent should work from the Godot game project that consumes this plugin, not from this plugin repo.

### 1. Install the plugin into the Godot project

Copy these into the project:

- `godot/addons/admob_plugin/` -> `<project>/addons/admob_plugin/`
- `godot/autoload/AdManager.gd` -> `<project>/autoload/AdManager.gd`
- `ios/plugins/` -> `<project>/ios/plugins/`

### 2. Enable the plugin in Godot

In the Godot project:

- enable `AdMobPlugin` under Project Settings -> Plugins
- add `res://autoload/AdManager.gd` as autoload `AdManager`

### 3. Configure ProjectSettings values

Set:

- `admob/ios/app_id`
- `admob/ios/interstitial_id`
- `admob/ios/rewarded_id`
- `admob/ios/att_message`

Recommended first pass:

- keep using Google test IDs until runtime works end-to-end

### 4. Create a minimal iOS test scene

The consuming Godot project should add a minimal scene/script that:

- calls `AdManager.initialize()`
- connects to:
  - `initialized`
  - `interstitial_loaded`
  - `interstitial_closed`
  - `interstitial_failed_to_load`
  - `interstitial_show_failed`
  - `rewarded_loaded`
  - `rewarded_closed`
  - `rewarded_earned`
  - `rewarded_failed_to_load`
  - `rewarded_show_failed`
- prints every signal to the console
- exercises:
  - `AdManager.request_tracking_authorization()`
  - `AdManager.get_tracking_authorization_status()`
  - `AdManager.load_interstitial()`
  - `AdManager.show_interstitial()`
  - `AdManager.load_rewarded()`
  - `AdManager.show_rewarded()`

### 5. Export and validate on iOS

The consuming project agent should:

- make an iOS export preset if missing
- export for iOS
- confirm the plugin is included in the generated Xcode project/export
- confirm the iOS export preset has `plugins/AdMobPlugin=true`
- build and run on:
  - simulator if supported by the export flow
  - physical iPhone if ATT/ad behavior needs validation

### 6. Fix project-side integration issues

The next agent should expect issues in one of these areas:

- Godot iOS plugin discovery/path layout
- plist key propagation
- linker flags / embedded frameworks
- singleton registration name mismatch
- Objective-C++/Godot runtime mismatch
- ATT behavior differences between simulator and device

If there are integration failures, the next agent should patch this plugin repo, then copy refreshed plugin files back into the Godot project and retry.

### Rebuild Rule

When rebuilding the iOS plugin:

- use the exact Godot iOS/export-template version used by the consuming project
- regenerate the xcframeworks
- copy refreshed payload files back into:
  - `godot/addons/admob_plugin/` when addon scripts changed
  - `godot/autoload/AdManager.gd` when wrapper API changed
  - `ios/plugins/admob_plugin/` for rebuilt iOS payload/framework metadata

## Recommended Acceptance Checklist

Consider the iOS implementation complete only when all of these are true in the real Godot project:

- `Engine.has_singleton("AdMobPlugin")` is true on iOS
- `AdManager.initialize()` emits `initialized`
- `request_consent_info_update()` / UMP callbacks run as expected for target regions
- `show_privacy_options_form()` works when a consuming game deliberately exposes that path and UMP reports privacy options are required
- the native privacy-options path should not add a separate stale preflight rejection before presentation; let the UMP SDK present the form or return the authoritative error
- `AdManager.request_tracking_authorization()` works without crash
- `AdManager.get_tracking_authorization_status()` returns expected values
- interstitial loads and shows
- rewarded loads and shows
- `rewarded_earned` fires correctly
- close/failure signals match Android naming
- no manual Xcode dependency edits are required after export

## Files Most Likely To Need Further Changes

- `godot/autoload/AdManager.gd`
- `godot/addons/admob_plugin/admob_plugin.gd`
- `ios/plugins/admob_plugin/admob_plugin.gdip`
- `ios/native/AdMobPlugin/src/admob_plugin.mm`
- `ios/native/AdMobPlugin/scripts/build_xcframework.sh`

## Scope Boundary (Non-Goals For This Plugin)

This plugin repository covers AdMob + ATT + UMP only.

The following are separate plugin/workstreams and should be planned in the consuming game project roadmap:

- iOS IAP plugin integration (StoreKit)
- iOS Game Center plugin integration

## Short Prompt For The Next Agent

Use this from the Godot project folder:

`Validate and finish iOS integration for the local AdMob plugin. The plugin repo already contains ios/plugins/admob_plugin with AdMobPlugin.debug.xcframework, AdMobPlugin.release.xcframework, GoogleMobileAds.xcframework, and gdip metadata. Verify Godot detects the iOS plugin, export the project for iOS, test initialize/interstitial/rewarded/ATT flows, and patch either the project or plugin integration until the runtime works without manual Xcode dependency edits.`
