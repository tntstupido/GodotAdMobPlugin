plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android") version "2.1.0"
}

android {
    namespace = "com.yourcompany.admobplugin"
    compileSdk = 35

    defaultConfig {
        minSdk = 21
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}

dependencies {
    // Godot engine AAR — download from https://github.com/godotengine/godot/releases
    // Place godot-lib.release.aar in the libs/ directory of this module.
    compileOnly(fileTree("libs") { include("*.aar") })

    implementation("com.google.android.gms:play-services-ads:24.1.0")
}
