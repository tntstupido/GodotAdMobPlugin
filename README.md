# AdMob Plugin for Godot 4

Native Android plugin that exposes AdMob interstitial and rewarded ads to GDScript.
The Godot-facing layer now includes platform-specific settings and iOS ATT helper hooks, and the repository includes a Godot iOS plugin descriptor scaffold under `ios/plugins/`.
Tested Android target: Godot 4.5.1 and play-services-ads 24.1.0.
Android ILR support is included via native `paid_event` callbacks (`OnPaidEventListener`) for interstitial and rewarded ads.

---

## Release

- Latest packaged release: `v1.3.0`
- GitHub release: `https://github.com/tntstupido/GodotAdMobPlugin/releases/tag/v1.3.0`
- Direct download: `https://github.com/tntstupido/GodotAdMobPlugin/releases/download/v1.3.0/AdMobPlugin-v1.3.0-addons.zip`
- The release zip contains:
  - Android runtime payload under `addons/admob_plugin/`
  - iOS runtime payload under `ios/plugins/admob_plugin/`

---

## Project Structure

```
AdMobPlugin/
├── README.md                          # this file
├── CHANGELOG.md                       # version history
├── ios/
│   ├── native/
│   │   └── AdMobPlugin/
│   │       ├── src/                   # Objective-C++ Godot/iOS bridge scaffold
│   │       ├── scripts/               # xcframework build script
│   │       └── README.md              # native build expectations
│   └── plugins/
│       └── admob_plugin/
│           ├── admob_plugin.gdip      # Godot iOS plugin descriptor
│           └── README.md              # expected iOS payload layout
│
├── android/                           # Android Studio / Gradle project
│   ├── settings.gradle.kts
│   ├── build.gradle.kts
│   ├── gradle.properties
│   ├── local.properties               # sdk.dir (do not commit to git)
│   └── admobplugin/
│       ├── build.gradle.kts
│       ├── libs/
│       │   └── godot-lib.4.5.1.stable.template_release.aar   # Godot engine AAR
│       └── src/main/
│           ├── AndroidManifest.xml
│           └── java/com/yourcompany/admobplugin/
│               └── AdMobPlugin.kt     # Kotlin plugin class
│
├── godot/                             # copy into your Godot project
    ├── addons/admob_plugin/
    │   ├── plugin.cfg                 # Godot plugin metadata
    │   ├── admob_plugin.gd            # EditorExportPlugin (GDScript)
    │   ├── AdMobPlugin-debug.aar      # built AAR (debug)
    │   └── AdMobPlugin-release.aar    # built AAR (release)
    └── autoload/
        └── AdManager.gd              # singleton for use in game scenes
└── scripts/
    └── package_release.sh             # release zip builder
```

---

## Status

- Android export/runtime support is implemented and packaged in this repository.
- iOS payload is implemented and included under [ios/plugins/admob_plugin](/Users/mladen/Documents/Plugins/GodotAdMobPlugin/ios/plugins/admob_plugin):
  - `AdMobPlugin.debug.xcframework`
  - `AdMobPlugin.release.xcframework`
  - `GoogleMobileAds.xcframework`
  - `UserMessagingPlatform.xcframework`
  - `admob_plugin.gdip`
- iOS consent stack support is now present:
  - UMP helpers exposed to GDScript
  - explicit UMP privacy-options form helper exposed to GDScript
  - ATT helpers exposed to GDScript
  - ATT prompt is manual-only (not auto-triggered by ad loading)
  - consuming projects may keep this as plugin capability only; a game does not need to expose a manual privacy-options button if its validated UX is fully covered by automatic UMP/ATT flow
- Native iOS source and build workflow remain under [ios/native/AdMobPlugin](/Users/mladen/Documents/Plugins/GodotAdMobPlugin/ios/native/AdMobPlugin).

---

## Quick Start

### 1. Build the AAR (once, or whenever you change Kotlin code)

```bash
# Requirements: JDK 17, Android SDK, internet (for downloading dependencies)
cd android
# Use Gradle 8.7+ or the wrapper if available
gradle :admobplugin:assembleDebug :admobplugin:assembleRelease
```

Then copy the output AAR files manually:

```bash
cp android/admobplugin/build/outputs/aar/admobplugin-debug.aar   godot/addons/admob_plugin/AdMobPlugin-debug.aar
cp android/admobplugin/build/outputs/aar/admobplugin-release.aar  godot/addons/admob_plugin/AdMobPlugin-release.aar
```

### 2. Copy into your Godot project

```bash
cp -r godot/addons/admob_plugin/  <your_godot_project>/addons/admob_plugin/
cp    godot/autoload/AdManager.gd  <your_godot_project>/autoload/AdManager.gd
cp -r ios/plugins/                 <your_godot_project>/ios/plugins/
```

### 3. iOS plugin payload

Godot 4 detects iOS plugins from `.gdip` files inside `res://ios/plugins`. This repository now includes [admob_plugin.gdip](/Users/mladen/Documents/Plugins/GodotAdMobPlugin/ios/plugins/admob_plugin/admob_plugin.gdip), which declares:

- singleton name `AdMobPlugin`
- plugin binary basename `AdMobPlugin.xcframework`
- embedded dependencies:
  - `GoogleMobileAds.xcframework`
  - `UserMessagingPlatform.xcframework`
- Info.plist keys `GADApplicationIdentifier` and `NSUserTrackingUsageDescription`

The iOS runtime payload is present in this repository and should be synced into the consuming Godot project under `res://ios/plugins/admob_plugin/`.

Native source code for that bridge now lives in [ios/native/AdMobPlugin](/Users/mladen/Documents/Plugins/GodotAdMobPlugin/ios/native/AdMobPlugin).

### 3.1 iOS post-export patch step

Current verified workflow for a Godot iOS export that uses this plugin:

1. Export the iOS/Xcode project from Godot.
2. Run:

```bash
python3 scripts/patch_ios_export_xcode_project.py <exported_ios_project_dir>
```

For example:

```bash
python3 scripts/patch_ios_export_xcode_project.py /Users/mladen/Documents/GodotProjects/die_laughing_export
```

This currently patches the generated Xcode project to:

- compile the existing `dummy.swift`
- enable Swift standard library embedding
- link `JavaScriptCore.framework`

The script is idempotent and can be rerun safely after each fresh export.

### 4. Enable in Godot

- **Project → Project Settings → Plugins** → enable `AdMobPlugin`
- **Project → Project Settings → Autoload** → add `res://autoload/AdManager.gd` as `AdManager`

### 5. Use in GDScript

```gdscript
func _ready() -> void:
    AdManager.initialize()

    AdManager.interstitial_loaded.connect(_on_interstitial_ready)
    AdManager.rewarded_loaded.connect(_on_rewarded_ready)
    AdManager.rewarded_earned.connect(_on_rewarded_earned)

    AdManager.load_interstitial()
    AdManager.load_rewarded()

func _on_interstitial_ready() -> void:
    AdManager.show_interstitial()

func _on_rewarded_ready() -> void:
    AdManager.show_rewarded()

func _on_rewarded_earned() -> void:
    print("Grant reward to player")
```

---

## Android UMP Test Helpers

Android runtime now exposes explicit UMP debug/testing helpers for pre-publish consent validation:

- `set_ump_debug_geography(mode)` / `setUmpDebugGeography(mode)`
  - accepted values: `disabled`, `eea`, `not_eea`
- `reset_ump_consent_state()` / `resetUmpConsentState()`
- `request_consent_info_update()` / `requestConsentInfoUpdate()`
- `can_request_ads()` / `canRequestAds()`
- `is_consent_form_available()` / `isConsentFormAvailable()`
- `show_consent_form_if_required()` / `showConsentFormIfRequired()`
- `get_consent_status()` / `getConsentStatus()`
- `get_privacy_options_requirement_status()` / `getPrivacyOptionsRequirementStatus()`
- `is_privacy_options_form_available()` / `isPrivacyOptionsFormAvailable()`
- `show_privacy_options_form()` / `showPrivacyOptionsForm()`

Important:
- These are testing-oriented controls.
- Production/release behavior should not force debug geography or test-device overrides.
- Enforce that policy in the host game layer (for example, only apply these controls in debug builds).

## API Reference

### AdManager (autoload singleton)

| Method | Description |
|--------|-------------|
| `initialize()` | Initializes the AdMob SDK. Call once at game start. |
| `load_interstitial()` | Starts loading an interstitial ad. |
| `show_interstitial() -> bool` | Shows the ad if loaded. Returns `true` if shown. |
| `is_interstitial_loaded() -> bool` | Returns whether an ad is ready to show. |
| `load_rewarded()` | Starts loading a rewarded ad. |
| `show_rewarded() -> bool` | Shows a rewarded ad if loaded. Returns `true` if shown. |
| `is_rewarded_loaded() -> bool` | Returns whether a rewarded ad is ready to show. |
| `request_tracking_authorization()` | Calls into the native ATT prompt helper when the active platform plugin exposes it. |
| `get_tracking_authorization_status() -> int` | Returns native ATT status when exposed, otherwise `-1`. |
| `request_consent_info_update()` | Triggers UMP consent info update on iOS when supported. |
| `can_request_ads() -> bool` | Returns UMP ad-request eligibility state on iOS when supported. |
| `is_consent_form_available() -> bool` | Returns whether a UMP consent form is available on iOS when supported. |
| `show_consent_form_if_required()` | Requests UMP consent form presentation on iOS when required. |
| `get_consent_status() -> int` | Returns UMP consent status value on iOS when supported. |
| `get_privacy_options_requirement_status() -> int` | Returns UMP privacy-options requirement status on iOS when supported. |
| `is_privacy_options_form_available() -> bool` | Returns whether UMP privacy options are currently available on iOS. |
| `show_privacy_options_form()` | Presents the native UMP privacy-options form on iOS when available. This is optional at the game-UI level; projects can keep it unused if automatic consent flow is sufficient. |

### AdMobPlugin (native singleton methods)

| Method | Description |
|--------|-------------|
| `initialize(appId, testMode)` | Initializes the AdMob SDK on Android. |
| `load_interstitial(adUnitId)` / `loadInterstitial(adUnitId)` | Loads an interstitial ad. |
| `show_interstitial() -> bool` / `showInterstitial() -> bool` | Shows an interstitial ad if loaded. |
| `is_interstitial_loaded() -> bool` / `isInterstitialLoaded() -> bool` | Returns interstitial loaded state. |
| `load_rewarded(adUnitId)` / `loadRewarded(adUnitId)` | Loads a rewarded ad. |
| `show_rewarded() -> bool` / `showRewarded() -> bool` | Shows a rewarded ad if loaded. |
| `is_rewarded_loaded() -> bool` / `isRewardedLoaded() -> bool` | Returns rewarded loaded state. |
| `request_tracking_authorization()` / `requestTrackingAuthorization()` | iOS ATT authorization request helper. |
| `get_tracking_authorization_status() -> int` / `getTrackingAuthorizationStatus() -> int` | iOS ATT status helper. |
| `request_consent_info_update()` / `requestConsentInfoUpdate()` | iOS UMP consent info update helper. |
| `can_request_ads() -> bool` / `canRequestAds() -> bool` | iOS UMP ad-request eligibility helper. |
| `is_consent_form_available() -> bool` / `isConsentFormAvailable() -> bool` | iOS UMP consent form availability helper. |
| `show_consent_form_if_required()` / `showConsentFormIfRequired()` | iOS UMP consent form presentation helper. |
| `get_consent_status() -> int` / `getConsentStatus() -> int` | iOS UMP consent status helper. |
| `get_privacy_options_requirement_status() -> int` / `getPrivacyOptionsRequirementStatus() -> int` | iOS UMP privacy options requirement helper. |
| `is_privacy_options_form_available() -> bool` / `isPrivacyOptionsFormAvailable() -> bool` | iOS UMP privacy-options availability helper. |
| `show_privacy_options_form()` / `showPrivacyOptionsForm()` | iOS UMP privacy-options form presentation helper. |

### AdManager Signals (autoload)

| Signal | Description |
|--------|-------------|
| `initialized` | SDK is ready. |
| `interstitial_loaded` | Ad loaded and ready to show. |
| `interstitial_closed` | User dismissed the ad. Next ad starts loading automatically. |
| `interstitial_failed_to_load` | Load error (no network, wrong ID, etc.) |
| `interstitial_show_failed` | Error while showing the ad. |
| `rewarded_loaded` | Rewarded ad loaded and ready to show. |
| `rewarded_closed` | Rewarded ad dismissed. Next rewarded ad starts loading automatically. |
| `rewarded_earned` | User earned reward callback fired. |
| `rewarded_failed_to_load` | Rewarded load error (no network, wrong ID, etc.) |
| `rewarded_show_failed` | Error while showing the rewarded ad. |
| `paid_event(ad_type, ad_unit_id, value_micros, currency_code, precision_type)` | Impression-level ad revenue callback for loaded ad objects. |

### AdMobPlugin Signals (native)

| Signal | Description |
|--------|-------------|
| `initialized` | SDK is ready. |
| `interstitial_loaded` | Interstitial loaded and ready to show. |
| `interstitial_closed` | Interstitial dismissed by the user. |
| `interstitial_failed_to_load` | Interstitial load failed. |
| `interstitial_show_failed` | Interstitial show failed. |
| `rewarded_loaded` | Rewarded ad loaded and ready to show. |
| `rewarded_closed` | Rewarded ad dismissed by the user. |
| `rewarded_earned` | User earned reward callback fired. |
| `rewarded_failed_to_load` | Rewarded ad load failed. |
| `rewarded_show_failed` | Rewarded ad show failed. |
| `paid_event` | Impression-level ad revenue callback (`ad_type`, `ad_unit_id`, `value_micros`, `currency_code`, `precision_type`). |
| `consent_info_updated` | iOS UMP consent info update callback. |
| `consent_form_shown` | iOS UMP consent form shown callback. |
| `consent_form_dismissed` | iOS UMP consent form dismissed callback. |
| `consent_flow_finished` | iOS UMP consent flow finished callback. |
| `consent_error` | iOS UMP consent flow error callback. |
| `privacy_options_form_shown` | iOS UMP privacy-options form shown callback. |
| `privacy_options_form_dismissed` | iOS UMP privacy-options form dismissed callback. |
| `privacy_options_form_finished` | iOS UMP privacy-options flow finished callback. |

---

## Test IDs (Google)

When a device is configured as a test device, `paid_event` may still fire but `value_micros` can be `0`.

Use these **only** during development and testing:

```
App ID:            ca-app-pub-3940256099942544~3347511713
Interstitial ID:   ca-app-pub-3940256099942544/1033173712
Rewarded ID:       ca-app-pub-3940256099942544/5224354917
```

At runtime, `AdManager` resolves IDs from ProjectSettings first:

- `admob/android/app_id`
- `admob/android/interstitial_id`
- `admob/android/rewarded_id`
- `admob/ios/app_id`
- `admob/ios/interstitial_id`
- `admob/ios/rewarded_id`
- `admob/ios/att_message`

Legacy fallback remains enabled for `admob/app_id`.
If no settings are configured, the hardcoded Google test IDs in [AdManager.gd](/Users/mladen/Documents/Plugins/GodotAdMobPlugin/godot/autoload/AdManager.gd) are used.

---

## Versions & Dependencies

| Component | Version |
|-----------|---------|
| Godot | 4.5.1 stable |
| Kotlin | 2.1.0 |
| Android Gradle Plugin | 8.3.0 |
| Gradle | 8.7 |
| play-services-ads | 24.1.0 |
| compileSdk | 35 |
| minSdk | 21 (Android 5.0+) |
| JDK | 17 |
| iOS plugin descriptor | Included |
| iOS native source scaffold | Included |
| iOS native xcframeworks | Included |

---

## Scope Boundaries

This repository/plugin covers AdMob + ATT + UMP only.

Planned integrations such as:

- iOS IAP plugin integration (StoreKit)
- iOS Game Center plugin integration

should be implemented as separate plugins/workstreams in the consuming game project and coordinated there at the product roadmap level.

---

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| `Engine.has_singleton("AdMobPlugin") == false` | AAR missing or wrong class name | Check both AARs are in `addons/admob_plugin/` and plugin is enabled |
| Build error: `SDK location not found` | Missing `local.properties` | Create `android/local.properties` with `sdk.dir=/path/to/Android/Sdk` |
| Build error: Kotlin metadata version | Wrong Kotlin version | Godot 4.5.1 requires Kotlin 2.1.0 |
| Ad does not show | `show_interstitial()` called before `interstitial_loaded` signal | Wait for the signal before calling show |
| App crashes on show | Activity null or callback not set | Ensure show is called on the UI thread (already handled in the plugin) |

---

## Notes for AI Assistants

- Plugin class: `android/admobplugin/src/main/java/com/yourcompany/admobplugin/AdMobPlugin.kt`
- Export plugin: `godot/addons/admob_plugin/admob_plugin.gd`
- Autoload singleton: `godot/autoload/AdManager.gd`
- Godot plugin API uses the `GodotPlugin` base class and `@UsedByGodot` annotation to expose methods
- Signals are registered via `getPluginSignals()` which returns `Set<SignalInfo>` (not `Set<String>`)
- `emitSignal("name")` is called from Kotlin to send signals to GDScript
- AAR files in `godot/addons/admob_plugin/` are built artifacts — regenerate them if Kotlin code changes
- `local.properties` is not tracked in git (contains local SDK path)

---

## Build Tip (if Gradle wrapper fails)

Run the wrapper main class directly:

```bash
export JAVA_HOME=/opt/jdk-17
export PATH="$JAVA_HOME/bin:$PATH"
java -classpath gradle/wrapper/gradle-wrapper.jar org.gradle.wrapper.GradleWrapperMain :admobplugin:assembleDebug :admobplugin:assembleRelease
```
