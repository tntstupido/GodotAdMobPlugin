# AdMob Plugin for Godot 4 (Android)

Native Android plugin that exposes AdMob interstitial and rewarded ads to GDScript.
Tested with Godot 4.5.1 and play-services-ads 24.1.0.

---

## Project Structure

```
AdMobPlugin/
├── README.md                          # this file
├── CHANGELOG.md                       # version history
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
└── godot/                             # copy into your Godot project
    ├── addons/admob_plugin/
    │   ├── plugin.cfg                 # Godot plugin metadata
    │   ├── admob_plugin.gd            # EditorExportPlugin (GDScript)
    │   ├── AdMobPlugin-debug.aar      # built AAR (debug)
    │   └── AdMobPlugin-release.aar    # built AAR (release)
    └── autoload/
        └── AdManager.gd              # singleton for use in game scenes
```

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
```

### 3. Enable in Godot

- **Project → Project Settings → Plugins** → enable `AdMobPlugin`
- **Project → Project Settings → Autoload** → add `res://autoload/AdManager.gd` as `AdManager`

### 4. Use in GDScript

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

---

## Test IDs (Google)

Use these **only** during development and testing:

```
App ID:            ca-app-pub-3940256099942544~3347511713
Interstitial ID:   ca-app-pub-3940256099942544/1033173712
Rewarded ID:       ca-app-pub-3940256099942544/5224354917
```

`APP_ID`, `INTERSTITIAL_ID`, and `REWARDED_ID` are defined in `godot/autoload/AdManager.gd`.
For production, replace them with your real IDs and set `TEST_MODE = false`.

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
