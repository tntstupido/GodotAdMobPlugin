# AdMob Plugin for Godot 4 (Android)

Native Android plugin that exposes AdMob interstitial ads to GDScript.
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
    AdManager.interstitial_loaded.connect(_on_ad_ready)
    AdManager.load_interstitial()

func _on_ad_ready() -> void:
    AdManager.show_interstitial()
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

### Signals

| Signal | Description |
|--------|-------------|
| `initialized` | SDK is ready. |
| `interstitial_loaded` | Ad loaded and ready to show. |
| `interstitial_closed` | User dismissed the ad. Next ad starts loading automatically. |
| `interstitial_failed_to_load` | Load error (no network, wrong ID, etc.) |
| `interstitial_show_failed` | Error while showing the ad. |

---

## Test IDs (Google)

Use these **only** during development and testing:

```
App ID:            ca-app-pub-3940256099942544~3347511713
Interstitial ID:   ca-app-pub-3940256099942544/1033173712
```

They are defined in `godot/autoload/AdManager.gd` as `APP_ID` and `INTERSTITIAL_ID`.
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