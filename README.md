# AdMob Plugin za Godot 4 (Android)

Nativni Android plugin koji izlaže AdMob interstitial reklame GDScript-u.
Testiran sa Godot 4.5.1 i play-services-ads 24.1.0.

---

## Struktura projekta

```
AdMobPlugin/
├── README.md                          # ovaj fajl
├── AdMob_Android_Plugin_Guide.md      # detaljan vodič korak-po-korak
│
├── android/                           # Android Studio / Gradle projekt
│   ├── settings.gradle.kts
│   ├── build.gradle.kts
│   ├── gradle.properties
│   ├── local.properties               # sdk.dir (ne commitovati u git)
│   └── admobplugin/
│       ├── build.gradle.kts
│       ├── libs/
│       │   └── godot-lib.4.5.1.stable.template_release.aar   # Godot engine AAR
│       └── src/main/
│           ├── AndroidManifest.xml
│           └── java/com/yourcompany/admobplugin/
│               └── AdMobPlugin.kt     # Kotlin plugin klasa
│
└── godot/                             # kopirati u Godot projekt
    ├── addons/admob_plugin/
    │   ├── plugin.cfg                 # Godot plugin metadata
    │   ├── admob_plugin.gd            # EditorExportPlugin (GDScript)
    │   ├── AdMobPlugin-debug.aar      # buildovani AAR (debug)
    │   └── AdMobPlugin-release.aar    # buildovani AAR (release)
    └── autoload/
        └── AdManager.gd              # singleton za korištenje u igri
```

---

## Brzi start

### 1. Build AAR (jednom, ili kad mijenjaš Kotlin kod)

```bash
# Potrebno: JDK 17, Android SDK, internet (za preuzimanje dependencija)
cd android
# Koristi Gradle 8.7+ ili wrapper ako ga imaš
gradle :admobplugin:assembleDebug :admobplugin:assembleRelease
```

Output AAR fajlovi se automatski kopiraju u `godot/addons/admob_plugin/` —
ili kopiraj ručno:

```bash
cp android/admobplugin/build/outputs/aar/admobplugin-debug.aar   godot/addons/admob_plugin/AdMobPlugin-debug.aar
cp android/admobplugin/build/outputs/aar/admobplugin-release.aar  godot/addons/admob_plugin/AdMobPlugin-release.aar
```

### 2. Kopiraj u Godot projekt

```bash
cp -r godot/addons/admob_plugin/  <tvoj_godot_projekat>/addons/admob_plugin/
cp    godot/autoload/AdManager.gd  <tvoj_godot_projekat>/autoload/AdManager.gd
```

### 3. Aktiviraj u Godotu

- **Project → Project Settings → Plugins** → uključi `AdMobPlugin`
- **Project → Project Settings → Autoload** → dodaj `res://autoload/AdManager.gd` kao `AdManager`

### 4. Koristi u GDScript-u

```gdscript
func _ready() -> void:
    AdManager.initialize()
    AdManager.interstitial_loaded.connect(_on_ad_ready)
    AdManager.load_interstitial()

func _on_ad_ready() -> void:
    AdManager.show_interstitial()
```

---

## API referenca

### AdManager (autoload singleton)

| Metoda | Opis |
|--------|------|
| `initialize()` | Inicijalizuje AdMob SDK. Pozovi jednom na startu. |
| `load_interstitial()` | Počinje učitavanje interstitial reklame. |
| `show_interstitial() -> bool` | Prikazuje reklamu ako je učitana. Vraća `true` ako je pokazana. |
| `is_interstitial_loaded() -> bool` | Provjera da li je reklama spremna. |

### Signali

| Signal | Opis |
|--------|------|
| `initialized` | SDK je spreman. |
| `interstitial_loaded` | Reklama učitana, može se prikazati. |
| `interstitial_closed` | Korisnik zatvorio reklamu. Sljedeća se automatski počinje učitavati. |
| `interstitial_failed_to_load` | Greška pri učitavanju (nema mreže, pogrešan ID itd.) |
| `interstitial_show_failed` | Greška pri prikazivanju. |

---

## Test ID-ovi (Google)

Koristiti **isključivo** za razvoj i testiranje:

```
App ID:            ca-app-pub-3940256099942544~3347511713
Interstitial ID:   ca-app-pub-3940256099942544/1033173712
```

Nalaze se u `godot/autoload/AdManager.gd` kao konstante `APP_ID` i `INTERSTITIAL_ID`.
Za produkciju zamijeniti sa pravim ID-ovima i postaviti `TEST_MODE = false`.

---

## Verzije i dependencije

| Komponenta | Verzija |
|------------|---------|
| Godot | 4.5.1 stable |
| Kotlin | 2.1.0 |
| Android Gradle Plugin | 8.3.0 |
| Gradle | 8.7 |
| play-services-ads | 24.1.0 |
| compileSdk | 35 |
| minSdk | 21 (Android 5.0+) |
| JDK | 17 |

---

## Česte greške

| Problem | Uzrok | Rješenje |
|---------|-------|----------|
| `Engine.has_singleton("AdMobPlugin") == false` | AAR nedostaje ili pogrešan naziv klase | Provjeri da su oba AAR-a u `addons/admob_plugin/` i da je plugin aktiviran |
| Build greška: `SDK location not found` | Nedostaje `local.properties` | Kreiraj `android/local.properties` sa `sdk.dir=/putanja/do/Android/Sdk` |
| Build greška: Kotlin metadata version | Pogrešna Kotlin verzija | Godot 4.5.1 zahtijeva Kotlin 2.1.0 |
| Reklama se ne prikazuje | `show_interstitial()` pozvan prije `interstitial_loaded` signala | Sačekaj signal, ne pozivaj show odmah nakon load |
| App se ruši pri prikazivanju | Activity null ili callback nije postavljen | Provjeri da se show poziva na UI threadu (rješeno u pluginu) |

---

## Napomene za AI asistente

- Plugin klasa: `android/admobplugin/src/main/java/com/yourcompany/admobplugin/AdMobPlugin.kt`
- Export plugin: `godot/addons/admob_plugin/admob_plugin.gd`
- Autoload singleton: `godot/autoload/AdManager.gd`
- Godot plugin API koristi `GodotPlugin` baznu klasu i `@UsedByGodot` anotaciju za izlaganje metoda
- Signali se registruju kroz `getPluginSignals()` koja vraća `Set<SignalInfo>` (ne `Set<String>`)
- `emitSignal("naziv")` se poziva iz Kotlin koda za slanje signala u GDScript
- AAR fajlovi u `godot/addons/admob_plugin/` su buildovani artefakti — regenerisati ih ako se mijenja Kotlin kod
- `local.properties` nije u git-u (sadrži lokalne putanje)

---

## Release Notes

- Latest fixes are tracked in `CHANGELOG.md`.
- Current stable release: **v1.1.0**.

### Build tip (if `./gradlew` fails with wrapper manifest error)

Use wrapper main class directly:

```bash
export JAVA_HOME=/opt/jdk-17
export PATH="$JAVA_HOME/bin:$PATH"
java -classpath gradle/wrapper/gradle-wrapper.jar org.gradle.wrapper.GradleWrapperMain :admobplugin:assembleDebug :admobplugin:assembleRelease
```
